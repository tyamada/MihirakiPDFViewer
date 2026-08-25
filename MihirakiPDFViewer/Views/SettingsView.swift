//
// SettingView.swift
// MihirakiPDFViewer
//
// Created by Cline on 2026/07/02.
// Reviewed & Updated by Takuma Yamada.
//
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
    @Environment(\.colorScheme) private var colorScheme
    
    public init(viewModel: PDFViewerViewModel) {
        self.viewModel = viewModel
    }

    private var settingsBackgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var settingsTextColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private func metadataDisplayValue(_ value: String?) -> String {
        value ?? String(localized: "not_available", defaultValue: "Not available")
    }

    private func documentInfoRow(label: String, value: String?) -> some View {
        Text("\(label): \(metadataDisplayValue(value))")
            .foregroundColor(settingsTextColor)
            .padding(.horizontal, 2)
            .background(settingsBackgroundColor)
    }

    public var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 24) {
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
                .padding(1)
                .background(settingsBackgroundColor)

                // オプション
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "options"))
                        .font(.headline)
                    Text(String(localized: "cover_page_setting_label", defaultValue: "Cover Page Setting"))
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
                .padding(1)
                .background(settingsBackgroundColor)
                
                // ドキュメント情報
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "doc_info"))
                        .font(.headline)
                    if let doc = viewModel.document {
                        VStack(alignment: .leading, spacing: 4) {
                            documentInfoRow(label: String(localized: "pdf_title_label", defaultValue: "Title"), value: doc.title)
                            documentInfoRow(label: String(localized: "pdf_author_label", defaultValue: "Author"), value: doc.author)
                            documentInfoRow(label: String(localized: "pdf_subtitle_label", defaultValue: "Subtitle"), value: doc.subtitle)
                            documentInfoRow(label: String(localized: "pdf_keywords_label", defaultValue: "Keywords"), value: doc.keywords)
                            documentInfoRow(label: String(localized: "pdf_version_label", defaultValue: "PDF Version"), value: doc.pdfVersion)
                            Text(String(localized: "total_pages", defaultValue: "\(doc.totalPageCount)"))
                                .foregroundColor(settingsTextColor)
                                .padding(.horizontal, 2)
                                .background(settingsBackgroundColor)
                            Text("\(String(localized: "page_layout")): \(doc.pageLayout.displayName)")
                                .foregroundColor(settingsTextColor)
                                .padding(.horizontal, 2)
                                .background(settingsBackgroundColor)
                            Text("\(String(localized: "scroll_direction")): \(doc.layoutDirection == .rightToLeft ? "R2L" : "L2R")")
                                .foregroundColor(settingsTextColor)
                                .padding(.horizontal, 2)
                                .background(settingsBackgroundColor)
                        }
                        .foregroundColor(settingsTextColor)
                    } else {
                        Text(String(localized: "no_doc"))
                            .font(.caption)
                            .foregroundColor(settingsTextColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(1)
                .background(settingsBackgroundColor)
                
                // アプリ情報
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "app_info"))
                        .font(.headline)
                        .foregroundColor(settingsTextColor)
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
                    .foregroundColor(settingsTextColor)
                    .accessibilityElement(children: .combine)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(1)
                .background(settingsBackgroundColor)

                // 開発者への応援 (Tip)
                VStack(alignment: .center, spacing: 12) {
                    Divider()
                    Text(String(localized: "developer_support_title", defaultValue: "Support the Developer"))
                        .font(.headline)
                    Text(String(localized: "developer_support_description", defaultValue: "Your support helps keep the app updated. You can use all features without making a purchase."))
                        .font(.body)
                        .foregroundColor(settingsTextColor)
                        .multilineTextAlignment(.center)
                    
                    NavigationLink(destination: TipSelectionView(tipManager: TipManager.shared)) {
                        Text(String(localized: "tip_selection_title", defaultValue: "Support"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("supportButton")
                    .accessibilityHint(String(localized: "support_button_accessibility_hint", defaultValue: "Opens the tip selection screen."))
                }
                .padding(.vertical)
                .background(settingsBackgroundColor)
            }
            .padding()
            .background(settingsBackgroundColor)
        }
        .foregroundColor(settingsTextColor)
        .background(settingsBackgroundColor)
        .accessibilityIdentifier("settingsScreen")
        .navigationTitle(String(localized: "settings"))
    }
}

struct TipSelectionView: View {
    @ObservedObject var tipManager: TipManager
    @Environment(\.purchase) private var purchaseAction
    @Environment(\.colorScheme) private var colorScheme
    @State private var purchasingProductID: String?

    private var settingsTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        List {
            Section {
                if let errorMessage = tipManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(settingsTextColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)
                } else if tipManager.products.isEmpty {
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

                                Image(tipIconName(for: product.id))

                                    .resizable()

                                    .scaledToFill()

                                    .frame(width: 44, height: 44)

                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tipDisplayName(for: product.id))
                                        .font(.headline)
                                    Text(tipDescription(for: product.id))
                                        .font(.caption)
                                        .foregroundColor(settingsTextColor)
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
                        .accessibilityIdentifier("tipProductButton_\(product.id)")
                    }
                }
            } footer: {
                Text(String(localized: "developer_support_description", defaultValue: "Your support helps keep the app updated. You can use all features without making a purchase."))
                    .font(.body)
                    .foregroundColor(settingsTextColor)
            }
        }
        .accessibilityIdentifier("tipSelectionScreen")
        .navigationTitle(String(localized: "tip_selection_title", defaultValue: "Support"))
        .task {
            await tipManager.updateStorefront()
        }
    }

    private func tipIconName(for productID: String) -> String {
        switch productID {
        case "tip_100":
            return "TipIconBronze"
        case "tip_500":
            return "TipIconSilver"
        case "tip_1000":
            return "TipIconGold"
        default:
            return "TipIconGold"
        }
    }

    private func tipDisplayName(for productID: String) -> LocalizedStringResource {
        switch productID {
        case "tip_100":
            return "tip_100_name"
        case "tip_500":
            return "tip_500_name"
        case "tip_1000":
            return "tip_1000_name"
        default:
            return "tip_selection_title"
        }
    }

    private func tipDescription(for productID: String) -> LocalizedStringResource {
        switch productID {
        case "tip_100":
            return "tip_100_description"
        case "tip_500":
            return "tip_500_description"
        case "tip_1000":
            return "tip_1000_description"
        default:
            return "developer_support_description"
        }
    }

    private func purchase(_ product: Product) {
        purchasingProductID = product.id
        Task {
            await tipManager.purchase(product, using: purchaseAction)
            purchasingProductID = nil
        }
    }
}
