import CryptoKit
import Foundation
import Testing
@testable import MihirakiPDFViewer

private final class ManifestFixtureLocator: NSObject {}

@Suite(.serialized)
@MainActor
struct SamplePDFManifestTests {
    private func fixture(_ name: String) throws -> URL {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: ManifestFixtureLocator.self)
        #endif
        if name == "SamplePDFCatalog",
           let url = Bundle.main.url(forResource: name, withExtension: "json") { return url }
        return try #require(bundle.url(forResource: name, withExtension: "json")
            ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    }

    private func bundled() throws -> SamplePDFCatalog {
        try JSONDecoder().decode(SamplePDFCatalog.self, from: Data(contentsOf: fixture("SamplePDFCatalog")))
    }

    private func data() throws -> Data { try Data(contentsOf: fixture("pdf-manifest-v1")) }

    private func changed(_ mutation: (inout [String: Any]) -> Void) throws -> Data {
        var object = try #require(JSONSerialization.jsonObject(with: data()) as? [String: Any])
        mutation(&object)
        return try JSONSerialization.data(withJSONObject: object)
    }

    @Test func publishedManifestPreservesAllExistingIdentitiesAndOrder() throws {
        let old = try bundled()
        let manifest = try JSONDecoder().decode(SamplePDFManifest.self, from: data())
        let result = try manifest.catalog(preserving: old)
        #expect(result.samples.count == 51)
        #expect(result.samples.map(\.id) == old.samples.map(\.id))
        #expect(result.samples.map(\.fileName) == old.samples.map(\.fileName))
        #expect(result.samples.map(\.languageCode) == old.samples.map(\.languageCode))
        #expect(result.samples.map(\.downloadURL) == old.samples.map(\.downloadURL))
        #expect(result.samples.map(\.byteSize) == old.samples.map(\.byteSize))
        #expect(result.samples.map(\.sha256) == old.samples.map(\.sha256))
        #expect(result.samples.filter { $0.languageCode == "fil" }.count == 3)
        #expect(result.samples.filter { $0.languageCode == "fil" }.allSatisfy { $0.downloadURL.path.hasSuffix("_tl.pdf") })
        #expect(result.samples.first { $0.id == "tameshibu-episode1-en" }?.fileName == "tameshibu_episode1_2_en.pdf")
    }

    @Test func manifestCanAddAReleaseWithoutDroppingPriorEntries() throws {
        let payload = try changed { root in
            var entries = root["entries"] as! [[String: Any]]
            var new = entries[0]
            new["sample_id"] = "ep4_ja"; new["episode"] = 4
            new["filename"] = "episode4_ja.pdf"
            new["new_download_url"] = "https://github.com/tyamada/manga-prompt-kit/releases/download/manga-pdf-20261201-v1/episode4_ja.pdf"
            entries = [new]; root["entries"] = entries; root["pdf_count"] = 1
        }
        let old = try bundled()
        let result = try JSONDecoder().decode(SamplePDFManifest.self, from: payload).catalog(preserving: old)
        #expect(result.samples.count == 52)
        #expect(Array(result.samples.prefix(51)) == old.samples)
        #expect(result.samples.last?.id == "tameshibu-episode4-ja")
    }

    @Test(arguments: ["schema", "duplicateID", "duplicateFilename", "http", "wrongHost", "latest",
                      "wrongRepository", "filenameMismatch", "traversal", "badHash", "badBytes",
                      "license", "entryLicense", "empty", "count", "episode", "language", "locale"])
    func invalidManifestIsRejected(_ kind: String) throws {
        let payload = try changed { root in
            var entries = root["entries"] as! [[String: Any]]
            switch kind {
            case "schema": root["schema_version"] = 2
            case "duplicateID": entries[1] = entries[0]
            case "duplicateFilename": entries[1]["filename"] = entries[0]["filename"]
            case "http": entries[0]["new_download_url"] = (entries[0]["new_download_url"] as! String).replacingOccurrences(of: "https:", with: "http:")
            case "wrongHost": entries[0]["new_download_url"] = "https://example.com/episode.pdf"
            case "latest": entries[0]["new_download_url"] = "https://github.com/tyamada/manga-prompt-kit/releases/latest/download/tameshibu_episode1_2_ja.pdf"
            case "wrongRepository": entries[0]["new_download_url"] = (entries[0]["new_download_url"] as! String).replacingOccurrences(of: "manga-prompt-kit", with: "other")
            case "filenameMismatch": entries[0]["filename"] = "another.pdf"
            case "traversal": entries[0]["filename"] = "../escape.pdf"
            case "badHash": entries[0]["sha256"] = String(repeating: "g", count: 64)
            case "badBytes": entries[0]["bytes"] = 104857601
            case "license": root["license"] = "unknown"
            case "entryLicense": entries[0]["license"] = "unknown"
            case "empty": entries = []; root["pdf_count"] = 0
            case "count": root["pdf_count"] = 1
            case "episode": entries[0]["episode"] = 2
            case "language": entries[0]["language_key"] = "tl"
            case "locale": entries[0]["locale"] = "en-US"
            default: break
            }
            root["entries"] = entries
        }
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(SamplePDFManifest.self, from: payload).catalog(preserving: bundled())
        }
    }

    @Test func URLPolicyRejectsCredentialsPortsQueriesAndEncodedPaths() {
        let base = "https://github.com/tyamada/manga-prompt-kit/releases/download/manga-pdf-20261103-v1/a.pdf"
        for value in [base + "?token=x", base + "#fragment", base.replacingOccurrences(of: "github.com", with: "user@github.com"),
                      base.replacingOccurrences(of: "github.com", with: "github.com:443"),
                      base.replacingOccurrences(of: "a.pdf", with: "%61.pdf"),
                      base.replacingOccurrences(of: "a.pdf", with: "a%2fb.pdf")] {
            #expect(!SamplePDFSourcePolicy.isPDFURL(URL(string: value)!))
        }
        #expect(SamplePDFSourcePolicy.isManifestURL(SamplePDFSourcePolicy.latestManifestURL))
        #expect(SamplePDFSourcePolicy.isManifestURL(SamplePDFSourcePolicy.fixedManifestURL))
        #expect(!SamplePDFSourcePolicy.isManifestURL(URL(string: "https://raw.githubusercontent.com/other/repo/main/pdf-manifest.json")!))
        #expect(!SamplePDFSourcePolicy.isAssetResponseURL(URL(string: "http://release-assets.githubusercontent.com/a")!))
    }

    private func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ManifestMockProtocol.self]
        return URLSession(configuration: configuration)
    }

    @Test func successfulRefreshPersistsAndOfflineRestartKeepsCatalogAndPDFs() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        ManifestMockProtocol.configure(data: try data())
        let network = session(); defer { network.invalidateAndCancel() }
        let store = SamplePDFStore(session: network, documentsDirectory: root, bundledCatalogURL: try fixture("SamplePDFCatalog"))
        store.loadCatalog()
        let sample = try #require(store.catalog?.samples.first)
        let cachedPDF = store.localURL(for: sample)
        try FileManager.default.createDirectory(at: cachedPDF.deletingLastPathComponent(), withIntermediateDirectories: true)
        let originalPDF = Data("%PDF-old user-selected contents".utf8)
        try originalPDF.write(to: cachedPDF)
        #expect(await store.refreshCatalog())
        #expect(store.catalogSource == "remote")
        #expect(try Data(contentsOf: cachedPDF) == originalPDF)
        let cache = root.appendingPathComponent(".SamplePDFCatalog-v1.json")
        let goodCache = try Data(contentsOf: cache)
        ManifestMockProtocol.configure(data: Data(), failure: URLError(.notConnectedToInternet))
        let restart = SamplePDFStore(session: network, documentsDirectory: root, bundledCatalogURL: try fixture("SamplePDFCatalog"))
        restart.loadCatalog()
        #expect(restart.catalogSource == "cached")
        #expect(restart.catalog?.samples == store.catalog?.samples)
        #expect(!(await restart.refreshCatalog()))
        #expect(try Data(contentsOf: cache) == goodCache)
        #expect(try Data(contentsOf: cachedPDF) == originalPDF)
        #expect(restart.state(for: sample) == .downloaded)
        #expect(restart.errorMessage == nil)
    }

    @Test(arguments: ["json", "schema", "duplicate", "http", "status", "responseURL", "oversized"])
    func failedRefreshPreservesLastValidCatalogAndCache(_ kind: String) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let network = session(); defer { network.invalidateAndCancel() }
        ManifestMockProtocol.configure(data: try data())
        let store = SamplePDFStore(session: network, documentsDirectory: root, bundledCatalogURL: try fixture("SamplePDFCatalog"))
        #expect(await store.refreshCatalog())
        let old = store.catalog?.samples
        let cache = root.appendingPathComponent(".SamplePDFCatalog-v1.json")
        let disk = try Data(contentsOf: cache)
        var bad = try data(); var status = 200; var responseURL: URL? = nil
        switch kind {
        case "json": bad = Data("not json".utf8)
        case "schema": bad = try changed { $0["schema_version"] = 2 }
        case "duplicate": bad = try changed { root in var e = root["entries"] as! [[String: Any]]; e[1] = e[0]; root["entries"] = e }
        case "http": bad = try changed { root in var e = root["entries"] as! [[String: Any]]; e[0]["new_download_url"] = "http://example.com/a.pdf"; root["entries"] = e }
        case "status": status = 503
        case "responseURL": responseURL = URL(string: "https://example.com/pdf-manifest.json")!
        case "oversized": bad = Data(repeating: 32, count: SamplePDFStore.maximumManifestSize + 1)
        default: break
        }
        ManifestMockProtocol.configure(data: bad, status: status, responseURL: responseURL)
        #expect(!(await store.refreshCatalog()))
        #expect(store.catalog?.samples == old)
        #expect(try Data(contentsOf: cache) == disk)
    }

    @Test func corruptCacheFallsBackToBundleWithoutDeletingIt() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let cache = root.appendingPathComponent(".SamplePDFCatalog-v1.json")
        let bytes = Data("broken cached list".utf8); try bytes.write(to: cache)
        let store = SamplePDFStore(documentsDirectory: root, bundledCatalogURL: try fixture("SamplePDFCatalog"))
        store.loadCatalog()
        #expect(store.catalogSource == "bundled")
        #expect(store.catalog?.samples.count == 51)
        #expect(try Data(contentsOf: cache) == bytes)
    }

    @Test func cachedIdentityChangeIsRejected() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: fixture("SamplePDFCatalog"))) as? [String: Any])
        var samples = json["samples"] as! [[String: Any]]
        samples[0]["fileName"] = "renamed.pdf"
        json["samples"] = samples
        let cache = root.appendingPathComponent(".SamplePDFCatalog-v1.json")
        let bytes = try JSONSerialization.data(withJSONObject: json)
        try bytes.write(to: cache)
        let store = SamplePDFStore(documentsDirectory: root, bundledCatalogURL: try fixture("SamplePDFCatalog"))
        store.loadCatalog()
        #expect(store.catalogSource == "bundled")
        #expect(store.catalog?.samples == (try bundled()).samples)
        #expect(try Data(contentsOf: cache) == bytes)
    }

    @Test func persistenceFailureDoesNotApplyAnUnpersistedCatalog() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = root.appendingPathComponent(".SamplePDFCatalog-v1.json")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        ManifestMockProtocol.configure(data: try data())
        let network = session(); defer { network.invalidateAndCancel() }
        let store = SamplePDFStore(session: network, documentsDirectory: root, bundledCatalogURL: try fixture("SamplePDFCatalog"))
        store.loadCatalog()
        let original = store.catalog?.samples
        #expect(!(await store.refreshCatalog()))
        #expect(store.catalog?.samples == original)
        #expect(store.catalogSource == "bundled")
    }

    @Test func fixedManifestAllowsOnlyItsTrustedReleaseCDNResponse() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cdn = URL(string: "https://release-assets.githubusercontent.com/asset/catalog?signature=test")!
        #expect(SamplePDFSourcePolicy.isManifestResponseURL(cdn, requested: SamplePDFSourcePolicy.fixedManifestURL))
        #expect(!SamplePDFSourcePolicy.isManifestResponseURL(cdn, requested: SamplePDFSourcePolicy.latestManifestURL))
        ManifestMockProtocol.configure(data: try data(), responseURL: cdn)
        let network = session(); defer { network.invalidateAndCancel() }
        let store = SamplePDFStore(session: network, documentsDirectory: root,
            bundledCatalogURL: try fixture("SamplePDFCatalog"), manifestURL: SamplePDFSourcePolicy.fixedManifestURL)
        #expect(await store.refreshCatalog())
        #expect(store.catalog?.samples.count == 51)
    }

    @Test func validPDFCacheIsReusedWithoutAnyNetworkRequest() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = Data("%PDF-tiny verified fixture".utf8)
        let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let sample = SamplePDF(id: "retained", title: "Kept", languageCode: "fil", fileName: "kept_tl.pdf",
            downloadURL: URL(string: "https://github.com/tyamada/manga-prompt-kit/releases/download/manga-pdf-20261103-v1/absent.pdf")!, byteSize: Int64(bytes.count), sha256: hash)
        let network = session(); defer { network.invalidateAndCancel() }
        ManifestMockProtocol.configure(data: Data(), failure: URLError(.notConnectedToInternet))
        let store = SamplePDFStore(session: network, documentsDirectory: root)
        let file = store.localURL(for: sample)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: file)
        await store.download(sample, allowsCellular: false)
        #expect(ManifestMockProtocol.requestCount == 0)
        #expect(store.state(for: sample) == .downloaded)
        #expect(store.errorMessage == nil)
        #expect(try Data(contentsOf: file) == bytes)
    }
}

private final class ManifestMockProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var payload = Data()
    private static var status = 200
    private static var failure: Error?
    private static var responseURL: URL?
    private static var count = 0
    static var requestCount: Int { lock.lock(); defer { lock.unlock() }; return count }

    static func configure(data: Data, status: Int = 200, responseURL: URL? = nil, failure: Error? = nil) {
        lock.lock(); defer { lock.unlock() }
        payload = data; self.status = status; self.failure = failure; self.responseURL = responseURL; count = 0
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        let data = Self.payload, status = Self.status, failure = Self.failure, url = Self.responseURL ?? request.url!
        Self.count += 1; Self.lock.unlock()
        if let failure { client?.urlProtocol(self, didFailWithError: failure); return }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
