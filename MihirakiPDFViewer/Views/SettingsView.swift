//
// SettingView.swift
// MihirakiPDFViewer
//
// Created by Takuma Yamada on 2026/08/14.
// Copyright 2026 Takuma Yamada.
//
// This software is released under the MIT License.
// For the full license text, please see the LICENSE file in the root directory.
//

import StoreKit
import SwiftUI

/// 設定変更を行うためのビュー
public struct SettingsView: View {
    @ObservedObject var viewModel: PDFViewerViewModel
    @Environment(\.dismiss) var dismiss
    
    public init(viewModel: PDFViewerViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 画面設定
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "screen_settings"))
                        .font(.headline)
                    Toggle(String(localized: "is_slider_enabled", defaultValue: "Slider Display"), isOn: Binding(
                            get: { viewModel.settings.isSliderEnabled },
                            set: { viewModel.settings.isSliderEnabled = $0 }
                        ))
                    Toggle(String(localized: "is_searchbar_enabled", defaultValue: "Search Bar"), isOn: Binding(
                            get: { viewModel.settings.isSearchbarEnabled },
                            set: { viewModel.settings.isSearchbarEnabled = $0 }
                        ))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 表示設定
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "display_settings"))
                        .font(.headline)
                    Toggle(String(localized: "is_spread_view"), isOn: Binding(
                        get: { viewModel.settings.isSpreadViewEnabled },
                        set: { viewModel.settings.isSpreadViewEnabled = $0 }
                    ))
                     Toggle(String(localized: "is_cover_page"), isOn: Binding(
                        get: { viewModel.settings.isCoverPageEnabled },
                        set: { viewModel.settings.isCoverPageEnabled = $0 }
                    ))
                    Text(String(localized: "scroll_direction"))
                    Picker("Direction", selection: Binding(
                        get: { viewModel.settings.layoutDirection },
                        set: { viewModel.settings.layoutDirection = $0 }
                    )) {
                        Text(String(localized: "dir_l2r")).tag(LayoutDirection.leftToRight)
                        Text(String(localized: "dir_r2l")).tag(LayoutDirection.rightToLeft)
                    }
                        .pickerStyle(.segmented)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // オプション
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "options"))
                        .font(.headline)
                    Text(String(localized: "cover_page_setting_label"))
                    Picker(String(localized: "cover_page_setting_label", defaultValue: "Cover Page Setting"), selection: Binding(
                        get: { viewModel.settings.coverPageSetting },
                        set: { viewModel.settings.coverPageSetting = $0 }
                    )) {
                        Text(String(localized: "TypeA")).tag(CoverPageSetting.typeA)
                        Text(String(localized: "TypeB")).tag(CoverPageSetting.typeB)
                    }
                       .pickerStyle(.segmented)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // ドキュメント情報
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "doc_info"))
                        .font(.headline)
                    if let doc = viewModel.document {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "total_pages", defaultValue: "\(doc.totalPageCount)"))
                            Text("\(String(localized: "layout")): \(doc.pageLayout.displayName)")
                            Text("\(String(localized: "direction")): \(doc.layoutDirection == .rightToLeft ? "R2L" : "L2R")")
                        }
                        .foregroundColor(.secondary)
                    } else {
                        Text(String(localized: "no_doc"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // アプリ情報
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "app_info"))
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(String(localized: "app_name_label"))
                            Spacer()
                             Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "PDFViewer")
                        }
                        HStack {
                            Text(String(localized: "version_label"))
                            Spacer()
                             Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        }
                        HStack {
                            Text(String(localized: "copyright_label"))
                            Spacer()
                             Text(String(localized: "copyright"))
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 開発者への応援 (Tip)
                VStack(alignment: .center, spacing: 12) {
                    Divider()
                    Text(String(localized: "developer_support_title", defaultValue: "開発者への応援"))
                        .font(.headline)
                    Text(String(localized: "developer_support_description", defaultValue: "あなたの応援が、アプリの継続的なアップデートに繋がります。購入しなくてもすべての機能を使用できます。"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    NavigationLink(destination: TipSelectionView(tipManager: TipManager.shared)) {
                        Text(String(localized: "tip_selection_title", defaultValue: "応援する"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 24)
                            .background(Color.blue)
                            .cornerRadius(20)
                    }
                }
                .padding(.vertical)
            }
            .padding()
        }
        .navigationTitle(String(localized: "settings"))
    }
}

struct TipSelectionView: View {
    @ObservedObject var tipManager: TipManager
    @State private var purchasingProductID: String?

    var body: some View {
        List {
            Section {
                if tipManager.products.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical)
                } else {
                    ForEach(tipManager.products, id: \.id) { product in
                        Button {
                            purchase(product)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.displayName)
                                        .font(.headline)
                                    Text(product.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if purchasingProductID == product.id {
                                    ProgressView()
                                } else {
                                    Text(product.displayPrice)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .disabled(purchasingProductID != nil)
                    }
                }
            } footer: {
                Text(String(localized: "developer_support_description", defaultValue: "あなたの応援が、アプリの継続的なアップデートに繋がります。購入しなくてもすべての機能を使用できます。"))
            }
        }
        .navigationTitle(String(localized: "tip_selection_title", defaultValue: "応援する"))
        .task {
            await tipManager.updateStorefront()
        }
    }

    private func purchase(_ product: Product) {
        purchasingProductID = product.id
        Task {
            await tipManager.purchase(product)
            purchasingProductID = nil
        }
    }
}
