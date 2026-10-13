//
// IncomingPDFImporterTests.swift
// MihirakiPDFViewerTests
//
// Copyright 2026 Takuma Yamada.
//

import Foundation
import Testing
@testable import MihirakiPDFViewer

struct IncomingPDFImporterTests {
    @Test
    func copiesIncomingPDFIntoImportedPDFDirectory() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        let destinationURL = try fixture.importer.copyImportedPDF(from: fixture.sourceURL)

        #expect(destinationURL.lastPathComponent == "Sample.pdf")
        #expect(destinationURL.deletingLastPathComponent().lastPathComponent == "ImportedPDFs")
        #expect(try Data(contentsOf: destinationURL) == fixture.data)
    }

    @Test
    func preservesExistingFileByCreatingUniqueDestinationName() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        let firstURL = try fixture.importer.copyImportedPDF(from: fixture.sourceURL)
        let secondURL = try fixture.importer.copyImportedPDF(from: fixture.sourceURL)

        #expect(firstURL.lastPathComponent == "Sample.pdf")
        #expect(secondURL.lastPathComponent == "Sample-2.pdf")
        #expect(try Data(contentsOf: firstURL) == fixture.data)
        #expect(try Data(contentsOf: secondURL) == fixture.data)
    }

    private struct Fixture {
        let rootURL: URL
        let sourceURL: URL
        let data = Data("%PDF-test".utf8)
        let importer: IncomingPDFImporter

        init() throws {
            rootURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            sourceURL = rootURL.appendingPathComponent("Source/Sample.pdf")
            try FileManager.default.createDirectory(
                at: sourceURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: sourceURL)
            importer = IncomingPDFImporter(importRootDirectory: rootURL.appendingPathComponent("Documents"))
        }

        func remove() {
            try? FileManager.default.removeItem(at: rootURL)
        }
    }
}
