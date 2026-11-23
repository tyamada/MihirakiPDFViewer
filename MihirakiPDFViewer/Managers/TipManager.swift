//
// TipManager.swift
// MihirakiPDFViewer
//
// Created by Cline on 2026/08/16.
// Reviewed & Updated by Takuma Yamada.
//
// Copyright 2026 Takuma Yamada.
//
// This software is released under the MIT License.
// For the full license text, please see the LICENSE file in the root directory.
//

import Foundation
import Observation
import StoreKit
import SwiftUI
import UIKit

enum SupporterTier: String, CaseIterable, Identifiable {
    case bronze = "supporter_icon_bronze"
    case silver = "supporter_icon_silver"
    case gold = "supporter_icon_gold"
    case koyomi = "supporter_badge_koyomi_v2"

    var id: String { rawValue }

    var name: LocalizedStringResource {
        switch self {
        case .bronze: "Bronze Supporter"
        case .silver: "Silver Supporter"
        case .gold: "Gold Supporter"
        case .koyomi: LocalizedStringResource("koyomi_v2_badge_name", defaultValue: "Release Commemorative Koyomi Badge")
        }
    }

    var imageName: String {
        switch self {
        case .bronze: "TipIconBronze"
        case .silver: "TipIconSilver"
        case .gold: "TipIconGold"
        case .koyomi: "KoyomiV2Badge"
        }
    }
}

/// 投げ銭（チップ）の購入と管理を行うマネージャー
@MainActor
@Observable
public class TipManager {
    public static let shared = TipManager()

    public static let koyomiV2BadgeProductID = "supporter_badge_koyomi_v2"
    
    // 定義された商品ID
    public static let productIDs = [
        "supporter_icon_bronze",
        "supporter_icon_silver",
        "supporter_icon_gold",
        koyomiV2BadgeProductID
    ]
    
    public private(set) var products: [Product] = []
    public var isPurchaseSuccess: Bool = false
    public var lastPurchasedProductID: String? = nil
    public private(set) var pendingAppIconName: String? = nil
    public private(set) var ownedProductIDs: Set<String> = []
    public private(set) var isRestoringPurchases = false
    public private(set) var restoreMessage: String? = nil
    public private(set) var currentAppIconName: String? = UIApplication.shared.alternateIconName
    public private(set) var errorMessage: String? = nil
    
    @ObservationIgnored
    private var transactionUpdates: Task<Void, Never>?
    @ObservationIgnored
    private var purchaseIntentUpdates: Task<Void, Never>?
    
    // Test hosts and UI tests opt in only on a Debug simulator. Release behavior
    // is unchanged; local validation never starts StoreKit account operations.
    private static var isOfflineValidation: Bool {
#if DEBUG && targetEnvironment(simulator)
        ProcessInfo.processInfo.environment["MIHIRAKI_OFFLINE_VALIDATION"] == "1"
#else
        false
#endif
    }

    private let skipsStoreOperations: Bool
    private let koyomiGrant: KoyomiGrantController
    private let synchronizePurchases: @MainActor () async throws -> Void
    private let readOwnedProducts: @MainActor () async -> Set<String>

    private init() {
        skipsStoreOperations = Self.isOfflineValidation
        koyomiGrant = KoyomiGrantController(
            deadline: KoyomiGrantDeadline.production, store: UserDefaultsKoyomiGrantStore())
        synchronizePurchases = { try await AppStore.sync() }
        readOwnedProducts = { await Self.currentOwnedProducts() }
        guard !skipsStoreOperations else { return }
        Task {
            await updateStorefront()
            await refreshEntitlements()
            startListeningForTransactions()
            startListeningForPurchaseIntents()
        }
    }
    
    // Fixture construction is absent from Release and never selected by launch settings.
#if DEBUG
    init(testGrant: KoyomiGrantController, ownedProductIDs: Set<String> = [],
         synchronizePurchases: @escaping @MainActor () async throws -> Void = {},
         readOwnedProducts: @escaping @MainActor () async -> Set<String> = { [] }) {
        skipsStoreOperations = false
        koyomiGrant = testGrant
        self.ownedProductIDs = ownedProductIDs
        self.synchronizePurchases = synchronizePurchases
        self.readOwnedProducts = readOwnedProducts
    }
#endif

    var isShowingKoyomiGrantNotification: Bool { koyomiGrant.hasNewGrantNotification }

    func dismissKoyomiGrantNotification() { koyomiGrant.dismissNotification() }

    var hasKoyomiBadge: Bool {
        koyomiGrant.state == .eligible || isPurchased(Self.koyomiV2BadgeProductID)
    }

    var displayedSupporterTiers: [SupporterTier] {
        SupporterTier.allCases.filter { tier in
            tier == .koyomi ? hasKoyomiBadge : isPurchased(tier.rawValue)
        }
    }

    func recheckKoyomiEligibility() async {
        guard !skipsStoreOperations else { return }
        await koyomiGrant.recheck()
    }

    // Rechecks only the local grant; this never refreshes the App Store transaction.
    func refreshKoyomiEligibilityByUserRequest() async {
        guard !skipsStoreOperations else { return }
        await koyomiGrant.refreshByUserRequest()
    }

    /// 商品情報を取得して更新する
    public func updateStorefront() async {
        guard !skipsStoreOperations else { return }
        do {
            let storeProducts = try await Product.products(for: Self.productIDs)
            self.products = storeProducts.sorted(by: { $0.price < $1.price })
            self.errorMessage = nil
        } catch {
            print("Failed to fetch products: \(error)")
            self.errorMessage = String(localized: "store_products_fetch_failed", defaultValue: "Could not load tip products. Please try again later.")
        }
    }
    
    /// 購入処理を開始する
    public func purchase(_ product: Product) async {
        await purchase(product) {
            try await product.purchase()
        }
    }

    /// SwiftUIの購入アクションを使って購入処理を開始する
    public func purchase(_ product: Product, using purchaseAction: PurchaseAction) async {
        await purchase(product) {
            try await purchaseAction(product)
        }
    }

    // This gate applies to direct, SwiftUI, and external PurchaseIntent starts.
    // Entitlement recognition, transaction updates and restoration do not use it.
    static func isNewPurchaseAllowed(for productID: String) -> Bool {
        [SupporterTier.bronze.rawValue, SupporterTier.silver.rawValue,
         SupporterTier.gold.rawValue].contains(productID)
    }

    static func performPurchaseIfAllowed<Result>(
        productID: String,
        purchaseAction: () async throws -> Result
    ) async rethrows -> Result? {
        guard isNewPurchaseAllowed(for: productID) else { return nil }
        return try await purchaseAction()
    }

    private func purchase(_ product: Product, purchaseAction: () async throws -> Product.PurchaseResult) async {
        guard !skipsStoreOperations else { return }
        do {
            guard let result = try await Self.performPurchaseIfAllowed(
                productID: product.id, purchaseAction: purchaseAction
            ) else { return }
            
            switch result {
            case .success(let verification):
                // 購入検証
                switch verification {
                case .verified(let transaction):
                    // 購入成功
                    await handleTransaction(transaction, marksPurchaseSuccess: true)
                case .unverified(_, let error):
                    // 検証に失敗（不正な可能性がある）
                    print("Transaction unverified: \(error)")
                    self.errorMessage = String(localized: "purchase_verification_failed", defaultValue: "Could not verify the purchase.")
                }
            case .userCancelled:
                // ユーザーがキャンセル
                break
            case .pending:
                // 承認待ち（保護者による承認など）
                break
            @unknown default:
                break
            }
        } catch {
            print("Purchase failed: \(error)")
            self.errorMessage = String(localized: "purchase_failed", defaultValue: "The purchase could not be completed.")
        }
    }
    
    /// トランザクションを処理し、結果を反映する
    private func handleTransaction(_ transaction: StoreKit.Transaction, marksPurchaseSuccess: Bool = false) async {
        guard Self.productIDs.contains(transaction.productID) else {
            return
        }

        if transaction.revocationDate == nil {
            ownedProductIDs.insert(transaction.productID)
        } else {
            ownedProductIDs.remove(transaction.productID)
        }

        await transaction.finish()

        if marksPurchaseSuccess {
            self.lastPurchasedProductID = transaction.productID
            self.pendingAppIconName = Self.appIconName(for: transaction.productID)
            self.isPurchaseSuccess = true
        }

        print("Transaction handled successfully: \(transaction.productID)")
    }

    static func appIconName(for productID: String) -> String? {
        switch productID {
        case "supporter_icon_bronze":
            return "AppIconBronze"
        case "supporter_icon_silver":
            return "AppIconSilver"
        case "supporter_icon_gold":
            return "AppIconGold"
        default:
            return nil
        }
    }
    
    /// トランザクションの更新を監視する（アプリ起動時などの再開用）
    private func startListeningForTransactions() {
        transactionUpdates?.cancel()
        transactionUpdates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                switch result {
                case .verified(let transaction):
                    await self?.handleTransaction(transaction)
                case .unverified(_, let error):
                    print("Transaction update unverified: \(error)")
                    self?.errorMessage = String(localized: "purchase_verification_failed", defaultValue: "Could not verify the purchase.")
                }
            }
        }
    }

    private func startListeningForPurchaseIntents() {
        purchaseIntentUpdates?.cancel()
        purchaseIntentUpdates = Task { [weak self] in
            for await purchaseIntent in PurchaseIntent.intents {
                await self?.purchase(purchaseIntent.product)
            }
        }
    }
    
    /// アプリのアイコンを変更する
    /// - Parameter iconName: Assetsに登録されているアイコン名
    @discardableResult
    public func changeAppIcon(named iconName: String?) async -> Bool {
        if let iconName {
            let ownsIcon = ownedProductIDs.contains { Self.appIconName(for: $0) == iconName }
            guard ownsIcon else {
                errorMessage = String(localized: "supporter_icon_not_owned", defaultValue: "Purchase this supporter icon before using it.")
                return false
            }
        }

        // iOSでアイコンを変更するには、Info.plistに代替アイコンの設定が必要
        // iconNameがnilの場合はデフォルトに戻す
        guard UIApplication.shared.supportsAlternateIcons else {
            print("Alternate app icons are not supported in this environment.")
            errorMessage = String(localized: "alternate_app_icons_not_supported", defaultValue: "Alternate app icons are not supported in this environment.")
            return false
        }

        guard UIApplication.shared.alternateIconName != iconName else {
            print("App icon is already set to \(iconName ?? "primary").")
            return true
        }

        do {
            try await UIApplication.shared.setAlternateIconName(iconName)
            currentAppIconName = iconName
            print("Changed app icon to \(iconName ?? "primary").")
            errorMessage = nil
            return true
        } catch {
            print("Failed to change app icon to \(iconName ?? "primary"): \(error)")
            errorMessage = String(localized: "app_icon_change_failed", defaultValue: "Could not change the app icon.")
            return false
        }
    }
    
    /// 購入成功フラグをリセットする
    public func resetSuccessFlag() {
        isPurchaseSuccess = false
        lastPurchasedProductID = nil
        pendingAppIconName = nil
    }

    public func clearError() {
        errorMessage = nil
    }

    public func isPurchased(_ productID: String) -> Bool {
        ownedProductIDs.contains(productID)
    }

    public func refreshEntitlements() async {
        guard !skipsStoreOperations else { return }
        ownedProductIDs = await readOwnedProducts()
    }

    private static func currentOwnedProducts() async -> Set<String> {
        var currentProductIDs: Set<String> = []

        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else {
                continue
            }
            currentProductIDs.insert(transaction.productID)
        }

        return currentProductIDs
    }

    public func restorePurchases() async {
        guard !skipsStoreOperations else { return }
        guard !isRestoringPurchases else { return }

        isRestoringPurchases = true
        restoreMessage = nil
        let previousProductIDs = ownedProductIDs

        do {
            try await synchronizePurchases()
            await refreshEntitlements()
            restoreMessage = ownedProductIDs.isEmpty
                ? String(localized: "no_purchases_to_restore", defaultValue: "No purchases were available to restore.")
                : String(localized: "purchases_restored", defaultValue: "Your purchases have been restored.")
            errorMessage = nil
        } catch {
            ownedProductIDs = previousProductIDs
            errorMessage = String(localized: "restore_purchases_failed", defaultValue: "Purchases could not be restored. Please try again.")
        }

        isRestoringPurchases = false
    }

    public func clearRestoreMessage() {
        restoreMessage = nil
    }
}

// The free badge is a device-local claim, separate from StoreKit purchases.
// It needs no account/acquisition lookup and no network to grant or redisplay.
struct KoyomiGrantDeadline: Equatable {
    let end: Date

    // Last claim day: 2027-12-31 JST (exclusive end: 2028-01-01 00:00 JST).
    static let production = KoyomiGrantDeadline(
        end: Date(timeIntervalSince1970: 1_830_265_200))

    init?(end: Date) {
        guard end.timeIntervalSince1970.isFinite else { return nil }
        self.end = end
    }

    func contains(_ date: Date) -> Bool {
        date.timeIntervalSince1970.isFinite && date < end
    }
}

@MainActor
protocol KoyomiGrantStoring {
    var isGranted: Bool { get }
    func saveGrant() -> Bool
}

@MainActor
final class UserDefaultsKoyomiGrantStore: KoyomiGrantStoring {
    private let defaults: UserDefaults
    private let key = "koyomi_auto_granted_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isGranted: Bool { defaults.bool(forKey: key) }

    func saveGrant() -> Bool {
        defaults.set(true, forKey: key)
        return isGranted
    }
}

@MainActor
@Observable
final class KoyomiGrantController {
    enum State: Equatable {
        case disabled
        case pending
        case eligible
        case ineligible
    }

    private(set) var state: State
    private(set) var isChecking = false
    private(set) var hasNewGrantNotification = false
    private let deadline: KoyomiGrantDeadline?
    private let store: any KoyomiGrantStoring
    private let now: @MainActor () -> Date

    init(deadline: KoyomiGrantDeadline?, store: any KoyomiGrantStoring,
         now: @escaping @MainActor () -> Date = { Date() }) {
        self.deadline = deadline
        self.store = store
        self.now = now
        state = store.isGranted ? .eligible : (deadline == nil ? .disabled : .pending)
    }

    func recheck() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        // A saved badge never expires, including when the clock or deadline changes.
        guard !store.isGranted else { state = .eligible; return }
        guard let deadline else { state = .disabled; return }
        let date = now()
        guard date.timeIntervalSince1970.isFinite else { state = .pending; return }
        guard deadline.contains(date) else { state = .ineligible; return }
        // Do not claim durable success until the local store reads the saved value.
        if store.saveGrant() {
            state = .eligible
            hasNewGrantNotification = true
        } else {
            state = .pending
        }
    }

    func dismissNotification() { hasNewGrantNotification = false }

    func refreshByUserRequest() async {
        await recheck()
    }
}
