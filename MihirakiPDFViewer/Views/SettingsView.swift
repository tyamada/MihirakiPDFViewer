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

import SwiftUI

/// 設定変更を行うためのビュー
public struct SettingsView: View {
    @Bindable var viewModel: PDFViewerViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingPromotionCodeInstructions = false
    @State private var isShowingTipSelection = false
    
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
                    SettingsSectionHeader(title: "display_settings")
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
                    SettingsSectionHeader(title: "doc_info")
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
                    SettingsSectionHeader(title: "options")
                    Toggle(
                        String(
                            localized: "single_page_in_portrait",
                            defaultValue: "Single Page in Portrait"
                        ),
                        isOn: Binding(
                            get: { viewModel.settings.isSinglePageInPortraitEnabled },
                            set: { viewModel.settings.isSinglePageInPortraitEnabled = $0 }
                        )
                    )
                    .accessibilityIdentifier("singlePageInPortraitToggle")

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
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HighContrastSettingsButtonStyle())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .accessibilityIdentifier("resetSettingsButton")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(1)
                .background(settingsBackgroundColor)
                
                // ヘルプ
                VStack(alignment: .leading, spacing: 12) {
                    SettingsSectionHeader(
                        title: LocalizedStringResource("help_title", defaultValue: "Help")
                    )
                    NavigationLink(destination: HelpView()) {
                        Text(String(localized: "help_title", defaultValue: "Help"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HighContrastSettingsButtonStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("helpButton")

                    DeviceTestingSettingsSection()
                    AppLoggingSettingsSection()

                    NavigationLink {
                        IssueReportingGuideView()
                    } label: {
                        Label("Report a Problem", systemImage: "exclamationmark.bubble")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HighContrastSettingsButtonStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("reportProblemButton")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(1)
                .background(settingsBackgroundColor)

                // アプリ情報
                VStack(alignment: .leading, spacing: 12) {
                    SettingsSectionHeader(title: "app_info")
                    VStack(alignment: .leading, spacing: 12) {
                        AppInformationRow(
                            label: "app_name_label",
                            value: Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                                ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
                                ?? "PDFViewer"
                        )
                        AppInformationRow(
                            label: "version_label",
                            value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                                ?? "1.0.0"
                        )
                        AppInformationRow(
                            label: "copyright_label",
                            value: String(localized: "copyright")
                        )
                    }

                    NavigationLink {
                        LicenseView()
                    } label: {
                        Label("License", systemImage: "doc.plaintext")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HighContrastSettingsButtonStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("licenseButton")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(1)
                .background(settingsBackgroundColor)

                // 開発者への応援 (Tip)
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    SettingsSectionHeader(
                        title: LocalizedStringResource(
                            "developer_support_title",
                            defaultValue: "Support the Developer"
                        )
                    )
                    Text(String(localized: "developer_support_description", defaultValue: "Your support helps keep the app updated. You can use all features without making a purchase."))
                        .font(.body)
                        .foregroundColor(settingsTextColor)
                        .multilineTextAlignment(.leading)
                    
                    Button {
                        isShowingTipSelection = true
                    } label: {
                        Text(String(localized: "tip_selection_title", defaultValue: "Support"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HighContrastSettingsButtonStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("supportButton")
                    .accessibilityHint(String(localized: "supporter_icon_store_accessibility_hint", defaultValue: "Opens the supporter icon store."))

                    Button {
                        isShowingPromotionCodeInstructions = true
                    } label: {
                        Text(String(localized: "enter_promotion_code", defaultValue: "Enter Promotion Code"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HighContrastSettingsButtonStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("enterPromotionCodeButton")
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
        .navigationDestination(isPresented: $isShowingTipSelection) {
            TipSelectionView(tipManager: TipManager.shared)
        }
        .alert(
            String(localized: "enter_promotion_code", defaultValue: "Enter Promotion Code"),
            isPresented: $isShowingPromotionCodeInstructions
        ) {
            Button(String(localized: "go_to_support_screen", defaultValue: "Go to Support Screen")) {
                isShowingTipSelection = true
            }
            Button(String(localized: "cancel", defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(
                localized: "promotion_code_instructions",
                defaultValue: "To use a promotion code, go to the Support screen and enter the code from the promotion code option."
            ))
        }
    }
}
