//
// HelpContentTests.swift
// MihirakiPDFViewerTests
//
// Copyright 2026 Takuma Yamada.
//

import Testing
@testable import MihirakiPDFViewer

struct HelpContentTests {
    @Test
    func settingsGuideMatchesSettingsScreenOrder() throws {
        let settings = try #require(HelpContent.settingsGuide.first)

        #expect(settings.details.map(\.id) == [
            "highQualityRendering",
            "sharpness",
            "spreadView",
            "coverPage",
            "scrollDirection",
            "documentInformation",
            "singlePageInPortrait",
            "coverPageSetting",
            "reset",
            "help",
            "diagnostics",
            "appInformation",
            "developerSupport",
            "promotionCode"
        ])
    }

    @Test
    func diagnosticHelpMatchesDiagnosticScreenOrder() throws {
        let diagnostics = try #require(HelpContent.diagnostics.first)

        #expect(diagnostics.details.map(\.id) == [
            "diagnosticPrivacy",
            "deviceTests",
            "appLogs",
            "reportProblem"
        ])
    }

    @Test
    func helpItemIdentifiersAreUniqueAcrossCategories() {
        let identifiers = HelpContent.items.map(\.id)

        #expect(Set(identifiers).count == identifiers.count)
    }
}
