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

                    DeviceTestingSettingsSection()
                    AppLoggingSettingsSection()

                    NavigationLink(destination: ResetSettingsView(viewModel: viewModel)) {
                        Text(String(localized: "reset_title", defaultValue: "Reset"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .accessibilityIdentifier("resetSettingsButton")
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
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
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
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    Text(String(localized: "developer_support_title", defaultValue: "Support the Developer"))
                        .font(.headline)
                    Text(String(localized: "developer_support_description", defaultValue: "Your support helps keep the app updated. You can use all features without making a purchase."))
                        .font(.body)
                        .foregroundColor(settingsTextColor)
                        .multilineTextAlignment(.leading)
                    
                    NavigationLink(destination: TipSelectionView(tipManager: TipManager.shared)) {
                        Text(String(localized: "tip_selection_title", defaultValue: "Support"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("supportButton")
                    .accessibilityHint(String(localized: "supporter_icon_store_accessibility_hint", defaultValue: "Opens the supporter icon store."))
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

private struct DeviceTestingSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                DeviceTestView()
            } label: {
                Label("Run tests on this device", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("runDeviceTestsButton")
        }
        .padding(.vertical)
    }
}

private struct AppLoggingSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                AppLogView()
            } label: {
                Label("View app logs", systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("viewAppLogsButton")
        }
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
            Text(String(localized: "reset_settings_and_icon_message", defaultValue: "This resets viewing settings, restores the default app icon, and closes the current document. Purchased supporter icons remain available."))
                .font(.body)
                .foregroundColor(textColor)

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
            Text(String(localized: "reset_settings_and_icon_message", defaultValue: "This resets viewing settings, restores the default app icon, and closes the current document. Purchased supporter icons remain available."))
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

    private struct HelpDetail: Identifiable {
        let id: String
        let title: LocalizedStringResource
        let description: LocalizedStringResource
    }

    private struct HelpItem: Identifiable {
        let id: Int
        let title: LocalizedStringResource
        let description: LocalizedStringResource
        var details: [HelpDetail] = []
    }

    private let helpItems: [HelpItem] = [
        HelpItem(
            id: 1,
            title: LocalizedStringResource("help_open_pdf_title", defaultValue: "Open PDF"),
            description: LocalizedStringResource(
                "help_open_pdf_description",
                defaultValue: "Use the file picker to select a PDF file from your device or iCloud Drive."
            )
        ),
        HelpItem(
            id: 2,
            title: LocalizedStringResource("help_navigate_pages_title", defaultValue: "Navigate Pages"),
            description: LocalizedStringResource(
                "help_navigate_pages_description",
                defaultValue: "Switch pages by swiping or using the slider."
            )
        ),
        HelpItem(
            id: 3,
            title: LocalizedStringResource("help_menu_title", defaultValue: "Menu"),
            description: LocalizedStringResource(
                "help_menu_description",
                defaultValue: "Tap the screen to toggle the visibility of the toolbar and slider."
            )
        ),
        HelpItem(
            id: 4,
            title: LocalizedStringResource("help_zoom_title", defaultValue: "Zoom"),
            description: LocalizedStringResource(
                "help_zoom_description",
                defaultValue: "Pinch to zoom in or out. Long-press and drag to scroll while zoomed in."
            )
        ),
        HelpItem(
            id: 5,
            title: LocalizedStringResource("help_search_title", defaultValue: "Search"),
            description: LocalizedStringResource(
                "help_search_description",
                defaultValue: "Enter text into the search bar to find specific content within the PDF."
            )
        ),
        HelpItem(
            id: 6,
            title: LocalizedStringResource("settings", defaultValue: "Settings"),
            description: LocalizedStringResource(
                "help_settings_description",
                defaultValue: "Use the Settings screen to customize viewing, run on-device tests, review app logs, and check information about the current document and app."
            ),
            details: [
                HelpDetail(
                    id: "highQualityRendering",
                    title: LocalizedStringResource("high_quality_rendering", defaultValue: "High Quality"),
                    description: LocalizedStringResource(
                        "help_setting_high_quality_description",
                        defaultValue: "Renders PDF pages at higher quality."
                    )
                ),
                HelpDetail(
                    id: "sharpness",
                    title: LocalizedStringResource("sharpness", defaultValue: "Sharpness"),
                    description: LocalizedStringResource(
                        "help_setting_sharpness_description",
                        defaultValue: "Makes text and lines appear sharper."
                    )
                ),
                HelpDetail(
                    id: "spreadView",
                    title: LocalizedStringResource("is_spread_view", defaultValue: "Spread View"),
                    description: LocalizedStringResource(
                        "help_setting_spread_view_description",
                        defaultValue: "Displays two pages side by side."
                    )
                ),
                HelpDetail(
                    id: "coverPage",
                    title: LocalizedStringResource("is_cover_page", defaultValue: "Cover Page"),
                    description: LocalizedStringResource(
                        "help_setting_cover_page_description",
                        defaultValue: "Displays the first page separately as the cover in spread view."
                    )
                ),
                HelpDetail(
                    id: "scrollDirection",
                    title: LocalizedStringResource("scroll_direction", defaultValue: "Scroll Direction"),
                    description: LocalizedStringResource(
                        "help_setting_scroll_direction_description",
                        defaultValue: "Selects whether pages advance from left to right or right to left."
                    )
                ),
                HelpDetail(
                    id: "coverPageSetting",
                    title: LocalizedStringResource("cover_page_setting_label", defaultValue: "Cover Page Setting"),
                    description: LocalizedStringResource(
                        "help_setting_cover_page_type_description",
                        defaultValue: "Selects how the cover page is positioned for each reading direction."
                    )
                ),
                HelpDetail(
                    id: "reset",
                    title: LocalizedStringResource("reset_title", defaultValue: "Reset"),
                    description: LocalizedStringResource(
                        "help_setting_reset_description",
                        defaultValue: "Resets app settings and closes the current document."
                    )
                ),
                HelpDetail(
                    id: "documentInformation",
                    title: LocalizedStringResource("doc_info", defaultValue: "Document Information"),
                    description: LocalizedStringResource(
                        "help_setting_document_info_description",
                        defaultValue: "Shows metadata, page count, page layout, and reading direction for the open PDF."
                    )
                ),
                HelpDetail(
                    id: "deviceTesting",
                    title: LocalizedStringResource("device_testing", defaultValue: "Device Testing"),
                    description: LocalizedStringResource(
                        "help_setting_device_testing_description",
                        defaultValue: "Runs app information, local storage, and PDF rendering checks on this device. Results include the test time, device, OS, and app version. Results are shared only when you tap Share and are never sent automatically."
                    )
                ),
                HelpDetail(
                    id: "diagnosticLogs",
                    title: LocalizedStringResource("app_logs", defaultValue: "App Logs"),
                    description: LocalizedStringResource(
                        "help_setting_app_logs_description",
                        defaultValue: "Shows privacy-safe diagnostic logs for investigating crashes, slowdowns, operation issues, and display issues. Logs do not include personal information, file contents, file names or paths, search terms, or passwords. They are deleted after 24 hours and are shared only when you tap Share."
                    )
                ),
                HelpDetail(
                    id: "help",
                    title: LocalizedStringResource("help_title", defaultValue: "Help"),
                    description: LocalizedStringResource(
                        "help_setting_help_description",
                        defaultValue: "Opens this help screen."
                    )
                ),
                HelpDetail(
                    id: "appInformation",
                    title: LocalizedStringResource("app_info", defaultValue: "App Information"),
                    description: LocalizedStringResource(
                        "help_setting_app_info_description",
                        defaultValue: "Shows the app name, version, and copyright."
                    )
                ),
                HelpDetail(
                    id: "developerSupport",
                    title: LocalizedStringResource("developer_support_title", defaultValue: "Support the Developer"),
                    description: LocalizedStringResource(
                        "help_setting_supporter_icons_description",
                        defaultValue: "Opens the supporter icon store. Purchases can be restored on devices using the same Apple Account."
                    )
                )
            ]
        )
    ]

    private var backgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(helpItems, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(item.id). \(String(localized: item.title))")
                            .font(.headline)
                        Text(item.description)
                            .font(.body)

                        ForEach(item.details) { detail in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(detail.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(detail.description)
                                    .font(.body)
                            }
                            .padding(.leading, 16)
                        }
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
                            productAction(for: product)
                        }
                    }
                }

                Button {
                    Task { await tipManager.restorePurchases() }
                } label: {
                    if tipManager.isRestoringPurchases {
                        HStack {
                            ProgressView()
                            Text(String(localized: "restoring_purchases", defaultValue: "Restoring Purchases…"))
                        }
                    } else {
                        Text(String(localized: "restore_purchases", defaultValue: "Restore Purchases"))
                    }
                }
                .disabled(tipManager.isRestoringPurchases || purchasingProductID != nil)
                .accessibilityIdentifier("restorePurchasesButton")

                if let restoreMessage = tipManager.restoreMessage {
                    Text(restoreMessage)
                        .font(.footnote)
                        .foregroundColor(settingsTextColor)
                }
            } footer: {
                Text(String(localized: "supporter_icon_purchase_description", defaultValue: "Each purchase permanently unlocks its supporter icon. Restore purchases on another device using the same Apple Account."))
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
        case "supporter_icon_bronze":
            return "TipIconBronze"
        case "supporter_icon_silver":
            return "TipIconSilver"
        case "supporter_icon_gold":
            return "TipIconGold"
        default:
            return "TipIconGold"
        }
    }

    private func tipDisplayName(for productID: String) -> LocalizedStringResource {
        switch productID {
        case "supporter_icon_bronze":
            return "tip_100_name"
        case "supporter_icon_silver":
            return "tip_500_name"
        case "supporter_icon_gold":
            return "tip_1000_name"
        default:
            return "tip_selection_title"
        }
    }

    private func tipDescription(for productID: String) -> LocalizedStringResource {
        switch productID {
        case "supporter_icon_bronze":
            return "tip_100_description"
        case "supporter_icon_silver":
            return "tip_500_description"
        case "supporter_icon_gold":
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

    @ViewBuilder
    private func productAction(for product: Product) -> some View {
        if purchasingProductID == product.id {
            ProgressView()
        } else if tipManager.isPurchased(product.id) {
            let iconName = TipManager.appIconName(for: product.id)
            if tipManager.currentAppIconName == iconName {
                Text(String(localized: "supporter_icon_in_use", defaultValue: "In Use"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Button(String(localized: "use_supporter_icon", defaultValue: "Use Icon")) {
                    Task { _ = await tipManager.changeAppIcon(named: iconName) }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("useSupporterIconButton_\(product.id)")
            }
        } else {
            Button(product.displayPrice) {
                purchase(product)
            }
            .buttonStyle(.borderedProminent)
            .disabled(purchasingProductID != nil || tipManager.isRestoringPurchases)
            .accessibilityIdentifier("tipProductButton_\(product.id)")
        }
    }
}
