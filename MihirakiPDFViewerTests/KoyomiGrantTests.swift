import Foundation
import Testing
@testable import MihirakiPDFViewer

@MainActor
private final class LocalGrantFixture: KoyomiGrantStoring {
    var isGranted = false
    var saves = 0
    var canSave = true
    func saveGrant() -> Bool {
        saves += 1
        if canSave { isGranted = true }
        return isGranted
    }
}

@MainActor
struct KoyomiGrantTests {
    private let end = Date(timeIntervalSince1970: 1_830_265_200)
    private var deadline: KoyomiGrantDeadline? { KoyomiGrantDeadline(end: end) }

    @Test(arguments: [TimeInterval(-86400), -1, -0.001, 0, 0.001, 86400])
    func exclusiveJSTClaimDeadline(offset: TimeInterval) async {
        let store = LocalGrantFixture()
        let date = end.addingTimeInterval(offset)
        let grant = KoyomiGrantController(deadline: deadline, store: store, now: { date })
        await grant.recheck()
        #expect(grant.state == (offset < 0 ? .eligible : .ineligible))
        #expect(store.isGranted == (offset < 0))
        #expect(store.saves == (offset < 0 ? 1 : 0))
    }

    @Test func productionDeadlineMatchesJST() throws {
        let policy = try #require(KoyomiGrantDeadline.production)
        #expect(ISO8601DateFormatter().string(from: policy.end) == "2027-12-31T15:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 9 * 60 * 60))
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: policy.end)
        #expect(parts.year == 2028 && parts.month == 1 && parts.day == 1 && parts.hour == 0 && parts.minute == 0 && parts.second == 0)
    }

    @Test func savedGrantSurvivesDeadlineAndNewUserDefaultsInstance() async throws {
        let suite = "KoyomiGrantTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let before = end.addingTimeInterval(-1)
        let grant = KoyomiGrantController(deadline: deadline,
            store: UserDefaultsKoyomiGrantStore(defaults: defaults), now: { before })
        await grant.recheck()
        #expect(grant.state == .eligible)
        let secondDefaults = try #require(UserDefaults(suiteName: suite))
        let late = end.addingTimeInterval(86400)
        let restarted = KoyomiGrantController(deadline: deadline,
            store: UserDefaultsKoyomiGrantStore(defaults: secondDefaults), now: { late })
        #expect(restarted.state == .eligible)
        await restarted.recheck()
        await restarted.refreshByUserRequest()
        #expect(restarted.state == .eligible)
    }

    @Test func missingLocalDataAfterDeadlineDoesNotRestoreFromAnAccount() async throws {
        let suite = "KoyomiGrantTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsKoyomiGrantStore(defaults: defaults)
        #expect(store.saveGrant())
        // Clears only this randomized test suite, never the app's real preferences.
        defaults.removePersistentDomain(forName: suite)
        let late = end.addingTimeInterval(1)
        let fresh = KoyomiGrantController(deadline: deadline,
            store: UserDefaultsKoyomiGrantStore(defaults: defaults), now: { late })
        await fresh.recheck()
        #expect(fresh.state == .ineligible)
        #expect(!store.isGranted)
    }

    @Test func repeatedChecksDoNotRewriteOrExpireSavedGrant() async {
        let store = LocalGrantFixture()
        var date = end.addingTimeInterval(-1)
        var clockReads = 0
        let grant = KoyomiGrantController(deadline: deadline, store: store, now: {
            clockReads += 1
            return date
        })
        await grant.recheck()
        date = end.addingTimeInterval(86400)
        await grant.recheck()
        await grant.refreshByUserRequest()
        #expect(grant.state == .eligible)
        #expect(store.saves == 1 && clockReads == 1)
    }

    @Test func savedBadgeRemainsWhenAutomaticGrantIsDisabled() async {
        let store = LocalGrantFixture()
        store.isGranted = true
        let grant = KoyomiGrantController(deadline: nil, store: store)
        await grant.recheck()
        #expect(grant.state == .eligible && store.saves == 0)
    }

    @Test(arguments: [TimeInterval.infinity, -.infinity, .nan])
    func invalidDeadlineCannotCreateLocalGrant(timestamp: TimeInterval) async {
        let store = LocalGrantFixture()
        let grant = KoyomiGrantController(
            deadline: KoyomiGrantDeadline(end: Date(timeIntervalSince1970: timestamp)), store: store)
        await grant.recheck()
        #expect(grant.state == .disabled && !store.isGranted && store.saves == 0)
    }

    @Test(arguments: [TimeInterval.infinity, -.infinity, .nan])
    func invalidClockDefersWithoutSaving(timestamp: TimeInterval) async {
        let store = LocalGrantFixture()
        let date = Date(timeIntervalSince1970: timestamp)
        let grant = KoyomiGrantController(deadline: deadline, store: store, now: { date })
        await grant.recheck()
        #expect(grant.state == .pending && !store.isGranted && store.saves == 0)
    }

    @Test func failedSaveCanRetryBeforeDeadline() async {
        let store = LocalGrantFixture()
        store.canSave = false
        let date = end.addingTimeInterval(-1)
        let grant = KoyomiGrantController(deadline: deadline, store: store, now: { date })
        await grant.recheck()
        #expect(grant.state == .pending && !store.isGranted)
        store.canSave = true
        await grant.recheck()
        #expect(grant.state == .eligible && store.saves == 2)
    }

    @Test func failedSaveDoesNotInventAClaimAfterDeadline() async {
        let store = LocalGrantFixture()
        store.canSave = false
        var date = end.addingTimeInterval(-1)
        let grant = KoyomiGrantController(deadline: deadline, store: store, now: { date })
        await grant.recheck()
        store.canSave = true
        date = end
        await grant.recheck()
        #expect(grant.state == .ineligible && !store.isGranted && store.saves == 1)
    }

    @Test func newGrantNotifiesOnceAndDismissDoesNotRemoveSavedBadge() async {
        let store = LocalGrantFixture()
        let date = end.addingTimeInterval(-1)
        let grant = KoyomiGrantController(deadline: deadline, store: store, now: { date })
        let manager = TipManager(testGrant: grant)
        #expect(!manager.isShowingKoyomiGrantNotification)
        await grant.recheck()
        #expect(manager.isShowingKoyomiGrantNotification && manager.hasKoyomiBadge)
        manager.dismissKoyomiGrantNotification()
        await grant.recheck()
        await grant.refreshByUserRequest()
        #expect(!manager.isShowingKoyomiGrantNotification && manager.hasKoyomiBadge)
        let restarted = KoyomiGrantController(deadline: deadline, store: store, now: { date })
        #expect(restarted.state == .eligible && !restarted.hasNewGrantNotification)
        #expect(store.saves == 1)
    }

    @Test func disabledGrantStillAllowsExistingStoreKitRestoration() async {
        let store = LocalGrantFixture()
        let grant = KoyomiGrantController(deadline: nil, store: store)
        var syncCalls = 0
        let manager = TipManager(testGrant: grant,
            synchronizePurchases: { syncCalls += 1 },
            readOwnedProducts: { [TipManager.koyomiV2BadgeProductID] })
        await manager.restorePurchases()
        #expect(manager.hasKoyomiBadge)
        #expect(manager.isPurchased(TipManager.koyomiV2BadgeProductID))
        #expect(syncCalls == 1 && !store.isGranted && grant.state == .disabled)
    }

    @Test(arguments: [true, false], [true, false])
    func localAndStoreKitRoutesShowOneBadge(local: Bool, owned: Bool) async {
        let store = LocalGrantFixture()
        store.isGranted = local
        let date = end
        let grant = KoyomiGrantController(deadline: deadline, store: store, now: { date })
        await grant.recheck()
        let tips: Set<String> = [SupporterTier.bronze.rawValue, SupporterTier.silver.rawValue, SupporterTier.gold.rawValue]
        let ids = owned ? tips.union([TipManager.koyomiV2BadgeProductID]) : tips
        let manager = TipManager(testGrant: grant, ownedProductIDs: ids)
        #expect(manager.hasKoyomiBadge == (local || owned))
        #expect(manager.displayedSupporterTiers.filter { $0 == .koyomi }.count == (local || owned ? 1 : 0))
        #expect(manager.ownedProductIDs == ids)
        #expect(manager.displayedSupporterTiers.filter { $0 != .koyomi }.count == 3)
    }

    @Test func revokedStoreKitRightCannotRemoveSavedFreeBadge() async {
        let store = LocalGrantFixture()
        store.isGranted = true
        let grant = KoyomiGrantController(deadline: deadline, store: store)
        let manager = TipManager(testGrant: grant, ownedProductIDs: [TipManager.koyomiV2BadgeProductID], readOwnedProducts: { [] })
        await manager.refreshEntitlements()
        #expect(!manager.isPurchased(TipManager.koyomiV2BadgeProductID))
        #expect(manager.hasKoyomiBadge && store.isGranted)
    }

    @Test(arguments: [true, false])
    func restorationFailurePreservesBothRoutes(local: Bool) async {
        let store = LocalGrantFixture()
        store.isGranted = local
        let date = end
        let grant = KoyomiGrantController(deadline: deadline, store: store, now: { date })
        await grant.recheck()
        let ids: Set<String> = [TipManager.koyomiV2BadgeProductID, SupporterTier.bronze.rawValue]
        let manager = TipManager(testGrant: grant, ownedProductIDs: ids,
            synchronizePurchases: { throw NSError(domain: "fixture", code: 1) })
        await manager.restorePurchases()
        #expect(manager.hasKoyomiBadge && manager.ownedProductIDs == ids)
        #expect(store.isGranted == local)
        #expect(manager.errorMessage != nil && !manager.isRestoringPurchases)
    }
}
