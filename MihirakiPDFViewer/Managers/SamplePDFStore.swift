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

    private(set) var catalog: SamplePDFCatalog?
    private(set) var states: [String: SamplePDFDownloadState] = [:]
    private(set) var isUsingCellular = false
    private(set) var isNetworkPathKnown = false
    var errorMessage: String?

    private let fileManager: FileManager
    private let session: URLSession
    private let catalogBundle: Bundle
    private let documentsDirectory: URL
    private let pathMonitor: NWPathMonitor
    private let pathMonitorQueue = DispatchQueue(label: "SamplePDFStore.NetworkPath")

    init(
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        catalogBundle: Bundle = .main,
        documentsDirectory: URL = URL.documentsDirectory,
        pathMonitor: NWPathMonitor = NWPathMonitor()
    ) {
        self.fileManager = fileManager
        self.session = session
        self.catalogBundle = catalogBundle
        self.documentsDirectory = documentsDirectory
        self.pathMonitor = pathMonitor

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
        do {
            guard let url = catalogBundle.url(forResource: "SamplePDFCatalog", withExtension: "json") else {
                throw SamplePDFStoreError.catalogUnavailable
            }

            let decodedCatalog = try JSONDecoder().decode(
                SamplePDFCatalog.self,
                from: Data(contentsOf: url)
            )
            try validate(decodedCatalog)
            catalog = decodedCatalog
            refreshDownloadStates()
        } catch {
            errorMessage = SamplePDFStoreError.catalogUnavailable.localizedDescription
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
            let destinationDirectory = documentsDirectory.appendingPathComponent("SamplePDFs", isDirectory: true)
            try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

            var request = URLRequest(
                url: sample.downloadURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 300
            )
            request.allowsCellularAccess = allowsCellular
            let (temporaryURL, response) = try await session.download(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw SamplePDFStoreError.invalidServerResponse
            }
            try validateDownloadURL(httpResponse.url)
            try await validateDownloadedFile(at: temporaryURL, sample: sample)

            let destinationURL = destinationURL(for: sample)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)

            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var mutableDestinationURL = destinationURL
            try mutableDestinationURL.setResourceValues(resourceValues)

            states[sample.id] = .downloaded
        } catch is CancellationError {
            states[sample.id] = .notDownloaded
        } catch {
            states[sample.id] = .notDownloaded
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? SamplePDFStoreError.downloadFailed.localizedDescription
        }
    }

    func delete(_ sample: SamplePDF) {
        states[sample.id] = .deleting
        errorMessage = nil

        do {
            let url = destinationURL(for: sample)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            states[sample.id] = .notDownloaded
        } catch {
            states[sample.id] = .downloaded
            errorMessage = SamplePDFStoreError.deleteFailed.localizedDescription
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
              catalog.license.creator == "Takuma Yamada" else {
            throw SamplePDFStoreError.invalidCatalog
        }

        var ids = Set<String>()
        var fileNames = Set<String>()

        for sample in catalog.samples {
            guard !sample.id.isEmpty,
                  ids.insert(sample.id).inserted,
                  fileNames.insert(sample.fileName).inserted,
                  sample.byteSize > 0,
                  sample.byteSize <= Self.maximumFileSize,
                  sample.fileName == URL(fileURLWithPath: sample.fileName).lastPathComponent,
                  sample.fileName.lowercased().hasSuffix(".pdf"),
                  sample.sha256.count == 64,
                  sample.sha256.allSatisfy({ $0.isHexDigit }) else {
                throw SamplePDFStoreError.invalidCatalog
            }
            try validateDownloadURL(sample.downloadURL)
        }
    }

    private func validateDownloadURL(_ url: URL?) throws {
        guard let url,
              url.scheme == "https",
              url.host == "tyamada.github.io",
              url.path.hasPrefix("/MihirakiPDFViewer/sample/") else {
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
