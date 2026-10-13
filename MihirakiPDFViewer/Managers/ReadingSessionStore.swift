//
// ReadingSessionStore.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import Foundation

/// Persists the document bookmark and reader state without retaining a PDF password.
struct ReadingSessionStore {
    struct State: Codable, Equatable {
        var bookmark: Data
        var pageIndex: Int
        var searchQuery: String
        var isSpread: Bool
        var isCover: Bool
        var isRightToLeft: Bool
    }

    struct Restoration: Equatable {
        let url: URL
        let state: State
    }

    var isEnabled: Bool { fileURL != nil }

    private let fileURL: URL?
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileURL: URL?,
        fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
    }

    func makeBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    func save(_ state: State) throws {
        guard let fileURL else { return }
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(state).write(to: fileURL, options: .atomic)
    }

    func restoration() throws -> Restoration? {
        guard let fileURL, fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let state = try decoder.decode(State.self, from: Data(contentsOf: fileURL))
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: state.bookmark,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return Restoration(url: url, state: state)
    }

    func remove() throws {
        guard let fileURL, fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    func containsSession(for url: URL) throws -> Bool {
        guard let restoration = try restoration() else { return false }
        return restoration.url.standardizedFileURL == url.standardizedFileURL
    }
}
