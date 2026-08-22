//
// PDFViewerModelTests.swift
// MihirakiPDFViewerTests
//
// Copyright 2026 Takuma Yamada.
//
// This software is released under the MIT License.
//

import Foundation
import PDFKit
import SwiftUI
import UIKit
import XCTest
@testable import MihirakiPDFViewer

@MainActor
final class PDFDocumentWrapperTests: XCTestCase {
    func testLoadsValidPDFAndDefaultsToSinglePageLayout() throws {
        let url = try makeTemporaryPDF(pageCount: 2)

        let wrapper = try PDFDocumentWrapper(url: url)

        XCTAssertEqual(wrapper.totalPageCount, 2)
        XCTAssertEqual(wrapper.pageLayout, .singlePage)
        XCTAssertEqual(wrapper.layoutDirection, .leftToRight)
        XCTAssertFalse(wrapper.isSpreadViewEnabled)
        XCTAssertFalse(wrapper.isCoverPageEnabled)
    }

    func testThrowsForInvalidPDF() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        try Data("not a pdf".utf8).write(to: url)

        XCTAssertThrowsError(try PDFDocumentWrapper(url: url))
    }

    func testRecognizesPageLayoutAndDirectionFromBundledPDFs() throws {
        let cases: [(name: String, pageLayout: PDFPageLayout, direction: LayoutDirection)] = [
            ("L2R_Single", .singlePage, .leftToRight),
            ("L2R_OneColumn", .oneColumn, .leftToRight),
            ("L2R_TwoColumnLeft", .twoColumnLeft, .leftToRight),
            ("L2R_TwoColumnRight", .twoColumnRight, .leftToRight),
            ("L2R_TwoPageLeft", .twoPageLeft, .leftToRight),
            ("L2R_TwoPageRight", .twoPageRight, .leftToRight),
            ("R2L_Single", .singlePage, .rightToLeft),
            ("R2L_OneColumn", .oneColumn, .rightToLeft),
            ("R2L_TwoColumnLeft", .twoColumnLeft, .rightToLeft),
            ("R2L_TwoColumnRight", .twoColumnRight, .rightToLeft),
            ("R2L_TwoPageLeft", .twoPageLeft, .rightToLeft),
            ("R2L_TwoPageRight", .twoPageRight, .rightToLeft)
        ]

        for testCase in cases {
            try XCTContext.runActivity(named: testCase.name) { _ in
                let wrapper = try PDFDocumentWrapper(url: bundledPDFURL(named: testCase.name))

                XCTAssertEqual(wrapper.pageLayout, testCase.pageLayout)
                XCTAssertEqual(wrapper.layoutDirection, testCase.direction)
            }
        }
    }
}

@MainActor
final class TipManagerTests: XCTestCase {
    func testProductIDsMapToAppIconNames() {
        XCTAssertEqual(TipManager.appIconName(for: "tip_100"), "AppIconBronze")
        XCTAssertEqual(TipManager.appIconName(for: "tip_500"), "AppIconSilver")
        XCTAssertEqual(TipManager.appIconName(for: "tip_1000"), "AppIconGold")
    }

    func testUnknownProductIDMapsToPrimaryAppIcon() {
        XCTAssertEqual(TipManager.appIconName(for: "unknown_product"), "AppIcon")
    }
}

@MainActor
final class PDFViewerViewModelTests: XCTestCase {
    func testPageGroupsAreEmptyWithoutDocument() {
        let viewModel = PDFViewerViewModel()

        XCTAssertTrue(viewModel.pageGroups.isEmpty)
    }

    func testPageGroupsUseSinglePagesWhenSpreadViewIsDisabled() throws {
        let viewModel = PDFViewerViewModel()
        viewModel.document = try PDFDocumentWrapper(url: makeTemporaryPDF(pageCount: 3))
        viewModel.settings.isSpreadViewEnabled = false
        viewModel.settings.isCoverPageEnabled = false

        let groups = viewModel.pageGroups

        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups.map(\.pages.count), [1, 1, 1])
        XCTAssertEqual(groups.map(\.startIndex), [0, 1, 2])
    }

    func testPageGroupsPairPagesWhenSpreadViewIsEnabled() throws {
        let viewModel = PDFViewerViewModel()
        viewModel.document = try PDFDocumentWrapper(url: makeTemporaryPDF(pageCount: 3))
        viewModel.settings.isSpreadViewEnabled = true
        viewModel.settings.isCoverPageEnabled = false

        let groups = viewModel.pageGroups

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.map(\.pages.count), [2, 1])
        XCTAssertEqual(groups.map(\.startIndex), [0, 2])
    }

    func testPageGroupsKeepCoverPageSeparateWhenEnabled() throws {
        let viewModel = PDFViewerViewModel()
        viewModel.document = try PDFDocumentWrapper(url: makeTemporaryPDF(pageCount: 4))
        viewModel.settings.isSpreadViewEnabled = true
        viewModel.settings.isCoverPageEnabled = true

        let groups = viewModel.pageGroups

        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups.map(\.pages.count), [1, 2, 1])
        XCTAssertEqual(groups.map(\.startIndex), [0, 1, 3])
    }

    func testLoadDocumentUpdatesDocumentAndResetsCurrentPage() throws {
        let viewModel = PDFViewerViewModel()
        viewModel.currentPageIndex = 2

        viewModel.loadDocument(from: try makeTemporaryPDF(pageCount: 2))

        XCTAssertNotNil(viewModel.document)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.currentPageIndex, 0)
    }

    func testCloseDocumentClearsDocumentAndResetsCurrentPage() throws {
        let viewModel = PDFViewerViewModel()
        viewModel.document = try PDFDocumentWrapper(url: makeTemporaryPDF(pageCount: 1))
        viewModel.currentPageIndex = 1

        viewModel.closeDocument()

        XCTAssertNil(viewModel.document)
        XCTAssertEqual(viewModel.currentPageIndex, 0)
    }

    func testUpdateSettingsPreservesCoverPageSetting() {
        var settings = PDFViewerSettings()
        settings.coverPageSetting = .typeB
        let viewModel = PDFViewerViewModel(settings: settings)

        viewModel.updateSettings(
            isSpreadViewEnabled: true,
            isCoverPageEnabled: true,
            isSliderEnabled: true,
            layoutDirection: .rightToLeft
        )

        XCTAssertTrue(viewModel.settings.isSpreadViewEnabled)
        XCTAssertTrue(viewModel.settings.isCoverPageEnabled)
        XCTAssertTrue(viewModel.settings.isSliderEnabled)
        XCTAssertEqual(viewModel.settings.layoutDirection, .rightToLeft)
        XCTAssertEqual(viewModel.settings.coverPageSetting, .typeB)
    }

    func testTypeAPageGroupsForR2LCoverPDF() throws {
        let viewModel = try makeViewModelForBundledPDF(named: "R2L_Cover")

        XCTAssertEqual(viewModel.settings.coverPageSetting, .typeA)
        XCTAssertEqual(viewModel.settings.layoutDirection, .rightToLeft)
        XCTAssertTrue(viewModel.settings.isSpreadViewEnabled)
        XCTAssertTrue(viewModel.settings.isCoverPageEnabled)
        XCTAssertEqual(pageNumbers(in: viewModel), [[1], [3, 2], [4]])
    }

    func testTypeAPageGroupsForR2LNoCoverPDF() throws {
        let viewModel = try makeViewModelForBundledPDF(named: "R2L_NoCover")

        XCTAssertEqual(viewModel.settings.coverPageSetting, .typeA)
        XCTAssertEqual(viewModel.settings.layoutDirection, .rightToLeft)
        XCTAssertTrue(viewModel.settings.isSpreadViewEnabled)
        XCTAssertFalse(viewModel.settings.isCoverPageEnabled)
        XCTAssertEqual(pageNumbers(in: viewModel), [[2, 1], [4, 3]])
    }

    func testTypeAPageGroupsForL2RCoverPDF() throws {
        let viewModel = try makeViewModelForBundledPDF(named: "L2R_Cover")

        XCTAssertEqual(viewModel.settings.coverPageSetting, .typeA)
        XCTAssertEqual(viewModel.settings.layoutDirection, .leftToRight)
        XCTAssertTrue(viewModel.settings.isSpreadViewEnabled)
        XCTAssertTrue(viewModel.settings.isCoverPageEnabled)
        XCTAssertEqual(pageNumbers(in: viewModel), [[1], [2, 3], [4]])
    }

    func testTypeAPageGroupsForL2RNoCoverPDF() throws {
        let viewModel = try makeViewModelForBundledPDF(named: "L2R_NoCover")

        XCTAssertEqual(viewModel.settings.coverPageSetting, .typeA)
        XCTAssertEqual(viewModel.settings.layoutDirection, .leftToRight)
        XCTAssertTrue(viewModel.settings.isSpreadViewEnabled)
        XCTAssertFalse(viewModel.settings.isCoverPageEnabled)
        XCTAssertEqual(pageNumbers(in: viewModel), [[1, 2], [3, 4]])
    }

    func testEmptySearchClearsMatches() throws {
        let viewModel = PDFViewerViewModel()
        viewModel.document = try PDFDocumentWrapper(url: makeTemporaryPDF(pageCount: 1))
        viewModel.searchMatches = [
            PDFViewerViewModel.PDFSearchMatch(pageIndex: 0, rects: [.zero])
        ]

        viewModel.performSearch(query: "")

        XCTAssertTrue(viewModel.searchMatches.isEmpty)
    }

    func testSinglePageInSpreadScalesUsingVirtualDoubleWidth() {
        let targetSize = SpreadLayoutView.singlePageSizeInSpread(
            pageSize: CGSize(width: 200, height: 300),
            containerSize: CGSize(width: 300, height: 500)
        )

        XCTAssertEqual(targetSize.width, 150)
        XCTAssertEqual(targetSize.height, 225)
    }

    func testTrailingSinglePageBlankPositionFollowsLayoutDirection() {
        XCTAssertTrue(SpreadLayoutView.pageComesBeforeBlankPage(layoutDirection: .leftToRight))
        XCTAssertFalse(SpreadLayoutView.pageComesBeforeBlankPage(layoutDirection: .rightToLeft))
    }
}

@MainActor
private func makeViewModelForBundledPDF(named name: String) throws -> PDFViewerViewModel {
    let url = try bundledPDFURL(named: name)
    let viewModel = PDFViewerViewModel()
    viewModel.loadDocument(from: url)

    XCTAssertNotNil(viewModel.document)
    XCTAssertNil(viewModel.errorMessage)

    return viewModel
}

private func bundledPDFURL(named name: String) throws -> URL {
    let bundle = Bundle(for: PDFViewerViewModelTests.self)
    let url = bundle.url(forResource: name, withExtension: "pdf")
    return try XCTUnwrap(url, "\(name).pdf is not available in the test bundle.")
}

@MainActor
private func pageNumbers(in viewModel: PDFViewerViewModel) -> [[Int]] {
    viewModel.pageGroups.map { group in
        group.pageIndices.map { $0 + 1 }
    }
}

private func makeTemporaryPDF(pageCount: Int) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("pdf")
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 200))

    try renderer.writePDF(to: url) { context in
        for pageNumber in 1...pageCount {
            context.beginPage()
            let text = "Page \(pageNumber)"
            text.draw(
                at: CGPoint(x: 20, y: 20),
                withAttributes: [.font: UIFont.systemFont(ofSize: 18)]
            )
        }
    }

    return url
}
