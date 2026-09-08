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
            saveReadingSession()
        }
    }
    @Published public var errorMessage: String?
    @Published public var currentPageIndex: Int = 0 { didSet { saveReadingSession() } }
    @Published public var searchQuery: String = "" { didSet { saveReadingSession() } }
    @Published public var searchMatches: [PDFSearchMatch] = []

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
    private var documentBookmark: Data?
    private var pendingSession: (url: URL, state: ReadingSession)?
    private var isLoadingDocument = false

    public init(settings: PDFViewerSettings? = nil, sessionURL: URL? = nil, preferences: UserDefaults? = nil) {
        self.sessionURL = sessionURL
        self.preferences = preferences
        if let settings = settings {
            self.settings = settings
        } else {
            self.settings = PDFViewerSettings(
                isHighQualityRenderingEnabled: preferences?.bool(forKey: Self.highQualityPreferenceKey) ?? false,
                isSharpnessEnabled: preferences?.bool(forKey: Self.sharpnessPreferenceKey) ?? false
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

    public var pageGroups: [PageGroup] {
        guard let document = document else { return [] }
        let totalPages = document.totalPageCount
        var groups: [PageGroup] = []

        var currentIndex = 0

        // 1. 表紙の処理 (Cover Page)
        if settings.isCoverPageEnabled {
            if totalPages > 0 {
                if let firstPage = document.pdfDocument.page(at: 0) {
                    groups.append(PageGroup(id: currentIndex, pages: [firstPage], startIndex: currentIndex, pageIndices: [currentIndex]))
                    currentIndex += 1
                }
            }
         }

         // 2. 見開き表示か単一表示かの判定
         if settings.isSpreadViewEnabled {
             // 見開き表示: 2ページずつペアにする
             while currentIndex < totalPages {
                 var pageIndices = [currentIndex]
                 if currentIndex + 1 < totalPages {
                     pageIndices.append(currentIndex + 1)
                 }

                 if settings.layoutDirection == .rightToLeft, pageIndices.count == 2 {
                     pageIndices.reverse()
                 }

                 let pages = pageIndices.compactMap { document.pdfDocument.page(at: $0) }
                 groups.append(PageGroup(id: currentIndex, pages: pages, startIndex: currentIndex, pageIndices: pageIndices))
                 currentIndex += 2
             }
         } else {
             // 単一表示
             while currentIndex < totalPages {
                 if let page = document.pdfDocument.page(at: currentIndex) {
                     groups.append(PageGroup(id: currentIndex, pages: [page], startIndex: currentIndex, pageIndices: [currentIndex]))
                 }
                 currentIndex += 1
             }
         }

        return groups
    }

    public func performSearch(query: String) {
        guard let document = document, !query.isEmpty else {
            searchMatches = []
            return
        }

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
    }

    /// PDFドキュメントをロードする
    @discardableResult
    public func loadDocument(from url: URL, password: String? = nil) -> LoadDocumentResult {
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
            return .loaded
        } catch PDFDocumentWrapperError.passwordRequired {
            self.document = nil
            self.errorMessage = nil
            return .passwordRequired
        } catch PDFDocumentWrapperError.invalidPassword {
            self.document = nil
            self.errorMessage = nil
            return .invalidPassword
        } catch {
            clearReadingSession()
            stopCurrentAccess()
            self.document = nil
            let message = error.localizedDescription
            self.errorMessage = message
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
        clearReadingSession()
        stopCurrentAccess()
        self.document = nil
        self.currentPageIndex = 0
        self.searchQuery = ""
        self.searchMatches = []
    }

    /// アプリ設定を初期状態に戻す
    public func resetApplicationSettings() {
        self.settings.isSpreadViewEnabled = false
        self.settings.isCoverPageEnabled = false
        self.settings.coverPageSetting = .typeA
        self.settings.isHighQualityRenderingEnabled = false
        self.settings.isSharpnessEnabled = false
        closeDocument()
    }

    /// 設定を変更する
    public func updateSettings(isSpreadViewEnabled: Bool, isCoverPageEnabled: Bool, layoutDirection: LayoutDirection) {
        self.settings = PDFViewerSettings(
            isSpreadViewEnabled: isSpreadViewEnabled,
            isCoverPageEnabled: isCoverPageEnabled,
            layoutDirection: layoutDirection,
            coverPageSetting: self.settings.coverPageSetting,
            isHighQualityRenderingEnabled: self.settings.isHighQualityRenderingEnabled,
            isSharpnessEnabled: self.settings.isSharpnessEnabled
        )
    }
}
