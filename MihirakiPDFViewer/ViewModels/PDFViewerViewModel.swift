//
// PDFViewerViewModel.swift
// MihirakiPDFViewer
//
// Created by Cline on 2026/07/02.
// Reviewed & Updated by Takuma Yamada.
//
// Copyright 2026 Takuma Yamada.
//
// This software is released under the MIT License.
// For the full license text, please see the LICENSE file in the root directory.
//

import Foundation
import PDFKit
import SwiftUI
import UIKit
import Combine

/// PDFビューアの表示ロジックを管理するViewModel
@MainActor
public class PDFViewerViewModel: ObservableObject {
    @Published public var document: PDFDocumentWrapper?
    @Published public var settings: PDFViewerSettings {
        didSet {
            if settings.isHighQualityRenderingEnabled != oldValue.isHighQualityRenderingEnabled {
                preferences?.set(settings.isHighQualityRenderingEnabled, forKey: Self.highQualityPreferenceKey)
            }
            if settings.isSharpnessEnabled != oldValue.isSharpnessEnabled {
                preferences?.set(settings.isSharpnessEnabled, forKey: Self.sharpnessPreferenceKey)
            }
            AppDiagnostics.record(.displaySettingsChanged)
            if settings.isSinglePageInPortraitEnabled != oldValue.isSinglePageInPortraitEnabled {
                preferences?.set(settings.isSinglePageInPortraitEnabled, forKey: Self.singlePageInPortraitPreferenceKey)
            }
            preserveDisplayedPageWhenLayoutChanges(from: oldValue)
            saveReadingSession()
        }
    }
    @Published public var errorMessage: String?
    @Published public var currentPageIndex: Int = 0 {
        didSet {
            if currentPageIndex != oldValue {
                AppDiagnostics.record(
                    .pageChanged,
                    numericValue: currentPageIndex + 1,
                    numericLabel: .page
                )
            }
            saveReadingSession()
        }
    }
    @Published public var searchQuery: String = "" { didSet { saveReadingSession() } }
    @Published public var searchMatches: [PDFSearchMatch] = []
    @Published public private(set) var isPortrait = false

    public struct PDFSearchMatch: Identifiable {
        public let id = UUID()
        public let pageIndex: Int
        public let rects: [CGRect]
    }

    public enum LoadDocumentResult: Equatable {
        case loaded
        case passwordRequired
        case invalidPassword
        case failed(String)
    }

    private var securityScopedURL: URL?
    private var isAccessingResource = false

    // The bookmark preserves access to PDFs chosen from document providers.
    // Passwords are deliberately excluded; protected PDFs prompt again.
    private struct ReadingSession: Codable {
        var bookmark: Data
        var pageIndex: Int
        var searchQuery: String
        var isSpread: Bool
        var isCover: Bool
        var isRightToLeft: Bool
    }

    public static var defaultSessionURL: URL {
        URL.applicationSupportDirectory.appendingPathComponent("ReadingSession.json")
    }

    private let sessionURL: URL?
    // Rendering preferences belong to the app, independently of the open PDF.
    private let preferences: UserDefaults?
    private static let highQualityPreferenceKey = "isHighQualityRenderingEnabled"
    private static let sharpnessPreferenceKey = "isSharpnessEnabled"
    private static let singlePageInPortraitPreferenceKey = "isSinglePageInPortraitEnabled"
    private let defaultSinglePageInPortraitEnabled: Bool
    private var documentBookmark: Data?
    private var pendingSession: (url: URL, state: ReadingSession)?
    private var isLoadingDocument = false

    public init(
        settings: PDFViewerSettings? = nil,
        sessionURL: URL? = nil,
        preferences: UserDefaults? = nil,
        isPhone: Bool? = nil
    ) {
        let defaultSinglePageInPortraitEnabled = isPhone ?? (UIDevice.current.userInterfaceIdiom == .phone)
        self.sessionURL = sessionURL
        self.preferences = preferences
        self.defaultSinglePageInPortraitEnabled = defaultSinglePageInPortraitEnabled
        if let settings = settings {
            self.settings = settings
        } else {
            let savedPortraitPreference = preferences?.object(forKey: Self.singlePageInPortraitPreferenceKey) as? Bool
            self.settings = PDFViewerSettings(
                isHighQualityRenderingEnabled: preferences?.bool(forKey: Self.highQualityPreferenceKey) ?? false,
                isSharpnessEnabled: preferences?.bool(forKey: Self.sharpnessPreferenceKey) ?? false,
                isSinglePageInPortraitEnabled: savedPortraitPreference ?? defaultSinglePageInPortraitEnabled
            )
        }
    }

    /// 表示すべきページのグループ（1ページまたは2ページのペア）
    public struct PageGroup: Identifiable {
        public let id: Int
        public let pages: [PDFPage]
        public let startIndex: Int
        public let pageIndices: [Int]
    }

    public var isSpreadLayoutEnabled: Bool {
        effectiveSpreadLayoutEnabled(for: settings, isPortrait: isPortrait)
    }

    public var pageGroups: [PageGroup] {
        makePageGroups(settings: settings, isPortrait: isPortrait)
    }

    public func updateViewportSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let newIsPortrait = size.height >= size.width
        guard newIsPortrait != isPortrait else { return }

        let oldGroups = pageGroups
        let displayedPageIndex = displayedPageIndex(in: oldGroups)
        isPortrait = newIsPortrait
        restoreDisplayedPage(displayedPageIndex, in: pageGroups)
    }

    private func effectiveSpreadLayoutEnabled(for settings: PDFViewerSettings, isPortrait: Bool) -> Bool {
        settings.isSpreadViewEnabled && !(isPortrait && settings.isSinglePageInPortraitEnabled)
    }

    private func makePageGroups(settings: PDFViewerSettings, isPortrait: Bool) -> [PageGroup] {
        guard let document else { return [] }
        let totalPages = document.totalPageCount
        var groups: [PageGroup] = []
        var currentIndex = 0

        if settings.isCoverPageEnabled, totalPages > 0,
           let firstPage = document.pdfDocument.page(at: 0) {
            groups.append(PageGroup(
                id: currentIndex,
                pages: [firstPage],
                startIndex: currentIndex,
                pageIndices: [currentIndex]
            ))
            currentIndex += 1
        }

        if effectiveSpreadLayoutEnabled(for: settings, isPortrait: isPortrait) {
            while currentIndex < totalPages {
                var pageIndices = [currentIndex]
                if currentIndex + 1 < totalPages {
                    pageIndices.append(currentIndex + 1)
                }

                if settings.layoutDirection == .rightToLeft, pageIndices.count == 2 {
                    pageIndices.reverse()
                }

                let pages = pageIndices.compactMap { document.pdfDocument.page(at: $0) }
                groups.append(PageGroup(
                    id: currentIndex,
                    pages: pages,
                    startIndex: currentIndex,
                    pageIndices: pageIndices
                ))
                currentIndex += 2
            }
        } else {
            while currentIndex < totalPages {
                if let page = document.pdfDocument.page(at: currentIndex) {
                    groups.append(PageGroup(
                        id: currentIndex,
                        pages: [page],
                        startIndex: currentIndex,
                        pageIndices: [currentIndex]
                    ))
                }
                currentIndex += 1
            }
        }

        return groups
    }

    private func preserveDisplayedPageWhenLayoutChanges(from oldSettings: PDFViewerSettings) {
        let oldGroups = makePageGroups(settings: oldSettings, isPortrait: isPortrait)
        let displayedPageIndex = displayedPageIndex(in: oldGroups)
        restoreDisplayedPage(displayedPageIndex, in: pageGroups)
    }

    private func displayedPageIndex(in groups: [PageGroup]) -> Int? {
        guard groups.indices.contains(currentPageIndex) else { return nil }
        return groups[currentPageIndex].startIndex
    }

    private func restoreDisplayedPage(_ pageIndex: Int?, in groups: [PageGroup]) {
        guard let pageIndex,
              let groupIndex = groups.firstIndex(where: { $0.pageIndices.contains(pageIndex) }) else {
            if groups.isEmpty {
                currentPageIndex = 0
            } else if currentPageIndex >= groups.count {
                currentPageIndex = groups.count - 1
            }
            return
        }
        currentPageIndex = groupIndex
    }

    public func performSearch(query: String) {
        guard let document = document, !query.isEmpty else {
            searchMatches = []
            return
        }

        let startedAt = ProcessInfo.processInfo.systemUptime
        AppDiagnostics.record(.searchStarted)
        let pdfDocument = document.pdfDocument
        var matchesDict: [Int: [CGRect]] = [:]
        
        let selections = pdfDocument.findString(query, withOptions: .caseInsensitive)
        
        // Create a mapping from PDFPage to its index in the document
        var pageToIndex: [PDFPage: Int] = [:]
        for i in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: i) {
                pageToIndex[page] = i
            }
        }

        for selection in selections {
            // Get the first page of the selection and its index
            if let firstPage = selection.pages.first, 
               let pageIndex = pageToIndex[firstPage] {
                // Get the bounds of the selection on that specific page
                let rect = selection.bounds(for: firstPage)
                matchesDict[pageIndex, default: []].append(rect)
            }
        }
        
        // Map the dictionary to the array of search matches
        self.searchMatches = matchesDict.map { (index, rects) in
            PDFSearchMatch(pageIndex: index, rects: rects)
        }.sorted { $0.pageIndex < $1.pageIndex }

        let duration = Self.elapsedMilliseconds(since: startedAt)
        AppDiagnostics.record(
            .searchCompleted,
            durationMilliseconds: duration,
            numericValue: selections.count,
            numericLabel: .matches
        )
        if duration >= 500 {
            AppDiagnostics.record(.searchSlow, durationMilliseconds: duration)
        }
    }

    /// PDFドキュメントをロードする
    @discardableResult
    public func loadDocument(from url: URL, password: String? = nil) -> LoadDocumentResult {
        let startedAt = ProcessInfo.processInfo.systemUptime
        AppDiagnostics.record(.documentLoadStarted)
        isLoadingDocument = true
        defer { isLoadingDocument = false }
        if pendingSession?.url != url { pendingSession = nil }
        documentBookmark = nil
        // 以前のアクセスを停止
        stopCurrentAccess()
        
        // セキュリティスコープへのアクセスを開始
        let accessing = url.startAccessingSecurityScopedResource()
        securityScopedURL = url
        isAccessingResource = accessing
        
        do {
            let loadedDocument = try PDFDocumentWrapper(url: url, password: password)
            self.document = loadedDocument
            self.errorMessage = nil
            // ドキュメントのメタデータに基づいて、表示設定を更新
            self.settings.layoutDirection = loadedDocument.layoutDirection
            self.settings.isSpreadViewEnabled = loadedDocument.isSpreadViewEnabled
            self.settings.isCoverPageEnabled = loadedDocument.isCoverPageEnabled
            self.currentPageIndex = 0
            self.searchQuery = ""
            self.searchMatches = []
            if let restored = pendingSession?.state {
                settings.isSpreadViewEnabled = restored.isSpread
                settings.isCoverPageEnabled = restored.isCover
                settings.layoutDirection = restored.isRightToLeft ? .rightToLeft : .leftToRight
                currentPageIndex = min(max(0, restored.pageIndex), max(0, pageGroups.count - 1))
                searchQuery = restored.searchQuery
                performSearch(query: searchQuery)
            }
            pendingSession = nil
            if sessionURL != nil {
                do {
                    documentBookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                    isLoadingDocument = false
                    saveReadingSession()
                } catch {
                    clearReadingSession()
                    errorMessage = error.localizedDescription
                }
            }
            AppDiagnostics.record(
                .documentLoaded,
                durationMilliseconds: Self.elapsedMilliseconds(since: startedAt),
                numericValue: loadedDocument.totalPageCount,
                numericLabel: .pages
            )
            return .loaded
        } catch PDFDocumentWrapperError.passwordRequired {
            self.document = nil
            self.errorMessage = nil
            AppDiagnostics.record(
                .documentPasswordRequired,
                durationMilliseconds: Self.elapsedMilliseconds(since: startedAt)
            )
            return .passwordRequired
        } catch PDFDocumentWrapperError.invalidPassword {
            self.document = nil
            self.errorMessage = nil
            AppDiagnostics.record(
                .documentPasswordRejected,
                durationMilliseconds: Self.elapsedMilliseconds(since: startedAt)
            )
            return .invalidPassword
        } catch {
            clearReadingSession()
            stopCurrentAccess()
            self.document = nil
            let message = error.localizedDescription
            self.errorMessage = message
            AppDiagnostics.record(
                .documentLoadFailed,
                durationMilliseconds: Self.elapsedMilliseconds(since: startedAt)
            )
            return .failed(message)
        }
    }

    /// Resolve the last PDF before opening it through the normal password flow.
    public func documentURLForRestoration() -> URL? {
        guard let sessionURL, FileManager.default.fileExists(atPath: sessionURL.path) else { return nil }
        do {
            let state = try JSONDecoder().decode(ReadingSession.self, from: Data(contentsOf: sessionURL))
            var stale = false
            let url = try URL(resolvingBookmarkData: state.bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
            pendingSession = (url, state)
            return url
        } catch {
            clearReadingSession()
            errorMessage = error.localizedDescription
            return nil
        }
    }

    public func saveReadingSession() {
        guard !isLoadingDocument, document != nil, let bookmark = documentBookmark, let sessionURL else { return }
        let state = ReadingSession(
            bookmark: bookmark, pageIndex: currentPageIndex, searchQuery: searchQuery,
            isSpread: settings.isSpreadViewEnabled, isCover: settings.isCoverPageEnabled,
            isRightToLeft: settings.layoutDirection == .rightToLeft
        )
        do {
            try FileManager.default.createDirectory(at: sessionURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(state).write(to: sessionURL, options: .atomic)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func clearReadingSession() {
        pendingSession = nil
        documentBookmark = nil
        guard let sessionURL, FileManager.default.fileExists(atPath: sessionURL.path) else { return }
        do { try FileManager.default.removeItem(at: sessionURL) }
        catch { errorMessage = error.localizedDescription }
    }

    public func clearReadingSession(ifMatching url: URL) {
        if pendingSession?.url.standardizedFileURL == url.standardizedFileURL {
            clearReadingSession()
            return
        }

        guard let sessionURL, FileManager.default.fileExists(atPath: sessionURL.path) else { return }
        do {
            let state = try JSONDecoder().decode(ReadingSession.self, from: Data(contentsOf: sessionURL))
            var stale = false
            let restoredURL = try URL(
                resolvingBookmarkData: state.bookmark,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            if restoredURL.standardizedFileURL == url.standardizedFileURL {
                clearReadingSession()
            }
        } catch {
            clearReadingSession()
        }
    }

    private func stopCurrentAccess() {
        if let url = securityScopedURL, isAccessingResource {
            url.stopAccessingSecurityScopedResource()
            isAccessingResource = false
            securityScopedURL = nil
        }
    }

    public func cancelPendingDocumentLoad() {
        clearReadingSession()
        stopCurrentAccess()
        self.document = nil
        self.currentPageIndex = 0
    }

    /// 現在のドキュメントを閉じる
    public func closeDocument() {
        AppDiagnostics.record(.documentClosed)
        clearReadingSession()
        stopCurrentAccess()
        self.document = nil
        self.currentPageIndex = 0
        self.searchQuery = ""
        self.searchMatches = []
    }

    /// アプリ設定を初期状態に戻す
    public func resetApplicationSettings() {
        AppDiagnostics.record(.settingsReset)
        self.settings.isSpreadViewEnabled = false
        self.settings.isCoverPageEnabled = false
        self.settings.coverPageSetting = .typeA
        self.settings.isHighQualityRenderingEnabled = false
        self.settings.isSharpnessEnabled = false
        self.settings.isSinglePageInPortraitEnabled = defaultSinglePageInPortraitEnabled
        closeDocument()
    }

    /// 設定を変更する
    private static func elapsedMilliseconds(since startedAt: TimeInterval) -> Int {
        Int(((ProcessInfo.processInfo.systemUptime - startedAt) * 1_000).rounded())
    }

    public func updateSettings(isSpreadViewEnabled: Bool, isCoverPageEnabled: Bool, layoutDirection: LayoutDirection) {
        self.settings = PDFViewerSettings(
            isSpreadViewEnabled: isSpreadViewEnabled,
            isCoverPageEnabled: isCoverPageEnabled,
            layoutDirection: layoutDirection,
            coverPageSetting: self.settings.coverPageSetting,
            isHighQualityRenderingEnabled: self.settings.isHighQualityRenderingEnabled,
            isSharpnessEnabled: self.settings.isSharpnessEnabled,
            isSinglePageInPortraitEnabled: self.settings.isSinglePageInPortraitEnabled
        )
    }
}
