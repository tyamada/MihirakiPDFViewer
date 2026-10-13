//
// IncomingPDFImporter.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import Foundation

/// Copies PDFs received from document providers into app-owned storage.
struct IncomingPDFImporter {
    private let fileManager: FileManager
    private let importRootDirectory: URL?

    init(fileManager: FileManager = .default, importRootDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.importRootDirectory = importRootDirectory
    }

    func copyImportedPDF(from sourceURL: URL) throws -> URL {
        let isAccessingResource = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessingResource {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let importDirectory = try importedPDFDirectoryURL()
        let destinationURL = uniqueImportedPDFURL(
            for: sourceURL.lastPathComponent.isEmpty ? "Document.pdf" : sourceURL.lastPathComponent,
            in: importDirectory
        )

        var coordinationError: NSError?
        var copyError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: sourceURL, options: [], error: &coordinationError) { readableURL in
            do {
                try fileManager.copyItem(at: readableURL, to: destinationURL)
            } catch {
                copyError = error
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        if let copyError {
            throw copyError
        }

        return destinationURL
    }

    private func importedPDFDirectoryURL() throws -> URL {
        let rootDirectory: URL
        if let importRootDirectory {
            rootDirectory = importRootDirectory
        } else {
            rootDirectory = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }

        let importDirectory = rootDirectory.appendingPathComponent("ImportedPDFs", isDirectory: true)
        try fileManager.createDirectory(at: importDirectory, withIntermediateDirectories: true)
        return importDirectory
    }

    private func uniqueImportedPDFURL(for fileName: String, in directory: URL) -> URL {
        let fileExtension = (fileName as NSString).pathExtension
        let baseName = (fileName as NSString).deletingPathExtension
        let sanitizedBaseName = baseName.isEmpty ? "Document" : baseName
        let sanitizedExtension = fileExtension.isEmpty ? "pdf" : fileExtension
        var candidateURL = directory
            .appendingPathComponent(sanitizedBaseName)
            .appendingPathExtension(sanitizedExtension)
        var copyIndex = 2

        while fileManager.fileExists(atPath: candidateURL.path) {
            candidateURL = directory
                .appendingPathComponent("\(sanitizedBaseName)-\(copyIndex)")
                .appendingPathExtension(sanitizedExtension)
            copyIndex += 1
        }

        return candidateURL
    }
}
