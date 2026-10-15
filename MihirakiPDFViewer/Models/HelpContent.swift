//
// HelpContent.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//
// This software is released under the MIT License.
// For the full license text, please see the LICENSE file in the root directory.
//

import Foundation

struct HelpDetail: Identifiable {
    let id: String
    let title: LocalizedStringResource
    let description: LocalizedStringResource
}

struct HelpItem: Identifiable {
    let id: Int
    let title: LocalizedStringResource
    let description: LocalizedStringResource
    var details: [HelpDetail] = []
}

enum HelpContent {
    static let gettingStarted: [HelpItem] = [
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
        )
    ]

    static let comfortableReading: [HelpItem] = [
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
        )
    ]

    static let settingsGuide: [HelpItem] = [
        HelpItem(
            id: 7,
            title: LocalizedStringResource("settings", defaultValue: "Settings"),
            description: LocalizedStringResource(
                "help_settings_description",
                defaultValue: "Use Settings to adjust viewing, review document information, access help and diagnostics, view app information, and support the developer."
            ),
            details: [
                detail(
                    id: "highQualityRendering",
                    title: LocalizedStringResource("high_quality_rendering", defaultValue: "High Quality"),
                    description: LocalizedStringResource("help_setting_high_quality_description", defaultValue: "Renders PDF pages at a higher resolution.")
                ),
                detail(
                    id: "sharpness",
                    title: LocalizedStringResource("sharpness", defaultValue: "Sharpness"),
                    description: LocalizedStringResource("help_setting_sharpness_description", defaultValue: "Adjusts how strongly text and lines are sharpened.")
                ),
                detail(
                    id: "spreadView",
                    title: LocalizedStringResource("is_spread_view", defaultValue: "Spread View"),
                    description: LocalizedStringResource("help_setting_spread_view_description", defaultValue: "Displays two pages side by side.")
                ),
                detail(
                    id: "coverPage",
                    title: LocalizedStringResource("is_cover_page", defaultValue: "Cover Page"),
                    description: LocalizedStringResource("help_setting_cover_page_description", defaultValue: "Displays the first page separately as the cover in spread view.")
                ),
                detail(
                    id: "scrollDirection",
                    title: LocalizedStringResource("scroll_direction", defaultValue: "Scroll Direction"),
                    description: LocalizedStringResource("help_setting_scroll_direction_description", defaultValue: "Selects whether pages advance from left to right or right to left.")
                ),
                detail(
                    id: "documentInformation",
                    title: LocalizedStringResource("doc_info", defaultValue: "Document Information"),
                    description: LocalizedStringResource("help_setting_document_info_description", defaultValue: "Shows metadata, page count, page layout, and reading direction for the open PDF.")
                ),
                detail(
                    id: "singlePageInPortrait",
                    title: LocalizedStringResource("single_page_in_portrait", defaultValue: "Single Page in Portrait"),
                    description: LocalizedStringResource("help_setting_single_page_in_portrait_description", defaultValue: "Displays one page at a time when the screen is taller than it is wide.")
                ),
                detail(
                    id: "coverPageSetting",
                    title: LocalizedStringResource("cover_page_setting_label", defaultValue: "Cover Page Setting"),
                    description: LocalizedStringResource("help_setting_cover_page_type_description", defaultValue: "Selects how the cover page is positioned for each reading direction.")
                ),
                detail(
                    id: "reset",
                    title: LocalizedStringResource("reset_title", defaultValue: "Reset"),
                    description: LocalizedStringResource("help_setting_reset_description", defaultValue: "Resets app settings and closes the current document.")
                ),
                detail(
                    id: "help",
                    title: LocalizedStringResource("help_title", defaultValue: "Help"),
                    description: LocalizedStringResource("help_setting_help_description", defaultValue: "Opens this help screen.")
                ),
                detail(
                    id: "diagnostics",
                    title: LocalizedStringResource("Diagnostics", defaultValue: "Diagnostics"),
                    description: LocalizedStringResource("help_setting_diagnostics_description", defaultValue: "Opens device tests, app logs, and problem reporting tools.")
                ),
                detail(
                    id: "appInformation",
                    title: LocalizedStringResource("app_info", defaultValue: "App Information"),
                    description: LocalizedStringResource("help_setting_app_info_description", defaultValue: "Shows the app version, build number, license, supporter badges, and support options.")
                ),
                detail(
                    id: "developerSupport",
                    title: LocalizedStringResource("developer_support_title", defaultValue: "Support the Developer"),
                    description: LocalizedStringResource("help_setting_supporter_icons_description", defaultValue: "Opens the supporter store to purchase or restore supporter icons and badges.")
                ),
                detail(
                    id: "promotionCode",
                    title: LocalizedStringResource("enter_promotion_code", defaultValue: "Enter Promotion Code"),
                    description: LocalizedStringResource("help_setting_promotion_code_description", defaultValue: "Explains how to redeem a promotion code from the Support screen.")
                )
            ]
        )
    ]

    static let diagnostics: [HelpItem] = [
        HelpItem(
            id: 8,
            title: LocalizedStringResource("Diagnostics", defaultValue: "Diagnostics"),
            description: LocalizedStringResource(
                "help_diagnostics_description",
                defaultValue: "Use on-device diagnostic tools and review privacy information before sharing results."
            ),
            details: [
                detail(
                    id: "diagnosticPrivacy",
                    title: LocalizedStringResource("Privacy", defaultValue: "Privacy"),
                    description: LocalizedStringResource("help_diagnostic_privacy_description", defaultValue: "Diagnostic results and logs remain on this device unless you explicitly share them.")
                ),
                detail(
                    id: "deviceTests",
                    title: LocalizedStringResource("Device Tests", defaultValue: "Device Tests"),
                    description: LocalizedStringResource("help_setting_device_testing_description", defaultValue: "Checks device and app information, memory, cache storage, available storage, and PDF rendering. Results are shared only when you tap Share.")
                ),
                detail(
                    id: "appLogs",
                    title: LocalizedStringResource("app_logs", defaultValue: "App Logs"),
                    description: LocalizedStringResource("help_setting_app_logs_description", defaultValue: "Shows privacy-safe logs from the last 24 hours. Logs are deleted automatically and shared only when you tap Share.")
                ),
                detail(
                    id: "reportProblem",
                    title: LocalizedStringResource("Report a Problem", defaultValue: "Report a Problem"),
                    description: LocalizedStringResource("help_diagnostic_report_problem_description", defaultValue: "Explains what to include in a report, links to device tests and app logs, and opens GitHub Issues after a privacy reminder.")
                )
            ]
        )
    ]

    static let items: [HelpItem] =
        gettingStarted + comfortableReading + settingsGuide + diagnostics

    private static func detail(
        id: String,
        title: LocalizedStringResource,
        description: LocalizedStringResource
    ) -> HelpDetail {
        HelpDetail(
            id: id,
            title: title,
            description: description
        )
    }
}
