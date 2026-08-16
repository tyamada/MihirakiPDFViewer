//
// TipSelectionView.swift
// MihirakiPDFViewer
//
// Created by Cline on 2026/08/16.
//

import SwiftUI
import StoreKit

/// 投げ銭（チップ）を選択するためのビュー
public struct TipSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var tipManager: TipManager
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text(String(localized: "developer_support_title", defaultValue: "開発者への応援"))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(String(localized: "developer_support_description", defaultValue: "あなたの応援が、アプリの継続的なアップデートに繋がります。購入しなくてもすべての機能を使用できます。"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        ForEach(tipManager.products) { product in
                            Button(action: {
                                Task {
                                    await tipManager.purchase(product)
                                }
                            }) {
                                HStack {
                                    Text(product.displayPrice)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.red)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    if !tipManager.products.isEmpty {
                        Text("※購入はApp Storeを通じて行われます。")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(String(localized: "tip_selection_title", defaultValue: "応援を選択"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}