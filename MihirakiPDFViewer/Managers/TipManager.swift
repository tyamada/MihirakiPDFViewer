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

import Combine
import Foundation
import StoreKit
import SwiftUI
import UIKit

/// 投げ銭（チップ）の購入と管理を行うマネージャー
@MainActor
public class TipManager: ObservableObject {
    public static let shared = TipManager()
    
    // 定義された商品ID
    public static let productIDs = [
        "supporter_icon_bronze",
        "supporter_icon_silver",
        "supporter_icon_gold"
    ]
    
    @Published public private(set) var products: [Product] = []
    @Published public var isPurchaseSuccess: Bool = false
    @Published public var lastPurchasedProductID: String? = nil
    @Published public private(set) var pendingAppIconName: String? = nil
    @Published public private(set) var ownedProductIDs: Set<String> = []
    @Published public private(set) var isRestoringPurchases = false
    @Published public private(set) var restoreMessage: String? = nil
    @Published public private(set) var currentAppIconName: String? = UIApplication.shared.alternateIconName
    @Published public private(set) var errorMessage: String? = nil
    
    private var transactionUpdates: Task<Void, Never>?
    private var purchaseIntentUpdates: Task<Void, Never>?
    
    private init() {
        Task {
            await updateStorefront()
            await refreshEntitlements()
            startListeningForTransactions()
            startListeningForPurchaseIntents()
        }
    }
    
    /// 商品情報を取得して更新する
    public func updateStorefront() async {
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

    private func purchase(_ product: Product, purchaseAction: () async throws -> Product.PurchaseResult) async {
        do {
            let result = try await purchaseAction()
            
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
            return "AppIcon"
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
        var currentProductIDs: Set<String> = []

        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else {
                continue
            }
            currentProductIDs.insert(transaction.productID)
        }

        ownedProductIDs = currentProductIDs
    }

    public func restorePurchases() async {
        guard !isRestoringPurchases else { return }

        isRestoringPurchases = true
        restoreMessage = nil
        let previousProductIDs = ownedProductIDs

        do {
            try await AppStore.sync()
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
