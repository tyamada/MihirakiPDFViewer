import Foundation
import Testing
@testable import MihirakiPDFViewer

private final class Episode4FixtureLocator: NSObject {}

@MainActor
struct Episode4ManifestTests {
    @Test func realPublishedEpisodeFourMergesAndRemainsAfterOfflineRestart() throws {
        let bundle = Bundle(for: Episode4FixtureLocator.self)
        let oldURL = try #require(Bundle.main.url(forResource: "SamplePDFCatalog", withExtension: "json"))
        let fixtureURL = try #require(bundle.url(forResource: "pdf-manifest-ep4-v1", withExtension: "json") ?? bundle.url(forResource: "pdf-manifest-ep4-v1", withExtension: "json", subdirectory: "Fixtures"))
        let old = try JSONDecoder().decode(SamplePDFCatalog.self, from: Data(contentsOf: oldURL))
        let manifest = try JSONDecoder().decode(SamplePDFManifest.self, from: Data(contentsOf: fixtureURL))
        let merged = try manifest.catalog(preserving: old)
        #expect(merged.samples.count == 52)
        let retained = Array(merged.samples.prefix(51))
        #expect(retained.map(\.id) == old.samples.map(\.id))
        #expect(retained.map(\.fileName) == old.samples.map(\.fileName))
        #expect(retained.map(\.languageCode) == old.samples.map(\.languageCode))
        #expect(retained.map(\.downloadURL) == old.samples.map(\.downloadURL))
        #expect(retained.map(\.byteSize) == old.samples.map(\.byteSize))
        #expect(retained.map(\.sha256) == old.samples.map(\.sha256))
        let ep4 = try #require(merged.samples.first { $0.id == "tameshibu-episode4-ja" })
        #expect(ep4.languageCode == "ja")
        #expect(ep4.fileName == "tameshibu_episode4_ja.pdf")
        #expect(ep4.byteSize == 99_981_486)
        #expect(ep4.sha256 == "7c4bde39dc25800aa097854c6e47f31934abe12b3a05d97450fb73523af3c3dc")
        #expect(ep4.downloadURL.absoluteString == "https://github.com/tyamada/manga-prompt-kit/releases/download/manga-pdf-20261127-ep4-ja-v1/tameshibu_episode4_ja.pdf")
        #expect(merged.samples.filter { $0.languageCode == "ja" }.count == 4)
        #expect(!merged.samples.filter { $0.languageCode == "en" }.contains(ep4))
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try JSONEncoder().encode(merged).write(to: base.appendingPathComponent(".SamplePDFCatalog-v1.json"))
        let retainedPDF = base.appendingPathComponent("SamplePDFs").appendingPathComponent(old.samples[0].fileName)
        try FileManager.default.createDirectory(at: retainedPDF.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data("%PDF-existing-cache-unchanged".utf8)
        try original.write(to: retainedPDF)
        let restart = SamplePDFStore(documentsDirectory: base, bundledCatalogURL: oldURL)
        restart.loadCatalog()
        #expect(restart.catalogSource == "cached")
        #expect(restart.catalog?.samples.count == 52)
        #expect(restart.catalog?.samples.contains(ep4) == true)
        #expect(try Data(contentsOf: retainedPDF) == original)
    }
}
