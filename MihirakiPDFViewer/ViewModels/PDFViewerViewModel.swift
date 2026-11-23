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
import Observation
import OSLog
import PDFKit
import SwiftUI

/// PDFビューアの表示ロジックを管理するViewModel
@MainActor
@Observable
public class PDFViewerViewModel: NSObject {
    public var document: PDFDocumentWrapper? {
        didSet { readingPageIndex = nil }
    }
    // Keep the exact PDF page when a viewport change temporarily pairs it with another page.
    private var readingPageIndex: Int?
    public var settings: PDFViewerSettings {
        didSet {
            accessibilitySelectionRevision += 1
            if settings.isHighQualityRenderingEnabled != oldValue.isHighQualityRenderingEnabled {
                preferences?.set(settings.isHighQualityRenderingEnabled, forKey: Self.highQualityPreferenceKey)
            }
            if settings.sharpnessAmount != oldValue.sharpnessAmount {
                preferences?.set(settings.sharpnessAmount, forKey: Self.sharpnessAmountPreferenceKey)
            }
            AppDiagnostics.record(.displaySettingsChanged)
            if settings.isSinglePageInPortraitEnabled != oldValue.isSinglePageInPortraitEnabled {
                preferences?.set(settings.isSinglePageInPortraitEnabled, forKey: Self.singlePageInPortraitPreferenceKey)
            }
            preserveDisplayedPageWhenLayoutChanges(from: oldValue)
            saveReadingSession()
        }
    }
    public var errorMessage: String?
    public var currentPageIndex: Int = 0 {
        didSet {
            readingPageIndex = displayedPageIndex(in: pageGroups)
            if currentPageIndex != oldValue {
                accessibilitySelectionRevision += 1
                tracePaging("changed", detail: "previousGroup=\(oldValue)")
                AppDiagnostics.record(
                    .pageChanged,
                    numericValue: currentPageIndex + 1,
                    numericLabel: .page
                )
            }
            saveReadingSession()
        }
    }
    public var searchQuery: String = "" { didSet { saveReadingSession() } }
    public var searchMatches: [PDFSearchMatch] = []
    public private(set) var isSearching = false
    private(set) var viewportLayout = PDFViewportLayout(
        size: CGSize(width: 1, height: 0),
        horizontalSizeClass: nil
    )

    public var isPortrait: Bool {
        viewportLayout.isPortrait
    }

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
    private static let sharpnessAmountPreferenceKey = "sharpnessAmount"
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
            let savedSharpnessAmount = preferences?.object(
                forKey: Self.sharpnessAmountPreferenceKey
            ) as? Double
            let legacySharpnessEnabled = preferences?.bool(forKey: Self.sharpnessPreferenceKey) ?? false
            self.settings = PDFViewerSettings(
                isHighQualityRenderingEnabled: preferences?.bool(forKey: Self.highQualityPreferenceKey) ?? false,
                isSharpnessEnabled: legacySharpnessEnabled,
                sharpnessAmount: savedSharpnessAmount,
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
        PDFPageGrouping.isSpreadEnabled(settings: settings, viewportLayout: viewportLayout)
    }

    public var pageGroups: [PageGroup] {
        makePageGroups(settings: settings, viewportLayout: viewportLayout)
    }

    /// A pager callback is only meaningful for the document and grouping that created it.
    struct PagerIdentity: Hashable {
        let documentID: UUID?
        let pages: [[Int]]
        let isRightToLeft: Bool
    }

    var pagerIdentity: PagerIdentity {
        PagerIdentity(
            documentID: document?.id,
            pages: pageGroups.map(\.pageIndices),
            isRightToLeft: settings.layoutDirection == .rightToLeft
        )
    }

    // Tab tags are PDF page identities, not positions in a reversed collection.
    subscript(pager identity: PagerIdentity) -> Int {
        get {
            let groups = pageGroups
            guard groups.indices.contains(currentPageIndex) else { return 0 }
            return groups[currentPageIndex].id
        }
        set {
            tracePaging("selection", detail: "requestedTag=\(newValue) validIdentity=\(identity == pagerIdentity)")
            guard identity == pagerIdentity,
                  let index = pageGroups.firstIndex(where: { $0.id == newValue }),
                  index != currentPageIndex else { return }
            currentPageIndex = index
        }
    }

    struct AccessibilityScrollRequest {
        let number: UInt64
        let pager: PagerIdentity
        let selectionRevision: UInt64
        let sourceGroupID: Int
        let edge: Edge
    }

    @ObservationIgnored private var accessibilityRequestNumber: UInt64 = 0
    @ObservationIgnored private var lastConsumedAccessibilityRequest: UInt64 = 0
    @ObservationIgnored private var accessibilitySelectionRevision: UInt64 = 0

    // This snapshot is made when the stable surface receives an action, never
    // captured by a page view. The number identifies a request, not a gesture.
    func makeAccessibilityScrollRequest(toward edge: Edge, pager identity: PagerIdentity) -> AccessibilityScrollRequest {
        accessibilityRequestNumber += 1
        return AccessibilityScrollRequest(
            number: accessibilityRequestNumber, pager: identity,
            selectionRevision: accessibilitySelectionRevision,
            sourceGroupID: self[pager: pagerIdentity], edge: edge
        )
    }

    func scrollAccessibilityPage(toward edge: Edge, pager identity: PagerIdentity) {
        applyAccessibilityScroll(makeAccessibilityScrollRequest(toward: edge, pager: identity))
    }

    @discardableResult
    func applyAccessibilityScroll(_ request: AccessibilityScrollRequest) -> Bool {
        let before = currentPageIndex
        var result = "rejected"
        tracePaging("scroll.begin", detail: "request=\(request.number) edge=\(request.edge) sourceTag=\(request.sourceGroupID) validIdentity=\(request.pager == pagerIdentity) revision=\(request.selectionRevision)")
        defer {
            tracePaging("scroll.end", detail: "request=\(request.number) result=\(result) beforeGroup=\(before) afterGroup=\(currentPageIndex)")
        }
        guard request.pager == pagerIdentity else {
            result = "stalePager"
            return false
        }
        guard request.number > lastConsumedAccessibilityRequest else {
            result = "duplicateOrSupersededRequest"
            return false
        }
        lastConsumedAccessibilityRequest = request.number
        guard request.selectionRevision == accessibilitySelectionRevision,
              request.sourceGroupID == self[pager: pagerIdentity] else {
            result = "staleSelection"
            return false
        }
        // The owner reported reversed physical-finger movement for BOTH bindings
        // on the fixed, unmirrored surface. Reverse the previous Edge policy only;
        // do not reintroduce the mirrored pager or page-captured source tags.
        // Logs establish Edge -> delta, not individual gesture -> Edge pairs.
        // This candidate still requires paired physical-gesture testing on SE.
        let step: Int
        switch request.edge {
        case .leading:
            step = request.pager.isRightToLeft ? -1 : 1
        case .trailing:
            step = request.pager.isRightToLeft ? 1 : -1
        case .top, .bottom:
            result = "unsupportedAxis"
            return false
        }
        let groups = pageGroups
        let destination = currentPageIndex + step
        guard groups.indices.contains(currentPageIndex),
              groups.indices.contains(destination) else {
            result = "boundary"
            return false
        }
        self[pager: request.pager] = groups[destination].id
        result = "moved"
        return true
    }

    #if DEBUG
    @ObservationIgnored private var pagingTraceSequence = 0
    private static let pagingLogger = Logger(
        subsystem: "com.takumayamada22.PDFViewer", category: "AccessibilityPaging"
    )
    #endif

    // Debug-only local unified logging: no document identifiers, paths or text.
    // Sequence numbers count log events, not gestures. Pair begin/end to count requests.
    private func tracePaging(_ event: String, detail: String = "") {
        #if DEBUG
        pagingTraceSequence += 1
        let pages = displayedPDFPageIndices.map { String($0 + 1) }.joined(separator: ",")
        Self.pagingLogger.notice("seq=\(self.pagingTraceSequence) event=\(event, privacy: .public) rtl=\(self.settings.layoutDirection == .rightToLeft) group=\(self.currentPageIndex) pdf=\(pages, privacy: .public) \(detail, privacy: .public)")
        #endif
    }

    var outline: [PDFOutlineNode] {
        document?.outline ?? []
    }

    struct AccessibilityFocusRequest: Equatable {
        let pager: PagerIdentity
        let viewport: PDFViewportLayout
        let pageNumber: Int?

        func reason(after previous: Self?) -> String {
            guard let previous else { return "surfaceMounted" }
            if pager.documentID != previous.pager.documentID { return "documentChanged" }
            if viewport != previous.viewport { return "viewportChanged" }
            if pager != previous.pager { return "groupingChanged" }
            return "pageChanged"
        }
    }

    var accessibilityFocusRequest: AccessibilityFocusRequest {
        AccessibilityFocusRequest(pager: pagerIdentity, viewport: viewportLayout,
                                  pageNumber: accessibilityFocusPageNumber)
    }

    @ObservationIgnored private(set) var accessibilityFocusEventGeneration = 0
    #if DEBUG
    @ObservationIgnored private(set) var accessibilityFocusObservation = PDFFocusObservation()
    @ObservationIgnored private(set) var lastIssuedAccessibilityFocusRequest: AccessibilityFocusRequest?
    @ObservationIgnored private(set) var accessibilityFocusRequestCount = 0
    #endif

    // Records an app request, never proof of OS focus or speech completion.
    func recordAccessibilityFocusRequest(_ request: AccessibilityFocusRequest, reason: String) {
        #if DEBUG
        accessibilityFocusObservation.begin(target: request.pageNumber)
        lastIssuedAccessibilityFocusRequest = request
        accessibilityFocusRequestCount += 1
        tracePaging("focus.request", detail: "focusRequest=\(accessibilityFocusRequestCount) targetPDF=\(request.pageNumber ?? 0) retainedPDF=\(accessibilityFocusPageNumber ?? 0) reason=\(reason)")
        #endif
    }

    func recordAccessibilityImageFocus(event: String, page: Int, posted: Bool = false, detail: String = "") {
        if event == "focus.elementFocused" {
            accessibilityFocusEventGeneration += 1
            #if DEBUG
            accessibilityFocusObservation.acquired(page)
            #endif
        }
        tracePaging(event, detail: "elementPDF=\(page) retainedPDF=\(accessibilityFocusPageNumber ?? 0) posted=\(posted) focusGeneration=\(accessibilityFocusEventGeneration) \(detail)")
        #if DEBUG
        if event == "focus.elementFocused", accessibilityFocusObservation.departedAfterTarget {
            tracePaging("focus.departureObserved", detail: "elementPDF=\(page) targetPDF=\(accessibilityFocusObservation.target ?? 0)")
        }
        #endif
    }

    var accessibilityFocusPageNumber: Int? {
        displayedPageIndex(in: pageGroups).map { $0 + 1 }
    }

    var displayedPDFPageIndices: [Int] {
        guard pageGroups.indices.contains(currentPageIndex) else { return [] }
        return pageGroups[currentPageIndex].pageIndices
    }

    func jumpToPDFPage(_ pageIndex: Int) {
        guard let document,
              (0..<document.totalPageCount).contains(pageIndex),
              let groupIndex = PDFPageGrouping.groupIndex(
                containing: pageIndex,
                in: pageGroups.map(\.pageIndices)
              ) else {
            return
        }
        readingPageIndex = pageIndex
        currentPageIndex = groupIndex
    }

    public func updateViewportSize(
        _ size: CGSize,
        horizontalSizeClass: UserInterfaceSizeClass? = nil
    ) {
        guard size.width > 0, size.height > 0 else { return }
        let newLayout = PDFViewportLayout(
            size: size,
            horizontalSizeClass: horizontalSizeClass
        )
        guard newLayout != viewportLayout else { return }
        accessibilitySelectionRevision += 1

        let oldGroups = pageGroups
        let displayedPageIndex = displayedPageIndex(in: oldGroups)
        viewportLayout = newLayout
        restoreDisplayedPage(displayedPageIndex, in: pageGroups)
    }

    private func makePageGroups(
        settings: PDFViewerSettings,
        viewportLayout: PDFViewportLayout
    ) -> [PageGroup] {
        guard let document else { return [] }
        return PDFPageGrouping.pageIndexGroups(
            totalPageCount: document.totalPageCount,
            settings: settings,
            viewportLayout: viewportLayout
        ).map { pageIndices in
            let startIndex = pageIndices.min() ?? 0
            return PageGroup(
                id: startIndex,
                pages: pageIndices.compactMap { document.pdfDocument.page(at: $0) },
                startIndex: startIndex,
                pageIndices: pageIndices
            )
        }
    }

    private func preserveDisplayedPageWhenLayoutChanges(from oldSettings: PDFViewerSettings) {
        let oldGroups = makePageGroups(settings: oldSettings, viewportLayout: viewportLayout)
        let displayedPageIndex = displayedPageIndex(in: oldGroups)
        restoreDisplayedPage(displayedPageIndex, in: pageGroups)
    }

    private func displayedPageIndex(in groups: [PageGroup]) -> Int? {
        guard groups.indices.contains(currentPageIndex) else { return nil }
        let group = groups[currentPageIndex]
        if let readingPageIndex, group.pageIndices.contains(readingPageIndex) {
            return readingPageIndex
        }
        return group.startIndex
    }

    private func restoreDisplayedPage(_ pageIndex: Int?, in groups: [PageGroup]) {
        guard let pageIndex,
              let groupIndex = PDFPageGrouping.groupIndex(
                containing: pageIndex,
                in: groups.map(\.pageIndices)
              ) else {
            if groups.isEmpty {
                currentPageIndex = 0
            } else if currentPageIndex >= groups.count {
                currentPageIndex = groups.count - 1
            }
            return
        }
        readingPageIndex = pageIndex
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
            self.readingPageIndex = nil
            self.jumpToPDFPage(0)
            self.searchQuery = ""
            self.searchMatches = []
            if let restored = pendingSession?.state {
                settings.isSpreadViewEnabled = restored.isSpread
                settings.isCoverPageEnabled = restored.isCover
                settings.layoutDirection = restored.isRightToLeft ? .rightToLeft : .leftToRight
                if let pdfPageIndex = restored.pdfPageIndex {
                    jumpToPDFPage(min(max(0, pdfPageIndex), max(0, loadedDocument.totalPageCount - 1)))
                } else {
                    // Older sessions stored only a page-group index.
                    currentPageIndex = min(max(0, restored.pageIndex), max(0, pageGroups.count - 1))
                }
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
            isRightToLeft: settings.layoutDirection == .rightToLeft,
            pdfPageIndex: displayedPageIndex(in: pageGroups)
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
        self.settings.sharpnessAmount = 0
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
            sharpnessAmount: self.settings.sharpnessAmount,
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
