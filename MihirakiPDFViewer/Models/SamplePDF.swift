//
// SamplePDF.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import Foundation

struct SamplePDFCatalog: Codable, Sendable {
    let schemaVersion: Int
    let license: SamplePDFLicense
    let samples: [SamplePDF]
}

struct SamplePDFLicense: Codable, Sendable {
    let identifier: String
    let name: String
    let creator: String
    let url: URL
}

struct SamplePDF: Codable, Identifiable, Equatable, Sendable {
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
        SamplePDFLanguageFilter.displayName(for: languageCode)
    }
}

enum SamplePDFLanguageFilter {
    static func availableLanguageCodes(in samples: [SamplePDF]) -> [String] {
        samples.reduce(into: []) { codes, sample in
            if !codes.contains(sample.languageCode) { codes.append(sample.languageCode) }
        }
    }

    static func initialLanguageCode(preferredLanguages: [String], availableLanguageCodes: [String]) -> String? {
        if let preferred = preferredLanguages.first {
            let normalized = normalize(preferred)
            if let exact = availableLanguageCodes.first(where: { normalize($0) == normalized }) { return exact }
            if normalized.split(separator: "-").first == "zh" {
                let parts = normalized.split(separator: "-").map(String.init)
                let traditional = parts.contains("hant") || (!parts.contains("hans") && (parts.contains("tw") || parts.contains("hk") || parts.contains("mo")))
                let candidates = traditional
                    ? (parts.contains("hk") ? ["zh-hant-hk", "zh-hant", "zh-tw"] : ["zh-hant", "zh-tw"])
                    : ["zh-hans", "zh-cn", "zh"]
                for candidate in candidates {
                    if let match = availableLanguageCodes.first(where: { normalize($0) == candidate }) { return match }
                }
            } else if let base = normalized.split(separator: "-").first,
                      let match = availableLanguageCodes.first(where: { normalize($0).split(separator: "-").first == base }) {
                return match
            }
        }
        return availableLanguageCodes.first { normalize($0) == "en" }
    }

    static func displayName(for code: String, locale: Locale = .current) -> String {
        switch normalize(code) {
        case "zh-hans", "zh-cn", "zh-sg":
            return String(localized: "sample_pdf_language_chinese_simplified", defaultValue: "Chinese (Simplified)")
        case "zh-hant", "zh-tw", "zh-mo", "zh-hant-mo":
            return String(localized: "sample_pdf_language_chinese_traditional", defaultValue: "Chinese (Traditional)")
        case "zh-hant-hk", "zh-hk":
            return String(localized: "sample_pdf_language_chinese_hong_kong", defaultValue: "Chinese (Traditional, Hong Kong)")
        default:
            return locale.localizedString(forIdentifier: code) ?? code
        }
    }

    private static func normalize(_ code: String) -> String {
        code.replacingOccurrences(of: "_", with: "-").lowercased()
    }
}

enum SamplePDFDownloadState: Equatable {
    case notDownloaded
    case downloading
    case downloaded
    case deleting
}


// The publication manifest has a different wire format and IDs from this app's
// bundled catalog. Never use its filenames as replacements for existing paths.
struct SamplePDFManifest: Decodable {
    struct Entry: Decodable {
        let sample_id: String
        let episode: Int
        let language_key: String
        let locale: String
        let title: String
        let filename: String
        let pages: Int
        let bytes: Int64
        let sha256: String
        let license: String
        let new_download_url: URL
    }

    let schema_version: Int
    let license: String
    let pdf_count: Int
    let entries: [Entry]

    func catalog(preserving previous: SamplePDFCatalog) throws -> SamplePDFCatalog {
        guard schema_version == 1, license == "CC-BY-4.0",
              !entries.isEmpty, entries.count <= 500, pdf_count == entries.count else {
            throw ValidationError.invalid
        }
        let knownLocales = [
            "ja": "ja-JP", "en": "en-US", "ko": "ko-KR",
            "zh_cn": "zh-Hans-CN", "zh_tw": "zh-Hant-TW", "zh_hk": "zh-Hant-HK",
            "de": "de-DE", "es": "es-ES", "es_419": "es-419",
            "fr": "fr-FR", "id": "id-ID", "it": "it-IT", "ne": "ne-NP",
            "pt": "pt-BR", "pt_pt": "pt-PT", "fil": "fil-PH", "vi": "vi-VN"
        ]
        let codes = ["zh_cn": "zh-Hans", "zh_tw": "zh-Hant",
                     "zh_hk": "zh-Hant-HK", "pt": "pt-BR", "pt_pt": "pt-PT",
                     "es_419": "es-419"]
        let old = Dictionary(uniqueKeysWithValues: previous.samples.map { ($0.id, $0) })
        var replacements: [String: SamplePDF] = [:]
        var remoteIDs = Set<String>()
        var filenames = Set<String>()
        var urls = Set<URL>()
        var newSamples: [SamplePDF] = []
        for entry in entries {
            guard entry.episode > 0, entry.episode <= 9999,
                  entry.language_key.range(of: "^[a-z][a-z0-9_]{0,31}$", options: .regularExpression) != nil,
                  entry.locale.range(of: "^[A-Za-z]{2,8}(-[A-Za-z0-9]{2,8})*$", options: .regularExpression) != nil,
                  knownLocales[entry.language_key].map({ $0 == entry.locale }) ?? true,
                  entry.sample_id == "ep\(entry.episode)_\(entry.language_key)",
                  remoteIDs.insert(entry.sample_id).inserted,
                  filenames.insert(entry.filename).inserted,
                  urls.insert(entry.new_download_url).inserted,
                  entry.license == "CC-BY-4.0", entry.pages > 0, entry.pages <= 10000,
                  !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  entry.title.count <= 1000,
                  SamplePDFSourcePolicy.isSafeFileName(entry.filename),
                  SamplePDFSourcePolicy.isPDFURL(entry.new_download_url),
                  entry.new_download_url.lastPathComponent == entry.filename,
                  entry.bytes > 0, entry.bytes <= 100 * 1024 * 1024,
                  SamplePDFSourcePolicy.isSHA256(entry.sha256) else {
                throw ValidationError.invalid
            }
            let id = "tameshibu-episode\(entry.episode)-\(entry.language_key.replacingOccurrences(of: "_", with: "-"))"
            guard replacements[id] == nil else { throw ValidationError.invalid }
            let existing = old[id]
            let code = existing?.languageCode ?? codes[entry.language_key] ?? (knownLocales[entry.language_key] == nil ? entry.locale : entry.language_key)
            let sample = SamplePDF(id: id, title: entry.title, languageCode: code,
                                   fileName: existing?.fileName ?? entry.filename,
                                   downloadURL: entry.new_download_url,
                                   byteSize: entry.bytes, sha256: entry.sha256.lowercased())
            replacements[id] = sample
            if existing == nil { newSamples.append(sample) }
        }
        // Preserve list order, language filters and all formerly known entries,
        // including downloaded selections omitted from a later publication.
        let samples = previous.samples.map { replacements[$0.id] ?? $0 } + newSamples
        guard Set(samples.map(\.fileName)).count == samples.count else { throw ValidationError.invalid }
        return SamplePDFCatalog(schemaVersion: 1, license: previous.license, samples: samples)
    }

    enum ValidationError: Error { case invalid }
}

enum SamplePDFSourcePolicy {
    nonisolated static let latestManifestURL = URL(string: "https://raw.githubusercontent.com/tyamada/manga-prompt-kit/main/releases/pdf-manifest.json")!
    nonisolated static let fixedManifestURL = URL(string: "https://github.com/tyamada/manga-prompt-kit/releases/download/manga-pdf-20261103-v1/pdf-manifest.json")!

    nonisolated static func isSafeFileName(_ name: String) -> Bool {
        name.count <= 200 && name.range(of: "^[A-Za-z0-9][A-Za-z0-9_.-]*\\.pdf$", options: .regularExpression) != nil
            && !name.contains("..")
    }

    nonisolated static func isSHA256(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
        }
    }

    private nonisolated static func hasSafeOrigin(_ url: URL) -> Bool {
        url.scheme == "https" && url.user == nil && url.password == nil && url.port == nil
    }

    nonisolated static func isPDFURL(_ url: URL) -> Bool {
        guard hasSafeOrigin(url), url.host == "github.com", url.query == nil, url.fragment == nil,
              URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath == url.path else { return false }
        let parts = url.path.split(separator: "/", omittingEmptySubsequences: false)
        return parts.count == 7 && parts[1] == "tyamada" && parts[2] == "manga-prompt-kit"
            && parts[3] == "releases" && parts[4] == "download"
            && parts[5].range(of: "^manga-pdf-[A-Za-z0-9][A-Za-z0-9._-]*$", options: .regularExpression) != nil
            && !parts[5].contains("..") && isSafeFileName(String(parts[6]))
    }

    nonisolated static func isManifestURL(_ url: URL) -> Bool {
        hasSafeOrigin(url) && (url == latestManifestURL || url == fixedManifestURL)
    }

    nonisolated static func isManifestResponseURL(_ url: URL, requested: URL) -> Bool {
        guard isManifestURL(requested) else { return false }
        return url == requested || (requested == fixedManifestURL
            && hasSafeOrigin(url) && url.host == "release-assets.githubusercontent.com" && url.fragment == nil)
    }

    nonisolated static func isAssetResponseURL(_ url: URL) -> Bool {
        isPDFURL(url) || (hasSafeOrigin(url) && url.host == "release-assets.githubusercontent.com" && url.fragment == nil)
    }
}
