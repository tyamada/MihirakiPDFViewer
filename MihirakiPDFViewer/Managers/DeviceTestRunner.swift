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
import Darwin

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
    let deviceModelName: String
    let deviceModelIdentifier: String
    let osVersion: String
    let appVersion: String
    let totalMemoryBytes: UInt64
    let availableMemoryBytes: UInt64
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
            String(localized: "Model name: \(deviceModelName)"),
            String(localized: "Model identifier: \(deviceModelIdentifier)"),
            String(localized: "OS version: \(osVersion)"),
            String(localized: "App version: \(appVersion)"),
            String(localized: "Total memory: \(ByteCountFormatter.string(fromByteCount: Int64(totalMemoryBytes), countStyle: .memory))"),
            String(localized: "Available memory: \(ByteCountFormatter.string(fromByteCount: Int64(availableMemoryBytes), countStyle: .memory))"),
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
        let modelIdentifier = deviceModelIdentifier()
        let checks = [
            bundleInformationCheck(version: version),
            cacheStorageCheck(fileManager: fileManager),
            availableStorageCheck(fileManager: fileManager),
            pdfEngineCheck(fileManager: fileManager)
        ]

        return DeviceTestReport(
            testedAt: testedAt,
            deviceModelName: deviceModelName(
                for: modelIdentifier,
                fallback: currentDevice.model
            ),
            deviceModelIdentifier: modelIdentifier,
            osVersion: "\(currentDevice.systemName) \(currentDevice.systemVersion)",
            appVersion: version,
            totalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            availableMemoryBytes: UInt64(os_proc_available_memory()),
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

    private static func cacheStorageCheck(
        fileManager: FileManager
    ) -> DeviceTestReport.Check {
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let url = cacheDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")
        let expectedData = Data("MihirakiPDFViewer device test".utf8)

        do {
            try expectedData.write(to: url, options: .atomic)
            defer { try? fileManager.removeItem(at: url) }
            let actualData = try Data(contentsOf: url)
            guard actualData == expectedData else {
                return failedCheck(
                    id: "cacheStorage",
                    name: "Cache storage",
                    detail: String(
                        localized: "The saved data did not match the data that was read."
                    )
                )
            }
            return passedCheck(id: "cacheStorage", name: "Cache storage")
        } catch {
            return failedCheck(
                id: "cacheStorage",
                name: "Cache storage",
                detail: error.localizedDescription
            )
        }
    }

    private static func availableStorageCheck(
        fileManager: FileManager
    ) -> DeviceTestReport.Check {
        do {
            let values = try fileManager.temporaryDirectory.resourceValues(
                forKeys: [.volumeAvailableCapacityForImportantUsageKey]
            )
            guard let capacity = values.volumeAvailableCapacityForImportantUsage else {
                return failedCheck(
                    id: "availableStorage",
                    name: "Available storage",
                    detail: String(localized: "Available storage could not be read.")
                )
            }
            return DeviceTestReport.Check(
                id: "availableStorage",
                name: "Available storage",
                status: .passed,
                detail: ByteCountFormatter.string(fromByteCount: capacity, countStyle: .file)
            )
        } catch {
            return failedCheck(
                id: "availableStorage",
                name: "Available storage",
                detail: error.localizedDescription
            )
        }
    }

    private static func deviceModelIdentifier() -> String {
        if let simulatorIdentifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
           !simulatorIdentifier.isEmpty {
            return simulatorIdentifier
        }

        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            identifier.append(Character(UnicodeScalar(UInt8(value))))
        }
    }

    static func deviceModelName(for identifier: String, fallback: String) -> String {
        modelNamesByIdentifier[identifier] ?? fallback
    }

    private static let modelNamesByIdentifier: [String: String] = [
        "iPhone10,1": "iPhone 8",
        "iPhone10,4": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus",
        "iPhone10,5": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X",
        "iPhone10,6": "iPhone X",
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd generation)",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3rd generation)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,5": "iPhone 16e",
        "iPad11,1": "iPad mini (5th generation)",
        "iPad11,2": "iPad mini (5th generation)",
        "iPad11,3": "iPad Air (3rd generation)",
        "iPad11,4": "iPad Air (3rd generation)",
        "iPad13,1": "iPad Air (4th generation)",
        "iPad13,2": "iPad Air (4th generation)",
        "iPad13,16": "iPad Air (5th generation)",
        "iPad13,17": "iPad Air (5th generation)",
        "iPad13,18": "iPad (10th generation)",
        "iPad13,19": "iPad (10th generation)",
        "iPad14,1": "iPad mini (6th generation)",
        "iPad14,2": "iPad mini (6th generation)",
        "iPad14,8": "iPad Air 11-inch (M2)",
        "iPad14,9": "iPad Air 11-inch (M2)",
        "iPad14,10": "iPad Air 13-inch (M2)",
        "iPad14,11": "iPad Air 13-inch (M2)",
        "iPad16,1": "iPad mini (A17 Pro)",
        "iPad16,2": "iPad mini (A17 Pro)",
        "iPad16,3": "iPad Pro 11-inch (M4)",
        "iPad16,4": "iPad Pro 11-inch (M4)",
        "iPad16,5": "iPad Pro 13-inch (M4)",
        "iPad16,6": "iPad Pro 13-inch (M4)"
    ]

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
