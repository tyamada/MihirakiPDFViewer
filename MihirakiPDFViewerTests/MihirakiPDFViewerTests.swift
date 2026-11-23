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

        #expect(report.shareText.contains("iPhone 16 Pro"))
        #expect(report.shareText.contains("iPhone17,1"))
        #expect(report.shareText.contains("Example OS"))
        #expect(report.shareText.contains("1.2.3 (4)"))
        #expect(report.shareText.contains("Example failure"))
    }

    @Test
    func sharedReportDoesNotDiscloseStorageOrStorageDerivedResult() {
        func report(storageStatus: DeviceTestReport.Check.Status, detail: String) -> DeviceTestReport {
            DeviceTestReport(
                testedAt: Date(timeIntervalSince1970: 1_800_000_000),
                deviceModelName: "iPhone", deviceModelIdentifier: "iPhone17,1",
                osVersion: "iOS", appVersion: "1.0.4",
                totalMemoryBytes: 1_000, availableMemoryBytes: 500,
                checks: [
                    .init(id: "pdfEngine", name: "PDF rendering", status: .passed, detail: nil),
                    .init(id: "availableStorage", name: "Available storage",
                          status: storageStatus, detail: detail)
                ]
            )
        }
        let passed = report(storageStatus: .passed, detail: "123.45 GB PRIVATE")
        let failed = report(storageStatus: .failed, detail: "PRIVATE storage error")
        #expect(passed.allPassed)
        #expect(!failed.allPassed)
        #expect(passed.shareText == failed.shareText)
        #expect(!passed.shareText.contains("PRIVATE"))
        #expect(!passed.shareText.contains(String(localized: "Available storage")))
    }

    @MainActor
    @Test
    func resolvesKnownModelIdentifierAndFallsBackForUnknownModel() {
        #expect(
            DeviceTestRunner.deviceModelName(
                for: "iPhone17,1",
                fallback: "iPhone"
            ) == "iPhone 16 Pro"
        )
        #expect(
            DeviceTestRunner.deviceModelName(
                for: "iPhone99,1",
                fallback: "iPhone"
            ) == "iPhone"
        )
    }

    @MainActor
    @Test
    func runnerValidatesLocalStorageAndPDFEngine() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeviceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let report = DeviceTestRunner.run(fileManager: IsolatedDiagnosticFileManager(directory: directory))
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
            deviceModelName: "iPhone 16 Pro",
            deviceModelIdentifier: "iPhone17,1",
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

private final class IsolatedDiagnosticFileManager: FileManager, @unchecked Sendable {
    let directory: URL

    init(directory: URL) {
        self.directory = directory
        super.init()
    }

    override var temporaryDirectory: URL { directory }

    override func urls(for directory: FileManager.SearchPathDirectory,
                       in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        [self.directory]
    }
}
