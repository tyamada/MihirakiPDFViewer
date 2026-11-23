//
// SamplePDFStore.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import CryptoKit
import Foundation
import Network
import Observation

@MainActor
@Observable
final class SamplePDFStore {
    static let maximumFileSize: Int64 = 100 * 1024 * 1024
    static let maximumManifestSize = 2 * 1024 * 1024

    private(set) var isRefreshingCatalog = false
    private(set) var catalogSource: String?

    private(set) var catalog: SamplePDFCatalog?
    private(set) var states: [String: SamplePDFDownloadState] = [:]
    private(set) var isUsingCellular = false
    private(set) var isNetworkPathKnown = false
    var errorMessage: String?

    private let fileManager: FileManager
    private let session: URLSession
    private let catalogBundle: Bundle
    private let documentsDirectory: URL
    private let bundledCatalogURL: URL?
    private let manifestURL: URL
    private var catalogCacheURL: URL {
        documentsDirectory.appendingPathComponent(".SamplePDFCatalog-v1.json")
    }
    private let pathMonitor: NWPathMonitor
    private let pathMonitorQueue = DispatchQueue(label: "SamplePDFStore.NetworkPath")

    init(
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        catalogBundle: Bundle = .main,
        documentsDirectory: URL = URL.documentsDirectory,
        pathMonitor: NWPathMonitor = NWPathMonitor(),
        bundledCatalogURL: URL? = nil,
        manifestURL: URL = SamplePDFSourcePolicy.latestManifestURL
    ) {
        self.fileManager = fileManager
        self.session = session
        self.catalogBundle = catalogBundle
        self.documentsDirectory = documentsDirectory
        self.pathMonitor = pathMonitor
        self.bundledCatalogURL = bundledCatalogURL
        self.manifestURL = manifestURL

        pathMonitor.pathUpdateHandler = { [weak self] path in
            let isUsingCellular = path.status == .satisfied && path.usesInterfaceType(.cellular)
            Task { @MainActor [weak self] in
                self?.isUsingCellular = isUsingCellular
                self?.isNetworkPathKnown = true
            }
        }
        pathMonitor.start(queue: pathMonitorQueue)
    }

    deinit {
        pathMonitor.cancel()
    }

    func loadCatalog() {
        // Reappearing views must not reset a working remote list to the bundle.
        guard catalog == nil else { refreshDownloadStates(); return }
        do {
            guard let url = bundledCatalogURL ?? catalogBundle.url(forResource: "SamplePDFCatalog", withExtension: "json") else {
                throw SamplePDFStoreError.catalogUnavailable
            }
            let bundled = try JSONDecoder().decode(SamplePDFCatalog.self, from: Data(contentsOf: url))
            try validate(bundled)
            catalog = bundled
            catalogSource = "bundled"
            // A corrupt cache never prevents use of the bundled fallback.
            if let size = try? catalogCacheURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
               size <= Self.maximumManifestSize,
               let data = try? Data(contentsOf: catalogCacheURL),
               let cached = try? JSONDecoder().decode(SamplePDFCatalog.self, from: data),
               (try? validate(cached)) != nil {
                let cachedByID = Dictionary(uniqueKeysWithValues: cached.samples.map { ($0.id, $0) })
                let identitiesPreserved = bundled.samples.allSatisfy { original in
                    guard let cachedSample = cachedByID[original.id] else { return false }
                    return cachedSample.fileName == original.fileName && cachedSample.languageCode == original.languageCode
                }
                if identitiesPreserved { catalog = cached; catalogSource = "cached" }
            }
            refreshDownloadStates()
        } catch {
            errorMessage = SamplePDFStoreError.catalogUnavailable.localizedDescription
        }
    }

    /// A failed refresh deliberately leaves the usable catalog and PDF files alone.
    @discardableResult
    func refreshCatalog(allowsCellular: Bool = false) async -> Bool {
        if catalog == nil { loadCatalog() }
        guard !isRefreshingCatalog, let previous = catalog,
              SamplePDFSourcePolicy.isManifestURL(manifestURL) else { return false }
        isRefreshingCatalog = true
        defer { isRefreshingCatalog = false }
        do {
            var request = URLRequest(url: manifestURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            request.allowsCellularAccess = allowsCellular
            let (data, response) = try await session.data(for: request, delegate: SamplePDFRedirectGuard(forManifest: true, manifestURL: manifestURL))
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let responseURL = http.url, SamplePDFSourcePolicy.isManifestResponseURL(responseURL, requested: manifestURL),
                  !data.isEmpty, data.count <= Self.maximumManifestSize else { return false }
            let manifest = try JSONDecoder().decode(SamplePDFManifest.self, from: data)
            let candidate = try manifest.catalog(preserving: previous)
            try validate(candidate)
            // Never replace metadata while an action is using the old row snapshot.
            guard !states.values.contains(.downloading), !states.values.contains(.deleting) else { return false }
            let encoded = try JSONEncoder().encode(candidate)
            guard encoded.count <= Self.maximumManifestSize else { return false }
            try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
            try encoded.write(to: catalogCacheURL, options: .atomic)
            catalog = candidate
            catalogSource = "remote"
            refreshDownloadStates()
            return true
        } catch {
            // Offline, unsupported schema, bad entries, or persistence failures:
            // retain the last valid in-memory/on-disk list without a modal error.
            return false
        }
    }

    func refreshDownloadStates() {
        guard let catalog else { return }

        for sample in catalog.samples {
            let state = states[sample.id]
            guard state != .downloading, state != .deleting else { continue }
            states[sample.id] = fileManager.fileExists(atPath: destinationURL(for: sample).path)
                ? .downloaded
                : .notDownloaded
        }
    }

    func state(for sample: SamplePDF) -> SamplePDFDownloadState {
        states[sample.id] ?? .notDownloaded
    }

    func download(_ sample: SamplePDF, allowsCellular: Bool) async {
        guard state(for: sample) != .downloading else { return }

        states[sample.id] = .downloading
        errorMessage = nil

        do {
            try validateDownloadURL(sample.downloadURL)
            let existingURL = destinationURL(for: sample)
            if fileManager.fileExists(atPath: existingURL.path),
               (try? await validateDownloadedFile(at: existingURL, sample: sample)) != nil {
                states[sample.id] = .downloaded
                return
            }
            let destinationDirectory = documentsDirectory.appendingPathComponent("SamplePDFs", isDirectory: true)
            try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

            var request = URLRequest(
                url: sample.downloadURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 300
            )
            request.allowsCellularAccess = allowsCellular
            let (temporaryURL, response) = try await session.download(for: request, delegate: SamplePDFRedirectGuard(forManifest: false))
            // A rejected response/checksum must not leave a downloaded temporary PDF behind.
            // After a successful move the source no longer exists, so this is a no-op.
            defer { try? fileManager.removeItem(at: temporaryURL) }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw SamplePDFStoreError.invalidServerResponse
            }
            try validateResponseURL(httpResponse.url)
            try await validateDownloadedFile(at: temporaryURL, sample: sample)

            let destinationURL = destinationURL(for: sample)
            if fileManager.fileExists(atPath: destinationURL.path) {
                _ = try fileManager.replaceItemAt(destinationURL, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            }

            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var mutableDestinationURL = destinationURL
            try mutableDestinationURL.setResourceValues(resourceValues)

            states[sample.id] = .downloaded
        } catch is CancellationError {
            states[sample.id] = fileManager.fileExists(atPath: destinationURL(for: sample).path)
                ? .downloaded : .notDownloaded
        } catch {
            states[sample.id] = fileManager.fileExists(atPath: destinationURL(for: sample).path)
                ? .downloaded : .notDownloaded
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? SamplePDFStoreError.downloadFailed.localizedDescription
        }
    }

    @discardableResult
    func delete(_ sample: SamplePDF) -> Bool {
        guard state(for: sample) != .downloading else { return false }
        states[sample.id] = .deleting
        errorMessage = nil

        do {
            let url = destinationURL(for: sample)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            states[sample.id] = .notDownloaded
            return true
        } catch {
            states[sample.id] = .downloaded
            errorMessage = SamplePDFStoreError.deleteFailed.localizedDescription
            return false
        }
    }

    func localURL(for sample: SamplePDF) -> URL {
        destinationURL(for: sample)
    }

    private func destinationURL(for sample: SamplePDF) -> URL {
        documentsDirectory
            .appendingPathComponent("SamplePDFs", isDirectory: true)
            .appendingPathComponent(sample.fileName, isDirectory: false)
    }

    private func validate(_ catalog: SamplePDFCatalog) throws {
        guard catalog.schemaVersion == 1,
              catalog.license.identifier == "CC-BY-4.0",
              catalog.license.creator == "こまいろ日和 / Komairo Hiyori (Takuma Yamada)",
              catalog.license.url.absoluteString == "https://creativecommons.org/licenses/by/4.0/",
              !catalog.samples.isEmpty, catalog.samples.count <= 1000 else {
            throw SamplePDFStoreError.invalidCatalog
        }

        var ids = Set<String>()
        var fileNames = Set<String>()

        for sample in catalog.samples {
            guard !sample.id.isEmpty, !sample.title.isEmpty, !sample.languageCode.isEmpty,
                  ids.insert(sample.id).inserted,
                  fileNames.insert(sample.fileName).inserted,
                  sample.byteSize > 0,
                  sample.byteSize <= Self.maximumFileSize,
                  SamplePDFSourcePolicy.isSafeFileName(sample.fileName),
                  SamplePDFSourcePolicy.isSHA256(sample.sha256) else {
                throw SamplePDFStoreError.invalidCatalog
            }
            try validateDownloadURL(sample.downloadURL)
        }
    }

    private func validateDownloadURL(_ url: URL?) throws {
        guard let url, SamplePDFSourcePolicy.isPDFURL(url) else {
            throw SamplePDFStoreError.invalidDownloadURL
        }
    }

    private func validateResponseURL(_ url: URL?) throws {
        guard let url, SamplePDFSourcePolicy.isAssetResponseURL(url) else {
            throw SamplePDFStoreError.invalidDownloadURL
        }
    }

    private func validateDownloadedFile(at url: URL, sample: SamplePDF) async throws {
        let maximumFileSize = Self.maximumFileSize

        try await Task.detached(priority: .userInitiated) {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            let actualSize = Int64(values.fileSize ?? 0)
            guard actualSize > 0,
                  actualSize <= maximumFileSize,
                  actualSize == sample.byteSize else {
                throw SamplePDFStoreError.invalidFileSize
            }

            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }

            guard let header = try fileHandle.read(upToCount: 5),
                  header == Data("%PDF-".utf8) else {
                throw SamplePDFStoreError.invalidPDF
            }

            try fileHandle.seek(toOffset: 0)
            var hasher = SHA256()
            while let chunk = try fileHandle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
                hasher.update(data: chunk)
            }

            let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            guard digest == sample.sha256.lowercased() else {
                throw SamplePDFStoreError.checksumMismatch
            }
        }.value
    }
}

private enum SamplePDFStoreError: LocalizedError {
    case catalogUnavailable
    case invalidCatalog
    case invalidDownloadURL
    case invalidServerResponse
    case invalidFileSize
    case invalidPDF
    case checksumMismatch
    case downloadFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .catalogUnavailable, .invalidCatalog:
            String(localized: "sample_pdf_catalog_error", defaultValue: "The sample PDF list could not be loaded.")
        case .invalidDownloadURL:
            String(localized: "sample_pdf_url_error", defaultValue: "The sample PDF download URL is invalid.")
        case .invalidServerResponse:
            String(localized: "sample_pdf_server_error", defaultValue: "The sample PDF could not be downloaded from the server.")
        case .invalidFileSize:
            String(localized: "sample_pdf_size_error", defaultValue: "The downloaded file size is invalid.")
        case .invalidPDF:
            String(localized: "sample_pdf_format_error", defaultValue: "The downloaded file is not a valid PDF.")
        case .checksumMismatch:
            String(localized: "sample_pdf_checksum_error", defaultValue: "The downloaded PDF failed its integrity check.")
        case .downloadFailed:
            String(localized: "sample_pdf_download_error", defaultValue: "The sample PDF could not be downloaded.")
        case .deleteFailed:
            String(localized: "sample_pdf_delete_error", defaultValue: "The sample PDF could not be deleted.")
        }
    }
}

// Validate every redirect before following it, as well as checking the final URL.
private final class SamplePDFRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let forManifest: Bool
    let manifestURL: URL
    init(forManifest: Bool, manifestURL: URL = SamplePDFSourcePolicy.latestManifestURL) {
        self.forManifest = forManifest
        self.manifestURL = manifestURL
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        guard let url = request.url else { completionHandler(nil); return }
        let allowed = forManifest
            ? SamplePDFSourcePolicy.isManifestResponseURL(url, requested: manifestURL)
            : SamplePDFSourcePolicy.isAssetResponseURL(url)
        completionHandler(allowed ? request : nil)
    }
}
