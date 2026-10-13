//
// PDFPageGroupingTests.swift
// MihirakiPDFViewerTests
//
// Copyright 2026 Takuma Yamada.
//

import SwiftUI
import Testing
@testable import MihirakiPDFViewer

struct PDFPageGroupingTests {
    @Test
    func emptyDocumentProducesNoGroups() {
        #expect(groups(pageCount: 0) == [])
    }

    @Test
    func spreadGroupsPagesInReadingOrder() {
        #expect(groups(pageCount: 5, spread: true) == [[0, 1], [2, 3], [4]])
        #expect(
            groups(pageCount: 5, spread: true, direction: .rightToLeft)
                == [[1, 0], [3, 2], [4]]
        )
    }

    @Test
    func coverRemainsSeparateFromFollowingSpread() {
        #expect(groups(pageCount: 4, spread: true, cover: true) == [[0], [1, 2], [3]])
    }

    @Test
    func portraitPreferenceTemporarilyDisablesSpread() {
        #expect(
            groups(
                pageCount: 4,
                spread: true,
                singlePageInPortrait: true,
                isPortrait: true
            ) == [[0], [1], [2], [3]]
        )
        #expect(
            groups(
                pageCount: 4,
                spread: true,
                singlePageInPortrait: true,
                isPortrait: false
            ) == [[0, 1], [2, 3]]
        )
    }

    @Test
    func regularWidthPortraitCanUseSpread() {
        #expect(
            groups(
                pageCount: 4,
                spread: true,
                singlePageInPortrait: true,
                isPortrait: true,
                horizontalSizeClass: .regular
            ) == [[0, 1], [2, 3]]
        )
    }

    @Test
    func locatesGroupContainingDisplayedPage() {
        let groups = [[0], [2, 1], [4, 3]]

        #expect(PDFPageGrouping.groupIndex(containing: 3, in: groups) == 2)
        #expect(PDFPageGrouping.groupIndex(containing: 9, in: groups) == nil)
    }

    private func groups(
        pageCount: Int,
        spread: Bool = false,
        cover: Bool = false,
        direction: LayoutDirection = .leftToRight,
        singlePageInPortrait: Bool = false,
        isPortrait: Bool = false,
        horizontalSizeClass: UserInterfaceSizeClass? = nil
    ) -> [[Int]] {
        PDFPageGrouping.pageIndexGroups(
            totalPageCount: pageCount,
            settings: PDFViewerSettings(
                isSpreadViewEnabled: spread,
                isCoverPageEnabled: cover,
                layoutDirection: direction,
                isSinglePageInPortraitEnabled: singlePageInPortrait
            ),
            viewportLayout: PDFViewportLayout(
                size: isPortrait
                    ? CGSize(width: 600, height: 800)
                    : CGSize(width: 800, height: 600),
                horizontalSizeClass: horizontalSizeClass
            )
        )
    }
}
