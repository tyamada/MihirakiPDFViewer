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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 表示設定
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "display_settings"))
                        .font(.headline)
                    Toggle(String(localized: "high_quality_rendering", defaultValue: "High Quality"), isOn: Binding(
                        get: { viewModel.settings.isHighQualityRenderingEnabled },
                        set: { viewModel.settings.isHighQualityRenderingEnabled = $0 }
                    ))
                    Toggle(String(localized: "sharpness", defaultValue: "Sharpness"), isOn: Binding(
                        get: { viewModel.settings.isSharpnessEnabled },
                        set: { viewModel.settings.isSharpnessEnabled = $0 }
                    ))
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
                    NavigationLink(destination: ResetSettingsView(viewModel: viewModel)) {
                        Text(String(localized: "reset_title", defaultValue: "Reset"))
                    }
                    .accessibilityIdentifier("resetSettingsButton")
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
                
                // ヘルプ
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "help_title", defaultValue: "Help"))
                        .font(.headline)
                    NavigationLink(destination: HelpView()) {
                        Text(String(localized: "help_title", defaultValue: "Help"))
                    }
                    .accessibilityIdentifier("helpButton")
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

struct ResetSettingsView: View {
    @ObservedObject var viewModel: PDFViewerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingResetConfirmation = false
    @State private var isResetting = false

    private var backgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(String(localized: "reset_settings_message", defaultValue: "This will reset the app settings."))
                .font(.body)
                .foregroundColor(textColor)

            Text(String(localized: "reset_app_icon_warning", defaultValue: "If you have changed the app icon, it cannot be restored after reset!"))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.red)

            Spacer()

            HStack(spacing: 12) {
                Button(String(localized: "cancel")) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("cancelResetButton")

                Button(String(localized: "reset_title", defaultValue: "Reset"), role: .destructive) {
                    isShowingResetConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(isResetting)
                .accessibilityIdentifier("confirmResetButton")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundColor(textColor)
        .background(backgroundColor)
        .accessibilityIdentifier("resetSettingsScreen")
        .navigationTitle(String(localized: "reset_title", defaultValue: "Reset"))
        .alert(
            String(localized: "reset_confirmation_title", defaultValue: "Reset Settings?"),
            isPresented: $isShowingResetConfirmation
        ) {
            Button(String(localized: "cancel"), role: .cancel) {}
            Button(String(localized: "reset_title", defaultValue: "Reset"), role: .destructive) {
                resetSettings()
            }
        } message: {
            Text(String(localized: "reset_confirmation_message", defaultValue: "This will reset the cover page setting, app icon, and close the current document."))
        }
    }

    private func resetSettings() {
        isResetting = true
        Task {
            _ = await TipManager.shared.changeAppIcon(named: nil)
            viewModel.resetApplicationSettings()
            isResetting = false
            dismiss()
        }
    }
}

struct HelpView: View {
    @Environment(\.colorScheme) private var colorScheme

    private struct HelpItem: Identifiable {
        let id: Int
        let titleKey: String
        let titleDefaultValue: String
        let descriptionKey: String
        let descriptionDefaultValue: String
    }

    private let helpItems: [HelpItem] = [
        HelpItem(
            id: 1,
            titleKey: "help_open_pdf_title",
            titleDefaultValue: "Open PDF",
            descriptionKey: "help_open_pdf_description",
            descriptionDefaultValue: "Use the file picker to select a PDF file from your device or iCloud Drive."
        ),
        HelpItem(
            id: 2,
            titleKey: "help_navigate_pages_title",
            titleDefaultValue: "Navigate Pages",
            descriptionKey: "help_navigate_pages_description",
            descriptionDefaultValue: "Switch pages by swiping or using the slider."
        ),
        HelpItem(
            id: 3,
            titleKey: "help_menu_title",
            titleDefaultValue: "Menu",
            descriptionKey: "help_menu_description",
            descriptionDefaultValue: "Tap the screen to toggle the visibility of the toolbar and slider."
        ),
        HelpItem(
            id: 4,
            titleKey: "help_zoom_title",
            titleDefaultValue: "Zoom",
            descriptionKey: "help_zoom_description",
            descriptionDefaultValue: "Pinch to zoom in or out. Long-press and drag to scroll while zoomed in."
        ),
        HelpItem(
            id: 5,
            titleKey: "help_search_title",
            titleDefaultValue: "Search",
            descriptionKey: "help_search_description",
            descriptionDefaultValue: "Enter text into the search bar to find specific content within the PDF."
        ),
        HelpItem(
            id: 6,
            titleKey: "help_layout_title",
            titleDefaultValue: "Layout",
            descriptionKey: "help_layout_description",
            descriptionDefaultValue: "Use the layout options in the menu to switch between single-page and two-page views."
        )
    ]

    private var backgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private func localizedHelpText(key: String, defaultValue: String) -> String {
        NSLocalizedString(key, bundle: .main, value: defaultValue, comment: "")
    }

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(helpItems, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(item.id). \(localizedHelpText(key: item.titleKey, defaultValue: item.titleDefaultValue))")
                            .font(.headline)
                        Text(localizedHelpText(key: item.descriptionKey, defaultValue: item.descriptionDefaultValue))
                            .font(.body)
                    }
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .background(backgroundColor)
        }
        .foregroundColor(textColor)
        .background(backgroundColor)
        .accessibilityIdentifier("helpScreen")
        .navigationTitle(String(localized: "help_title", defaultValue: "Help"))
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
