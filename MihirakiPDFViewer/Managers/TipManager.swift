//
// TipManager.swift
// MihirakiPDFViewer
//
// Created by Cline on 2026/08/16.
//

import Foundation
import StoreKit
import SwiftUI

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
    
    private var transactionUpdates: Task<Void, Never>?
    
    private init() {
        Task {
            await updateStorefront()
            await startListeningForTransactions()
        }
    }
    
    /// 商品情報を取得して更新する
    public func updateStorefront() async {
        do {
            let storeProducts = try await Product.products(for: Self.productIDs)
            self.products = storeProducts.sorted(by: { $0.price < $1.price })
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }
    
    /// 購入処理を開始する
    public func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            
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
        }
    }
    
    /// トランザクションを処理し、結果を反映する
    private func handleTransaction(_ transaction: Transaction) async {
        await transaction.finish()
        
        // 成功を通知
        self.lastPurchasedProductID = transaction.productID
        self.isPurchaseSuccess = true
        
        // アイコンの変更（もし特定の条件があれば。ここではとりあえず購入したらアイコンが変わる例も考えられるが、
        // 今回は「投げ銭をした際にお礼」をメインとする）
        // 必要に応じてここでアイコン変更メソッドを呼ぶ
        print("Transaction handled successfully: \(transaction.productID)")
    }
    
    /// トランザクションの更新を監視する（アプリ起動時などの再開用）
    private func startListeningForTransactions() {
        transactionUpdates?.cancel()
        transactionUpdates = Task.detached {
            for await result in Transaction.updates {
                await self.handleTransaction(result)
            }
        }
    }
    
    /// アプリのアイコンを変更する
    /// - Parameter iconName: Assetsに登録されているアイコン名
    public func changeAppIcon(named iconName: String?) {
        // iOSでアイコンを変更するには、Info.plistに代替アイコンの設定が必要
        // iconNameがnilの場合はデフォルトに戻す
        UIApplication.shared.setApplicationIconName(iconName)
    }
    
    /// 購入成功フラグをリセットする
    public func resetSuccessFlag() {
        isPurchaseSuccess = false
        lastPurchasedProductID = nil
    }
}