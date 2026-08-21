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

    func testEmptySearchClearsMatches() throws {
        let viewModel = PDFViewerViewModel()
        viewModel.document = try PDFDocumentWrapper(url: makeTemporaryPDF(pageCount: 1))
        viewModel.searchMatches = [
            PDFViewerViewModel.PDFSearchMatch(pageIndex: 0, rects: [.zero])
        ]

        viewModel.performSearch(query: "")

        XCTAssertTrue(viewModel.searchMatches.isEmpty)
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
