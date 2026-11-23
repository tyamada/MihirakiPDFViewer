//
// UITestLaunchConfigurationTests.swift
// MihirakiPDFViewerTests
//
// Copyright 2026 Takuma Yamada.
//

import Foundation
import Testing
@testable import MihirakiPDFViewer

struct UITestLaunchConfigurationTests {
    @Test
    func parsesFlagsAndPDFPaths() {
        let configuration = UITestLaunchConfiguration(arguments: [
            "MihirakiPDFViewer",
            "-uiTestResetRenderingPreferences",
            "-uiTestResetReadingSession",
            "-uiTestLoadSamplePDF",
            "-uiTestPDFPath",
            "/tmp/sample.pdf",
            "-uiTestIncomingPDFPath",
            "/tmp/incoming.pdf"
        ])

        #expect(configuration.shouldResetRenderingPreferences)
        #expect(configuration.shouldResetReadingSession)
        #expect(configuration.shouldLoadSamplePDF)
        #expect(configuration.pdfURL == URL(fileURLWithPath: "/tmp/sample.pdf"))
        #expect(configuration.incomingPDFURL == URL(fileURLWithPath: "/tmp/incoming.pdf"))
    }

    @Test
    func ignoresMissingPathValuesAndUnrelatedArguments() {
        let configuration = UITestLaunchConfiguration(arguments: [
            "MihirakiPDFViewer",
            "-unrelated",
            "-uiTestPDFPath"
        ])

        #expect(!configuration.shouldResetRenderingPreferences)
        #expect(!configuration.shouldResetReadingSession)
        #expect(!configuration.shouldLoadSamplePDF)
        #expect(configuration.pdfURL == nil)
        #expect(configuration.incomingPDFURL == nil)
    }
}
