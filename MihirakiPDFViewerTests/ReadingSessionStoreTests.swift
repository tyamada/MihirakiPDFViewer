//
// ReadingSessionStoreTests.swift
// MihirakiPDFViewerTests
//
// Copyright 2026 Takuma Yamada.
//

import Foundation
import Testing
@testable import MihirakiPDFViewer

struct ReadingSessionStoreTests {
    @Test
    func savesAndRestoresBookmarkAndReaderState() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let state = try fixture.makeState(pageIndex: 7, searchQuery: "sample")

        try fixture.store.save(state)
        let storedRestoration = try fixture.store.restoration()
        let restoration = try #require(storedRestoration)

        #expect(restoration.url.standardizedFileURL == fixture.documentURL.standardizedFileURL)
        #expect(restoration.state == state)
        #expect(try fixture.store.containsSession(for: fixture.documentURL))
    }

    @Test
    func removeDeletesPersistedSession() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.store.save(try fixture.makeState())

        try fixture.store.remove()

        #expect(try fixture.store.restoration() == nil)
    }

    @Test
    func disabledStorePerformsNoFileOperations() throws {
        let store = ReadingSessionStore(fileURL: nil)
        let state = ReadingSessionStore.State(
            bookmark: Data(),
            pageIndex: 0,
            searchQuery: "",
            isSpread: false,
            isCover: false,
            isRightToLeft: false
        )

        try store.save(state)
        try store.remove()

        #expect(!store.isEnabled)
        #expect(try store.restoration() == nil)
    }

    private struct Fixture {
        let rootURL: URL
        let documentURL: URL
        let sessionURL: URL
        let store: ReadingSessionStore

        init() throws {
            rootURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            documentURL = rootURL.appendingPathComponent("Document.pdf")
            sessionURL = rootURL.appendingPathComponent("Session/ReadingSession.json")
            try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
            try Data("%PDF-test".utf8).write(to: documentURL)
            store = ReadingSessionStore(fileURL: sessionURL)
        }

        func makeState(pageIndex: Int = 2, searchQuery: String = "query") throws -> ReadingSessionStore.State {
            ReadingSessionStore.State(
                bookmark: try store.makeBookmark(for: documentURL),
                pageIndex: pageIndex,
                searchQuery: searchQuery,
                isSpread: true,
                isCover: true,
                isRightToLeft: true
            )
        }

        func remove() {
            try? FileManager.default.removeItem(at: rootURL)
        }
    }
}
