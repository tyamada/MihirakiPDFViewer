//
//  MihirakiPDFViewerTests.swift
//  MihirakiPDFViewerTests
//
//  Copyright 2026 Takuma Yamada.
//

import Foundation
import Testing
@testable import MihirakiPDFViewer

struct DeviceTestReportTests {
    @Test
    func reportsSuccessOnlyWhenEveryCheckPasses() {
        let passedReport = makeReport(statuses: [.passed, .passed])
        let failedReport = makeReport(statuses: [.passed, .failed])

        #expect(passedReport.allPassed)
        #expect(!failedReport.allPassed)
    }

    @Test
    func shareTextIncludesReportMetadataAndFailureDetail() {
        let report = makeReport(statuses: [.failed], detail: "Example failure")

        #expect(report.shareText.contains("Example Device"))
        #expect(report.shareText.contains("Example OS"))
        #expect(report.shareText.contains("1.2.3 (4)"))
        #expect(report.shareText.contains("Example failure"))
    }

    @MainActor
    @Test
    func runnerValidatesLocalStorageAndPDFEngine() throws {
        let report = DeviceTestRunner.run()
        let localStorage = try #require(
            report.checks.first { $0.id == "cacheStorage" }
        )
        let pdfEngine = try #require(
            report.checks.first { $0.id == "pdfEngine" }
        )

        #expect(localStorage.status == .passed)
        #expect(pdfEngine.status == .passed)
    }

    private func makeReport(
        statuses: [DeviceTestReport.Check.Status],
        detail: String? = nil
    ) -> DeviceTestReport {
        DeviceTestReport(
            testedAt: Date(timeIntervalSince1970: 1_800_000_000),
            deviceName: "Example Device",
            deviceModel: "Example Model",
            osVersion: "Example OS",
            appVersion: "1.2.3 (4)",
            totalMemoryBytes: 1_000_000,
            availableMemoryBytes: 500_000,
            checks: statuses.enumerated().map { index, status in
                DeviceTestReport.Check(
                    id: "check-\(index)",
                    name: "App information",
                    status: status,
                    detail: detail
                )
            }
        )
    }
}
