//
// SamplePDF.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import Foundation

struct SamplePDFCatalog: Decodable, Sendable {
    let schemaVersion: Int
    let license: SamplePDFLicense
    let samples: [SamplePDF]
}

struct SamplePDFLicense: Decodable, Sendable {
    let identifier: String
    let name: String
    let creator: String
    let url: URL
}

struct SamplePDF: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let languageCode: String
    let fileName: String
    let downloadURL: URL
    let byteSize: Int64
    let sha256: String

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: byteSize, countStyle: .file)
    }

    var languageDisplayName: String {
        Locale.current.localizedString(forLanguageCode: languageCode) ?? languageCode
    }
}

enum SamplePDFLanguageFilter {
    static func availableLanguageCodes(in samples: [SamplePDF]) -> [String] {
        samples.reduce(into: []) { languageCodes, sample in
            if !languageCodes.contains(sample.languageCode) {
                languageCodes.append(sample.languageCode)
            }
        }
    }

    static func initialLanguageCode(
        preferredLanguages: [String],
        availableLanguageCodes: [String]
    ) -> String? {
        if let preferredLanguage = preferredLanguages.first,
           let match = availableLanguageCodes.first(where: {
                languageCodesMatch($0, preferredLanguage)
           }) {
            return match
        }

        return availableLanguageCodes.first(where: {
            languageCodesMatch($0, "en")
        })
    }

    private static func languageCodesMatch(_ available: String, _ preferred: String) -> Bool {
        let availableCode = available.replacingOccurrences(of: "_", with: "-").lowercased()
        let preferredCode = preferred.replacingOccurrences(of: "_", with: "-").lowercased()

        return preferredCode == availableCode
            || preferredCode.hasPrefix("\(availableCode)-")
            || availableCode.hasPrefix("\(preferredCode)-")
            || preferredCode.split(separator: "-").first == availableCode.split(separator: "-").first
    }
}

enum SamplePDFDownloadState: Equatable {
    case notDownloaded
    case downloading
    case downloaded
    case deleting
}
