//
// DeviceTestRunner.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//
// This software is released under the MIT License.
// For the full license text, please see the LICENSE file in the root directory.
//

import Foundation
import PDFKit
import UIKit

struct DeviceTestReport: Equatable {
    struct Check: Equatable, Identifiable {
        enum Status: Equatable {
            case passed
            case failed
        }

        let id: String
        let name: LocalizedStringResource
        let status: Status
        let detail: String?
    }

    let testedAt: Date
    let deviceName: String
    let osVersion: String
    let appVersion: String
    let checks: [Check]

    var allPassed: Bool {
        checks.allSatisfy { $0.status == .passed }
    }

    var shareText: String {
        let result = allPassed
            ? String(localized: "All tests passed.")
            : String(localized: "Some tests failed.")
        let checkLines = checks.map { check in
            let status = check.status == .passed
                ? String(localized: "Passed")
                : String(localized: "Failed")
            let detail = check.detail.map { " — \($0)" } ?? ""
            return "[\(status)] \(String(localized: check.name))\(detail)"
        }

        return ([
            String(localized: "Device Test Results"),
            String(localized: "Result: \(result)"),
            String(localized: "Test date: \(testedAt.formatted(date: .numeric, time: .standard))"),
            String(localized: "Device: \(deviceName)"),
            String(localized: "OS version: \(osVersion)"),
            String(localized: "App version: \(appVersion)"),
            ""
        ] + checkLines).joined(separator: "\n")
    }
}

@MainActor
enum DeviceTestRunner {
    static func run(
        bundle: Bundle = .main,
        device: UIDevice? = nil,
        fileManager: FileManager = .default,
        testedAt: Date = .now
    ) -> DeviceTestReport {
        let currentDevice = device ?? .current
        let version = appVersion(in: bundle)
        let checks = [
            bundleInformationCheck(version: version),
            localStorageCheck(fileManager: fileManager),
            pdfEngineCheck(fileManager: fileManager)
        ]

        return DeviceTestReport(
            testedAt: testedAt,
            deviceName: currentDevice.name,
            osVersion: "\(currentDevice.systemName) \(currentDevice.systemVersion)",
            appVersion: version,
            checks: checks
        )
    }

    private static func appVersion(in bundle: Bundle) -> String {
        let shortVersion = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, build) {
        case let (shortVersion?, build?) where !shortVersion.isEmpty && !build.isEmpty:
            return "\(shortVersion) (\(build))"
        case let (shortVersion?, _) where !shortVersion.isEmpty:
            return shortVersion
        default:
            return String(localized: "Not available")
        }
    }

    private static func bundleInformationCheck(
        version: String
    ) -> DeviceTestReport.Check {
        let passed = version != String(localized: "Not available")
        return DeviceTestReport.Check(
            id: "bundleInformation",
            name: "App information",
            status: passed ? .passed : .failed,
            detail: passed ? nil : String(localized: "The app version could not be read.")
        )
    }

    private static func localStorageCheck(
        fileManager: FileManager
    ) -> DeviceTestReport.Check {
        let url = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")
        let expectedData = Data("MihirakiPDFViewer device test".utf8)

        do {
            try expectedData.write(to: url, options: .atomic)
            defer { try? fileManager.removeItem(at: url) }
            let actualData = try Data(contentsOf: url)
            guard actualData == expectedData else {
                return failedCheck(
                    id: "localStorage",
                    name: "Local storage",
                    detail: String(
                        localized: "The saved data did not match the data that was read."
                    )
                )
            }
            return passedCheck(id: "localStorage", name: "Local storage")
        } catch {
            return failedCheck(
                id: "localStorage",
                name: "Local storage",
                detail: error.localizedDescription
            )
        }
    }

    private static func pdfEngineCheck(
        fileManager: FileManager
    ) -> DeviceTestReport.Check {
        let url = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        do {
            let renderer = UIGraphicsPDFRenderer(
                bounds: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                "Test".draw(at: CGPoint(x: 16, y: 16), withAttributes: nil)
            }
            defer { try? fileManager.removeItem(at: url) }

            guard let document = PDFDocument(url: url), document.pageCount == 1 else {
                return failedCheck(
                    id: "pdfEngine",
                    name: "PDF rendering",
                    detail: String(localized: "The generated PDF could not be read.")
                )
            }
            return passedCheck(id: "pdfEngine", name: "PDF rendering")
        } catch {
            return failedCheck(
                id: "pdfEngine",
                name: "PDF rendering",
                detail: error.localizedDescription
            )
        }
    }

    private static func passedCheck(
        id: String,
        name: LocalizedStringResource
    ) -> DeviceTestReport.Check {
        DeviceTestReport.Check(id: id, name: name, status: .passed, detail: nil)
    }

    private static func failedCheck(
        id: String,
        name: LocalizedStringResource,
        detail: String
    ) -> DeviceTestReport.Check {
        DeviceTestReport.Check(id: id, name: name, status: .failed, detail: detail)
    }
}
