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
import Combine

/// PDFビューアの表示ロジックを管理するViewModel
@MainActor
public class PDFViewerViewModel: NSObject, ObservableObject {
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
    @Published public private(set) var isSearching = false
    @Published public private(set) var isPortrait = false

    public struct PDFSearchMatch: Identifiable {
        public var id: Int { pageIndex }
        public let pageIndex: Int
        public let rects: [CGRect]
    }

    public enum LoadDocumentResult: Equatable {
        case loaded
        case passwordRequired
        case invalidPassword
        case failed(String)
    }

    public static var defaultSessionURL: URL {
        URL.applicationSupportDirectory.appendingPathComponent("ReadingSession.json")
    }

    private let sessionStore: ReadingSessionStore
    private let securityScopedResourceManager = SecurityScopedResourceManager()
    // Rendering preferences belong to the app, independently of the open PDF.
    private let preferences: UserDefaults?
    private static let highQualityPreferenceKey = "isHighQualityRenderingEnabled"
    private static let sharpnessPreferenceKey = "isSharpnessEnabled"
    private static let singlePageInPortraitPreferenceKey = "isSinglePageInPortraitEnabled"
    private static let defaultSinglePageInPortraitEnabled = true
    private var documentBookmark: Data?
    private var pendingSession: ReadingSessionStore.Restoration?
    private var isLoadingDocument = false
    private var activeSearchDocument: PDFDocument?
    private var searchRectsByPage: [Int: [CGRect]] = [:]
    private var searchSelectionCount = 0
    private var searchStartedAt: TimeInterval?

    public init(
        settings: PDFViewerSettings? = nil,
        sessionURL: URL? = nil,
        preferences: UserDefaults? = nil
    ) {
        self.sessionStore = ReadingSessionStore(fileURL: sessionURL)
        self.preferences = preferences
        if let settings = settings {
            self.settings = settings
        } else {
            let savedPortraitPreference = preferences?.object(forKey: Self.singlePageInPortraitPreferenceKey) as? Bool
            self.settings = PDFViewerSettings(
                isHighQualityRenderingEnabled: preferences?.bool(forKey: Self.highQualityPreferenceKey) ?? false,
                isSharpnessEnabled: preferences?.bool(forKey: Self.sharpnessPreferenceKey) ?? false,
                isSinglePageInPortraitEnabled: savedPortraitPreference ?? Self.defaultSinglePageInPortraitEnabled
            )
        }
        super.init()
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
        guard let pdfDocument = document?.pdfDocument, !query.isEmpty else {
            cancelSearch()
            return
        }

        if let activeSearchDocument {
            activeSearchDocument.delegate = nil
            activeSearchDocument.cancelFindString()
            self.activeSearchDocument = nil
        }

        startSearch(in: pdfDocument, query: query)
    }

    private func startSearch(in pdfDocument: PDFDocument, query: String) {
        activeSearchDocument = pdfDocument
        searchRectsByPage = [:]
        searchSelectionCount = 0
        searchStartedAt = ProcessInfo.processInfo.systemUptime
        isSearching = true
        AppDiagnostics.record(.searchStarted)
        pdfDocument.delegate = self
        pdfDocument.beginFindString(query, withOptions: .caseInsensitive)
    }

    private func cancelSearch() {
        let document = activeSearchDocument
        activeSearchDocument = nil
        searchRectsByPage = [:]
        searchSelectionCount = 0
        searchStartedAt = nil
        isSearching = false
        searchMatches = []
        document?.delegate = nil
        document?.cancelFindString()
    }

    /// PDFドキュメントをロードする
    @discardableResult
    public func loadDocument(from url: URL, password: String? = nil) -> LoadDocumentResult {
        let startedAt = ProcessInfo.processInfo.systemUptime
        AppDiagnostics.record(.documentLoadStarted)
        cancelSearch()
        isLoadingDocument = true
        defer { isLoadingDocument = false }
        if pendingSession?.url != url { pendingSession = nil }
        documentBookmark = nil
        securityScopedResourceManager.beginAccessing(url)
        
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
            if sessionStore.isEnabled {
                do {
                    documentBookmark = try sessionStore.makeBookmark(for: url)
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
            securityScopedResourceManager.stopAccessing()
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
        do {
            pendingSession = try sessionStore.restoration()
            return pendingSession?.url
        } catch {
            clearReadingSession()
            errorMessage = error.localizedDescription
            return nil
        }
    }

    public func saveReadingSession() {
        guard !isLoadingDocument, document != nil, let bookmark = documentBookmark else { return }
        let state = ReadingSessionStore.State(
            bookmark: bookmark, pageIndex: currentPageIndex, searchQuery: searchQuery,
            isSpread: settings.isSpreadViewEnabled, isCover: settings.isCoverPageEnabled,
            isRightToLeft: settings.layoutDirection == .rightToLeft
        )
        do {
            try sessionStore.save(state)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func clearReadingSession() {
        pendingSession = nil
        documentBookmark = nil
        do { try sessionStore.remove() }
        catch { errorMessage = error.localizedDescription }
    }

    public func clearReadingSession(ifMatching url: URL) {
        if pendingSession?.url.standardizedFileURL == url.standardizedFileURL {
            clearReadingSession()
            return
        }

        do {
            if try sessionStore.containsSession(for: url) {
                clearReadingSession()
            }
        } catch {
            clearReadingSession()
        }
    }

    public func cancelPendingDocumentLoad() {
        cancelSearch()
        clearReadingSession()
        securityScopedResourceManager.stopAccessing()
        self.document = nil
        self.currentPageIndex = 0
    }

    /// 現在のドキュメントを閉じる
    public func closeDocument() {
        AppDiagnostics.record(.documentClosed)
        cancelSearch()
        clearReadingSession()
        securityScopedResourceManager.stopAccessing()
        self.document = nil
        self.currentPageIndex = 0
        self.searchQuery = ""
    }

    /// アプリ設定を初期状態に戻す
    public func resetApplicationSettings() {
        AppDiagnostics.record(.settingsReset)
        self.settings.isSpreadViewEnabled = false
        self.settings.isCoverPageEnabled = false
        self.settings.coverPageSetting = .typeA
        self.settings.isHighQualityRenderingEnabled = false
        self.settings.isSharpnessEnabled = false
        self.settings.isSinglePageInPortraitEnabled = Self.defaultSinglePageInPortraitEnabled
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

extension PDFViewerViewModel: PDFDocumentDelegate {
    public func didMatchString(_ instance: PDFSelection) {
        guard let pdfDocument = activeSearchDocument,
              let page = instance.pages.first else {
            return
        }

        let pageIndex = pdfDocument.index(for: page)
        guard pageIndex != NSNotFound else { return }

        searchRectsByPage[pageIndex, default: []].append(instance.bounds(for: page))
        searchSelectionCount += 1
    }

    public func documentDidEndDocumentFind(_ notification: Notification) {
        guard let finishedDocument = notification.object as? PDFDocument,
              finishedDocument === activeSearchDocument else {
            return
        }

        activeSearchDocument = nil

        searchMatches = searchRectsByPage.map { pageIndex, rects in
            PDFSearchMatch(pageIndex: pageIndex, rects: rects)
        }.sorted { $0.pageIndex < $1.pageIndex }
        isSearching = false

        if let searchStartedAt {
            let duration = Self.elapsedMilliseconds(since: searchStartedAt)
            AppDiagnostics.record(
                .searchCompleted,
                durationMilliseconds: duration,
                numericValue: searchSelectionCount,
                numericLabel: .matches
            )
            if duration >= 500 {
                AppDiagnostics.record(.searchSlow, durationMilliseconds: duration)
            }
        }

        searchRectsByPage = [:]
        searchSelectionCount = 0
        searchStartedAt = nil
    }
}
