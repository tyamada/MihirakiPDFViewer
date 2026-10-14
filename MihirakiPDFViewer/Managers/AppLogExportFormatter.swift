//
// AppLogExportFormatter.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//
// This software is released under the MIT License.
// For the full license text, please see the LICENSE file in the root directory.
//

import Foundation
import UIKit

enum AppLogExportFormatter {
    static func text(
        for entries: [AppLogEntry],
        appVersion: String = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? String(localized: "Not available"),
        build: String = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? String(localized: "Not available"),
        systemName: String = UIDevice.current.systemName,
        systemVersion: String = UIDevice.current.systemVersion
    ) -> String {
        let header = [
            String(localized: "MihirakiPDFViewer App Logs"),
            String(localized: "App version: \(appVersion) (\(build))"),
            String(localized: "OS version: \(systemName) \(systemVersion)"),
            String(localized: "Retention: 24 hours"),
            String(localized: "No personal information or document contents are included."),
            ""
        ]
        let lines = entries.reversed().map { entry in
            var components = [
                entry.timestamp.formatted(.iso8601),
                "[\(entry.level.rawValue.uppercased())]",
                "[\(entry.category.rawValue)]",
                entry.event.rawValue
            ]
            if let duration = entry.durationMilliseconds {
                components.append("duration_ms=\(duration)")
            }
            if let value = entry.numericValue, let label = entry.numericLabel {
                components.append("\(label.rawValue)=\(value)")
            }
            return components.joined(separator: " ")
        }

        return (header + lines).joined(separator: "\n")
    }
}
