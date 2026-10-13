//
// PDFPageGrouping.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import SwiftUI

/// Computes page groupings independently of PDFKit objects.
struct PDFPageGrouping {
    static func isSpreadEnabled(
        settings: PDFViewerSettings,
        isPortrait: Bool
    ) -> Bool {
        settings.isSpreadViewEnabled
            && !(isPortrait && settings.isSinglePageInPortraitEnabled)
    }

    static func pageIndexGroups(
        totalPageCount: Int,
        settings: PDFViewerSettings,
        isPortrait: Bool
    ) -> [[Int]] {
        guard totalPageCount > 0 else { return [] }

        var groups: [[Int]] = []
        var currentIndex = 0

        if settings.isCoverPageEnabled {
            groups.append([currentIndex])
            currentIndex += 1
        }

        if isSpreadEnabled(settings: settings, isPortrait: isPortrait) {
            while currentIndex < totalPageCount {
                var pageIndices = [currentIndex]
                if currentIndex + 1 < totalPageCount {
                    pageIndices.append(currentIndex + 1)
                }
                if settings.layoutDirection == .rightToLeft, pageIndices.count == 2 {
                    pageIndices.reverse()
                }
                groups.append(pageIndices)
                currentIndex += 2
            }
        } else {
            while currentIndex < totalPageCount {
                groups.append([currentIndex])
                currentIndex += 1
            }
        }

        return groups
    }

    static func groupIndex(containing pageIndex: Int, in groups: [[Int]]) -> Int? {
        groups.firstIndex { $0.contains(pageIndex) }
    }
}
