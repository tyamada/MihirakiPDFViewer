//
// HelpView.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import SwiftUI

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
            title: LocalizedStringResource("sample_pdf_navigation_title", defaultValue: "Sample PDFs"),
            description: LocalizedStringResource(
                "help_sample_pdfs_description",
                defaultValue: "Browse sample PDFs by language, download one to this device, open it in the viewer, or delete the local copy when you no longer need it. Mobile-data downloads ask for confirmation."
            )
        ),
        HelpItem(
            id: 3,
            title: LocalizedStringResource("help_navigate_pages_title", defaultValue: "Navigate Pages"),
            description: LocalizedStringResource(
                "help_navigate_pages_description",
                defaultValue: "Switch pages by swiping or using the slider."
            )
        ),
        HelpItem(
            id: 4,
            title: LocalizedStringResource("help_menu_title", defaultValue: "Menu"),
            description: LocalizedStringResource(
                "help_menu_description",
                defaultValue: "Tap the screen to toggle the visibility of the toolbar and slider."
            )
        ),
        HelpItem(
            id: 5,
            title: LocalizedStringResource("help_zoom_title", defaultValue: "Zoom"),
            description: LocalizedStringResource(
                "help_zoom_description",
                defaultValue: "Pinch to zoom in or out. Long-press and drag to scroll while zoomed in."
            )
        ),
        HelpItem(
            id: 6,
            title: LocalizedStringResource("help_search_title", defaultValue: "Search"),
            description: LocalizedStringResource(
                "help_search_description",
                defaultValue: "Enter text into the search bar to find specific content within the PDF."
            )
        ),
        HelpItem(
            id: 7,
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
                    id: "singlePageInPortrait",
                    title: LocalizedStringResource(
                        "single_page_in_portrait",
                        defaultValue: "Single Page in Portrait"
                    ),
                    description: LocalizedStringResource(
                        "help_setting_single_page_in_portrait_description",
                        defaultValue: "Displays one page at a time by default when the screen is taller than it is wide, regardless of device type. Turn this off to keep spread view in portrait."
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
                    id: "reset",
                    title: LocalizedStringResource("reset_title", defaultValue: "Reset"),
                    description: LocalizedStringResource(
                        "help_setting_reset_description",
                        defaultValue: "Resets app settings and closes the current document."
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
