import Foundation
import Testing
@testable import MihirakiPDFViewer

@MainActor
struct SharingAndPurchaseSafetyTests {
    @Test(arguments: DeviceTestRunner.CheckKind.allCases)
    func untrustedErrorsBecomeFixedCheckMessages(kind: DeviceTestRunner.CheckKind) {
        let secret = "/private/fixture/FAKE-UUID/private-document.pdf password=fixture search=private"
        let check = DeviceTestRunner.performCheck(kind) {
            throw NSError(domain: "fixture", code: 71,
                          userInfo: [NSLocalizedDescriptionKey: secret])
        }
        #expect(check.id == kind.rawValue)
        #expect(check.status == .failed)
        #expect(check.detail == kind.failureDetail)
        #expect(!(check.detail ?? "").contains(secret))
        let report = DeviceTestReport(
            testedAt: Date(timeIntervalSince1970: 1_800_000_000),
            deviceModelName: "Test model", deviceModelIdentifier: "TestModel1,1",
            osVersion: "Test OS", appVersion: "Test build",
            totalMemoryBytes: 1_000, availableMemoryBytes: 500,
            checks: [check])
        for value in ["private-document", "FAKE-UUID", "password=", "search=", "systemUptime"] {
            #expect(!report.shareText.contains(value))
        }
        if kind == .availableStorage {
            #expect(!report.shareText.contains(kind.failureDetail))
        } else {
            #expect(report.shareText.contains(kind.failureDetail))
            #expect(report.shareText.contains(String(localized: kind.name)))
        }
    }

    @Test(arguments: ["supporter_badge_koyomi_v2", "unknown-product"])
    func deferredOrUnknownProductsNeverInvokePurchase(productID: String) async throws {
        var calls = 0
        let result: Bool? = try await TipManager.performPurchaseIfAllowed(productID: productID) {
            calls += 1
            throw NSError(domain: "purchase-must-not-run", code: 1)
        }
        #expect(result == nil)
        #expect(calls == 0)
    }

    @Test(arguments: ["supporter_icon_bronze", "supporter_icon_silver", "supporter_icon_gold"])
    func supportedProductsStillInvokePurchase(productID: String) async {
        var calls = 0
        let result = await TipManager.performPurchaseIfAllowed(productID: productID) {
            calls += 1
            return "local-result"
        }
        #expect(result == "local-result")
        #expect(calls == 1)
        #expect(TipManager.productIDs.contains(TipManager.koyomiV2BadgeProductID))
        #expect(SupporterTier.koyomi.imageName == "KoyomiV2Badge")
    }
}
