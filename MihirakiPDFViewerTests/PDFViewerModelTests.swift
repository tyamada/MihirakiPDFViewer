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

    func testExtractsDocumentMetadata() throws {
        let url = try makeTemporaryPDF(
            pageCount: 1,
            documentInfo: [
                kCGPDFContextTitle as String: "Sample Title",
                kCGPDFContextAuthor as String: "Sample Author",
                kCGPDFContextSubject as String: "Sample Subtitle",
                kCGPDFContextKeywords as String: "sample, pdf"
            ]
        )

        let wrapper = try PDFDocumentWrapper(url: url)

        XCTAssertEqual(wrapper.title, "Sample Title")
        XCTAssertEqual(wrapper.author, "Sample Author")
        XCTAssertEqual(wrapper.subtitle, "Sample Subtitle")
        XCTAssertEqual(wrapper.keywords, "sample, pdf")
        XCTAssertNotNil(wrapper.pdfVersion)
    }

    func testPasswordProtectedPDFRequiresPasswordAndLoadsWithCorrectPassword() throws {
        let url = try makePasswordProtectedPDF(password: "secret")

        XCTAssertThrowsError(try PDFDocumentWrapper(url: url)) { error in
            XCTAssertEqual(error as? PDFDocumentWrapperError, .passwordRequired)
        }
        XCTAssertThrowsError(try PDFDocumentWrapper(url: url, password: "wrong")) { error in
            XCTAssertEqual(error as? PDFDocumentWrapperError, .invalidPassword)
        }

        let wrapper = try PDFDocumentWrapper(url: url, password: "secret")

        XCTAssertEqual(wrapper.totalPageCount, 1)
        XCTAssertFalse(wrapper.pdfDocument.isLocked)

        let viewModel = PDFViewerViewModel()
        XCTAssertEqual(viewModel.loadDocument(from: url), .passwordRequired)
        XCTAssertEqual(viewModel.loadDocument(from: url, password: "wrong"), .invalidPassword)
        XCTAssertEqual(viewModel.loadDocument(from: url, password: "secret"), .loaded)
        XCTAssertNotNil(viewModel.document)
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
    func testRenderingPreferencesPersistWithoutPDFAndAfterClosingPDF() throws {
        let suiteName = "RenderingPreferences-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let model = PDFViewerViewModel(preferences: preferences)
        XCTAssertFalse(model.settings.isHighQualityRenderingEnabled)
        XCTAssertFalse(model.settings.isSharpnessEnabled)
        model.settings.isHighQualityRenderingEnabled = true
        model.settings.isSharpnessEnabled = true

        let restored = PDFViewerViewModel(preferences: preferences)
        XCTAssertTrue(restored.settings.isHighQualityRenderingEnabled)
        XCTAssertTrue(restored.settings.isSharpnessEnabled)
        XCTAssertEqual(restored.loadDocument(from: try makeTemporaryPDF(pageCount: 3)), .loaded)
        restored.closeDocument()
        let afterClose = PDFViewerViewModel(preferences: preferences)
        XCTAssertTrue(afterClose.settings.isHighQualityRenderingEnabled)
        XCTAssertTrue(afterClose.settings.isSharpnessEnabled)

        afterClose.settings.isHighQualityRenderingEnabled = false
        let afterDisablingOne = PDFViewerViewModel(preferences: preferences)
        XCTAssertFalse(afterDisablingOne.settings.isHighQualityRenderingEnabled)
        XCTAssertTrue(afterDisablingOne.settings.isSharpnessEnabled)
        afterDisablingOne.settings.isSharpnessEnabled = false
        XCTAssertFalse(PDFViewerViewModel(preferences: preferences).settings.isSharpnessEnabled)
    }

    func testResetApplicationSettingsPersistsRenderingDefaults() throws {
        let suiteName = "RenderingPreferences-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let model = PDFViewerViewModel(preferences: preferences)
        model.settings.isHighQualityRenderingEnabled = true
        model.settings.isSharpnessEnabled = true
        model.resetApplicationSettings()
        let restored = PDFViewerViewModel(preferences: preferences)
        XCTAssertFalse(restored.settings.isHighQualityRenderingEnabled)
        XCTAssertFalse(restored.settings.isSharpnessEnabled)
    }

    func testReadingSessionRestoresPDFPageLayoutAndQuery() throws {
        let sessionURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: sessionURL) }
        let pdfURL = try makeTemporaryPDF(pageCount: 8)
        let original = PDFViewerViewModel(sessionURL: sessionURL)
        XCTAssertEqual(original.loadDocument(from: pdfURL), .loaded)
        original.updateSettings(isSpreadViewEnabled: true, isCoverPageEnabled: true, layoutDirection: .rightToLeft)
        original.currentPageIndex = 2
        original.searchQuery = "Page"

        let restored = PDFViewerViewModel(sessionURL: sessionURL)
        let url = try XCTUnwrap(restored.documentURLForRestoration())
        XCTAssertEqual(restored.loadDocument(from: url), .loaded)
        XCTAssertEqual(restored.document?.totalPageCount, 8)
        XCTAssertEqual(restored.currentPageIndex, 2)
        XCTAssertTrue(restored.settings.isSpreadViewEnabled)
        XCTAssertTrue(restored.settings.isCoverPageEnabled)
        XCTAssertEqual(restored.settings.layoutDirection, .rightToLeft)
        XCTAssertEqual(restored.searchQuery, "Page")
    }

    func testClosingDocumentClearsReadingSession() throws {
        let sessionURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: sessionURL) }
        let model = PDFViewerViewModel(sessionURL: sessionURL)
        XCTAssertEqual(model.loadDocument(from: try makeTemporaryPDF(pageCount: 3)), .loaded)
        model.currentPageIndex = 1
        model.closeDocument()
        XCTAssertNil(PDFViewerViewModel(sessionURL: sessionURL).documentURLForRestoration())
    }

    func testProtectedReadingSessionRestoresAfterPasswordRetry() throws {
        let sessionURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: sessionURL) }
        let pdfURL = try makePasswordProtectedPDF(password: "1234", pageCount: 4)
        let model = PDFViewerViewModel(sessionURL: sessionURL)
        XCTAssertEqual(model.loadDocument(from: pdfURL, password: "1234"), .loaded)
        model.currentPageIndex = 2
        model.searchQuery = "resume"

        let restored = PDFViewerViewModel(sessionURL: sessionURL)
        let url = try XCTUnwrap(restored.documentURLForRestoration())
        XCTAssertEqual(restored.loadDocument(from: url), .passwordRequired)
        XCTAssertEqual(restored.loadDocument(from: url, password: "0000"), .invalidPassword)
        XCTAssertEqual(restored.loadDocument(from: url, password: "1234"), .loaded)
        XCTAssertEqual(restored.searchQuery, "resume")
        XCTAssertEqual(restored.currentPageIndex, 2)
    }

    func testDeletedPDFDoesNotLeaveRepeatedRestorationAttempt() throws {
        let sessionURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: sessionURL) }
        let pdfURL = try makeTemporaryPDF(pageCount: 3)
        let model = PDFViewerViewModel(sessionURL: sessionURL)
        XCTAssertEqual(model.loadDocument(from: pdfURL), .loaded)
        try FileManager.default.removeItem(at: pdfURL)

        let restored = PDFViewerViewModel(sessionURL: sessionURL)
        if let url = restored.documentURLForRestoration() {
            guard case .failed = restored.loadDocument(from: url) else {
                return XCTFail("A missing PDF must not restore")
            }
        }
        XCTAssertNil(restored.document)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sessionURL.path))
    }

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
            layoutDirection: .rightToLeft
        )

        XCTAssertTrue(viewModel.settings.isSpreadViewEnabled)
        XCTAssertTrue(viewModel.settings.isCoverPageEnabled)
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

    func testSearchLoadTestPDFsFindExpectedHitCounts() throws {
        let cases: [(fileName: String, terms: [(query: String, count: Int)])] = [
            (
                "search_test_600_hits",
                [
                    ("負荷テスト", 600),
                    ("LOADTEST600", 600),
                    ("性能検証", 300),
                    ("応答速度", 100)
                ]
            ),
            (
                "search_test_600_hits_en",
                [
                    ("Load Testing", 600),
                    ("LOADTEST600", 600),
                    ("Performance Check", 300),
                    ("Response Time", 100)
                ]
            )
        ]

        for testCase in cases {
            let document = try XCTUnwrap(PDFDocument(url: searchLoadTestURL(fileName: testCase.fileName)))

            for term in testCase.terms {
                let selections = document.findString(term.query, withOptions: .caseInsensitive)
                XCTAssertEqual(selections.count, term.count, "\(term.query) in \(testCase.fileName).pdf")
            }
        }
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

private func searchLoadTestURL(fileName: String) -> URL {
    projectRootURL()
        .appendingPathComponent("testdata")
        .appendingPathComponent(fileName)
        .appendingPathExtension("pdf")
}

private func projectRootURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

@MainActor
private func pageNumbers(in viewModel: PDFViewerViewModel) -> [[Int]] {
    viewModel.pageGroups.map { group in
        group.pageIndices.map { $0 + 1 }
    }
}

private func makePasswordProtectedPDF(password: String, pageCount: Int = 1) throws -> URL {
    let sourceURL = try makeTemporaryPDF(pageCount: pageCount)
    let encryptedURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("pdf")
    let document = try XCTUnwrap(PDFDocument(url: sourceURL))

    let didWrite = document.write(
        to: encryptedURL,
        withOptions: [
            PDFDocumentWriteOption.userPasswordOption: password,
            PDFDocumentWriteOption.ownerPasswordOption: "owner-\(password)"
        ]
    )
    XCTAssertTrue(didWrite)

    return encryptedURL
}

private func makeTemporaryPDF(pageCount: Int, documentInfo: [String: Any]? = nil) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("pdf")
    let format = UIGraphicsPDFRendererFormat()
    if let documentInfo {
        format.documentInfo = documentInfo
    }
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 200), format: format)

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
