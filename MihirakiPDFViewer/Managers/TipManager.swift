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
        "tip_100",
        "tip_500",
        "tip_1000"
    ]
    
    @Published public private(set) var products: [Product] = []
    @Published public var isPurchaseSuccess: Bool = false
    @Published public var lastPurchasedProductID: String? = nil
    @Published public private(set) var pendingAppIconName: String? = nil
    @Published public private(set) var errorMessage: String? = nil
    
    private var transactionUpdates: Task<Void, Never>?
    
    private init() {
        Task {
            await updateStorefront()
            startListeningForTransactions()
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
                    await handleTransaction(transaction)
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
    private func handleTransaction(_ transaction: StoreKit.Transaction) async {
        await transaction.finish()

        self.lastPurchasedProductID = transaction.productID
        self.pendingAppIconName = Self.appIconName(for: transaction.productID)
        self.isPurchaseSuccess = true

        print("Transaction handled successfully: \(transaction.productID)")
    }

    static func appIconName(for productID: String) -> String? {
        switch productID {
        case "tip_100":
            return "AppIconBronze"
        case "tip_500":
            return "AppIconSilver"
        case "tip_1000":
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
    
    /// アプリのアイコンを変更する
    /// - Parameter iconName: Assetsに登録されているアイコン名
    @discardableResult
    public func changeAppIcon(named iconName: String?) async -> Bool {
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
}
