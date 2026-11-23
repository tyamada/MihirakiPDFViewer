//
// SamplePDFCatalogTests.swift
// MihirakiPDFViewerTests
//
// Copyright 2026 Takuma Yamada.
//

import Foundation
import Testing
@testable import MihirakiPDFViewer

@MainActor
struct SamplePDFCatalogTests {
    @Test
    func bundledCatalogContainsValidFixedReleaseSamples() throws {
        let url = try #require(Bundle.main.url(forResource: "SamplePDFCatalog", withExtension: "json"))
        let catalog = try JSONDecoder().decode(
            SamplePDFCatalog.self,
            from: Data(contentsOf: url)
        )

        #expect(catalog.schemaVersion == 1)
        #expect(catalog.license.identifier == "CC-BY-4.0")
        #expect(catalog.license.creator == "こまいろ日和 / Komairo Hiyori (Takuma Yamada)")
        #expect(catalog.samples.count == 51)

        let ids = Set(catalog.samples.map(\.id))
        let fileNames = Set(catalog.samples.map(\.fileName))
        #expect(ids.count == catalog.samples.count)
        #expect(fileNames.count == catalog.samples.count)

        for sample in catalog.samples {
            #expect(sample.downloadURL.scheme == "https")
            #expect(sample.downloadURL.host == "github.com")
            #expect(sample.downloadURL.path.hasPrefix("/tyamada/manga-prompt-kit/releases/download/manga-pdf-20261103-v1/"))
            #expect(sample.fileName == URL(fileURLWithPath: sample.fileName).lastPathComponent)
            #expect(sample.fileName.lowercased().hasSuffix(".pdf"))
            #expect(sample.byteSize > 0)
            #expect(sample.byteSize <= SamplePDFStore.maximumFileSize)
            #expect(sample.sha256.count == 64)
            #expect(sample.sha256.allSatisfy { $0.isHexDigit })
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func hostedSamplesMatchBundledCatalogFileSizes() async throws {
        let url = try #require(Bundle.main.url(forResource: "SamplePDFCatalog", withExtension: "json"))
        let catalog = try JSONDecoder().decode(
            SamplePDFCatalog.self,
            from: Data(contentsOf: url)
        )

        try await withThrowingTaskGroup(of: (String, Int64, HTTPURLResponse).self) { group in
            for sample in catalog.samples {
                let sampleID = sample.id
                let downloadURL = sample.downloadURL
                let byteSize = sample.byteSize

                group.addTask {
                    var request = URLRequest(url: downloadURL)
                    request.httpMethod = "HEAD"
                    request.cachePolicy = .reloadIgnoringLocalCacheData
                    request.timeoutInterval = 30

                    let (_, response) = try await URLSession.shared.data(for: request)
                    let httpResponse = try #require(response as? HTTPURLResponse)
                    return (sampleID, byteSize, httpResponse)
                }
            }

            for try await (sampleID, byteSize, response) in group {
                #expect(
                    (200...299).contains(response.statusCode),
                    "\(sampleID) returned HTTP \(response.statusCode)"
                )
                #expect(
                    ["application/pdf", "application/octet-stream"].contains(response.mimeType ?? ""),
                    "\(sampleID) returned \(response.mimeType ?? "no content type")"
                )
                #expect(
                    response.expectedContentLength == byteSize,
                    "\(sampleID) is \(response.expectedContentLength) bytes on the server, but the catalog declares \(byteSize)"
                )
            }
        }
    }

    @Test
    func maximumDownloadSizeIsOneHundredMebibytes() {
        #expect(SamplePDFStore.maximumFileSize == 104_857_600)
    }

    @Test
    func languageFilterUsesPreferredLanguageWithRegion() {
        let languageCode = SamplePDFLanguageFilter.initialLanguageCode(
            preferredLanguages: ["ja-JP"],
            availableLanguageCodes: ["en", "ja", "ko", "zh-Hans"]
        )

        #expect(languageCode == "ja")
    }

    @Test
    func languageFilterFallsBackToEnglish() {
        let languageCode = SamplePDFLanguageFilter.initialLanguageCode(
            preferredLanguages: ["fr-FR", "ja-JP"],
            availableLanguageCodes: ["en", "ja", "ko", "zh-Hans"]
        )

        #expect(languageCode == "en")
    }

    @Test
    func languageFilterCanRepresentAllWhenEnglishIsUnavailable() {
        let languageCode = SamplePDFLanguageFilter.initialLanguageCode(
            preferredLanguages: ["fr-FR"],
            availableLanguageCodes: ["ja", "ko"]
        )

        #expect(languageCode == nil)
    }
    @Test
    func languageRegionsAndFilipinoRemainDistinct() throws {
        let url = try #require(Bundle.main.url(forResource: "SamplePDFCatalog", withExtension: "json"))
        let catalog = try JSONDecoder().decode(SamplePDFCatalog.self, from: Data(contentsOf: url))
        #expect(Set(catalog.samples.map(\.downloadURL)).count == 51)
        #expect(Set(catalog.samples.map(\.languageCode)).count == 17)
        let filipino = catalog.samples.filter { $0.languageCode == "fil" }
        #expect(filipino.count == 3)
        #expect(filipino.allSatisfy { $0.downloadURL.lastPathComponent.hasSuffix("_tl.pdf") })
    }

    @Test
    func failedRequestPreservesExistingDownloadedFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sample = SamplePDF(id: "legacy", title: "Legacy", languageCode: "fil",
            fileName: "legacy_tl.pdf", downloadURL: URL(string: "https://example.com/fail.pdf")!,
            byteSize: 1, sha256: String(repeating: "0", count: 64))
        let store = SamplePDFStore(documentsDirectory: directory)
        let cached = store.localURL(for: sample)
        try FileManager.default.createDirectory(at: cached.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data("%PDF-old acquired version".utf8)
        try original.write(to: cached)
        await store.download(sample, allowsCellular: false)
        #expect(try Data(contentsOf: cached) == original)
        #expect(store.state(for: sample) == .downloaded)
        #expect(store.errorMessage != nil)
    }

    @Test(.timeLimit(.minutes(3)))
    func releaseDownloadCacheReuseAndCorruptReplacement() async throws {
        let url = try #require(Bundle.main.url(forResource: "SamplePDFCatalog", withExtension: "json"))
        let catalog = try JSONDecoder().decode(SamplePDFCatalog.self, from: Data(contentsOf: url))
        let sample = try #require(catalog.samples.first { $0.id == "tameshibu-episode1-ja" })
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SamplePDFStore(documentsDirectory: directory)
        await store.download(sample, allowsCellular: false)
        #expect(store.errorMessage == nil)
        #expect(store.state(for: sample) == .downloaded)
        let cached = store.localURL(for: sample)
        let original = try Data(contentsOf: cached)
        #expect(original.count == sample.byteSize)

        // A valid cached PDF is reused even when the remote asset does not exist.
        let offlineSample = SamplePDF(id: sample.id, title: sample.title, languageCode: sample.languageCode,
            fileName: sample.fileName,
            downloadURL: URL(string: "https://github.com/tyamada/manga-prompt-kit/releases/download/manga-pdf-20261103-v1/absent-offline.pdf")!,
            byteSize: sample.byteSize, sha256: sample.sha256)
        await store.download(offlineSample, allowsCellular: false)
        #expect(store.errorMessage == nil)
        #expect(try Data(contentsOf: cached) == original)

        try Data("%PDF-corrupt".utf8).write(to: cached)
        await store.download(sample, allowsCellular: false)
        #expect(store.errorMessage == nil)
        #expect(try Data(contentsOf: cached) == original)

        let badChecksum = SamplePDF(id: sample.id, title: sample.title, languageCode: sample.languageCode,
            fileName: sample.fileName, downloadURL: sample.downloadURL,
            byteSize: sample.byteSize, sha256: String(repeating: "0", count: 64))
        await store.download(badChecksum, allowsCellular: false)
        #expect(store.errorMessage != nil)
        #expect(try Data(contentsOf: cached) == original)
        #expect(store.state(for: sample) == .downloaded)
    }

}
