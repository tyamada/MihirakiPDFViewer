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
    func bundledCatalogContainsValidGitHubPagesSamples() throws {
        let url = try #require(Bundle.main.url(forResource: "SamplePDFCatalog", withExtension: "json"))
        let catalog = try JSONDecoder().decode(
            SamplePDFCatalog.self,
            from: Data(contentsOf: url)
        )

        #expect(catalog.schemaVersion == 1)
        #expect(catalog.license.identifier == "CC-BY-4.0")
        #expect(catalog.license.creator == "Takuma Yamada")
        #expect(catalog.samples.count == 14)

        let ids = Set(catalog.samples.map(\.id))
        let fileNames = Set(catalog.samples.map(\.fileName))
        #expect(ids.count == catalog.samples.count)
        #expect(fileNames.count == catalog.samples.count)

        for sample in catalog.samples {
            #expect(sample.downloadURL.scheme == "https")
            #expect(sample.downloadURL.host == "tyamada.github.io")
            #expect(sample.downloadURL.path.hasPrefix("/MihirakiPDFViewer/sample/"))
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
                    response.mimeType == "application/pdf",
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
}
