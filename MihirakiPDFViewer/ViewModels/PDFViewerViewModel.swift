//
// PDFViewerViewModel.swift
// MihirakiPDFViewer
//
// Created by Takuma Yamada on 2026/08/14.
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
    @Published public var settings: PDFViewerSettings
    @Published public var errorMessage: String?
    @Published public var currentPageIndex: Int = 0
    @Published public var searchQuery: String = ""
    @Published public var searchMatches: [PDFSearchMatch] = []

    public struct PDFSearchMatch: Identifiable {
        public let id = UUID()
        public let pageIndex: Int
        public let rects: [CGRect]
    }

    private var securityScopedURL: URL?
    private var isAccessingResource = false

    public init(settings: PDFViewerSettings? = nil) {
        if let settings = settings {
            self.settings = settings
        } else {
            self.settings = PDFViewerSettings()
        }
    }

    /// 表示すべきページのグループ（1ページまたは2ページのペア）
    public struct PageGroup: Identifiable {
        public let id: Int
        public let pages: [PDFPage]
        public let startIndex: Int
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
                    groups.append(PageGroup(id: currentIndex, pages: [firstPage], startIndex: currentIndex))
                    currentIndex += 1
                }
            }
         }

         // 2. 見開き表示か単一表示かの判定
         if settings.isSpreadViewEnabled {
             // 見開き表示: 2ページずつペアにする
             while currentIndex < totalPages {
                 var pair: [PDFPage] = []
                 if let page = document.pdfDocument.page(at: currentIndex) {
                     pair.append(page)
                 }
                 
                 if currentIndex + 1 < totalPages, let nextPage = document.pdfDocument.page(at: currentIndex + 1) {
                     pair.append(nextPage)
                 }
                 
                 groups.append(PageGroup(id: currentIndex, pages: pair, startIndex: currentIndex))
                 currentIndex += 2
             }
         } else {
             // 単一表示
             while currentIndex < totalPages {
                 if let page = document.pdfDocument.page(at: currentIndex) {
                     groups.append(PageGroup(id: currentIndex, pages: [page], startIndex: currentIndex))
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
    public func loadDocument(from url: URL) {
        // 以前のアクセスを停止
        stopCurrentAccess()
        
        do {
            // セキュリティスコープへのアクセスを開始
            let accessing = url.startAccessingSecurityScopedResource()
            securityScopedURL = url
            isAccessingResource = accessing
            
            let loadedDocument = try PDFDocumentWrapper(url: url)
            self.document = loadedDocument
            // ドキュメントのメタデータに基づいて、表示設定を更新
            self.settings.layoutDirection = loadedDocument.layoutDirection
            self.settings.isSpreadViewEnabled = loadedDocument.isSpreadViewEnabled
            self.settings.isCoverPageEnabled = loadedDocument.isCoverPageEnabled
            self.currentPageIndex = 0
        } catch {
            stopCurrentAccess()
            self.document = nil
            self.errorMessage = error.localizedDescription
        }
    }

    private func stopCurrentAccess() {
        if let url = securityScopedURL, isAccessingResource {
            url.stopAccessingSecurityScopedResource()
            isAccessingResource = false
            securityScopedURL = nil
        }
    }

    /// 現在のドキュメントを閉じる
    public func closeDocument() {
        stopCurrentAccess()
        self.document = nil
        self.currentPageIndex = 0
    }

    /// 設定を変更する
    public func updateSettings(isSpreadViewEnabled: Bool, isCoverPageEnabled: Bool, isSliderEnabled: Bool, layoutDirection: LayoutDirection) {
        self.settings = PDFViewerSettings(
            isSpreadViewEnabled: isSpreadViewEnabled,
            isCoverPageEnabled: isCoverPageEnabled,
            isSliderEnabled: isSliderEnabled,
            layoutDirection: layoutDirection,
            coverPageSetting: self.settings.coverPageSetting
        )
    }
}
