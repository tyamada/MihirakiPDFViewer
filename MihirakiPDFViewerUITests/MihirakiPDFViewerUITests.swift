//
//  MihirakiPDFViewerUITests.swift
//  MihirakiPDFViewerUITests
//
//  Created by 山田 琢磨 on 2026/08/21.
//

import XCTest

final class MihirakiPDFViewerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testEmptyStateScreen() throws {
        app.launch()

        XCTAssertTrue(element("emptyStateView").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["selectPDFButton"].exists)
        XCTAssertTrue(app.buttons["settingsButton"].exists)
    }

    @MainActor
    func testSettingsScreen() throws {
        app.launch()

        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 5))
        app.buttons["settingsButton"].tap()

        XCTAssertTrue(element("settingsScreen").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settingsCloseButton"].exists)
    }

    @MainActor
    func testTipSelectionScreen() throws {
        app.launch()

        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 5))
        app.buttons["settingsButton"].tap()

        XCTAssertTrue(element("settingsScreen").waitForExistence(timeout: 5))
        app.swipeUp()

        XCTAssertTrue(app.buttons["supportButton"].waitForExistence(timeout: 5))
        app.buttons["supportButton"].tap()

        XCTAssertTrue(element("tipSelectionScreen").waitForExistence(timeout: 5))
    }

    @MainActor
    func testPDFViewerScreen() throws {
        app.launchArguments.append("-uiTestLoadSamplePDF")
        app.launch()

        XCTAssertTrue(element("pdfViewerScreen").waitForExistence(timeout: 5))
        XCTAssertTrue(element("pageSlider").exists)
        XCTAssertTrue(element("pageIndicator").exists)
        XCTAssertTrue(app.buttons["settingsButton"].exists)
        XCTAssertTrue(app.buttons["closeDocumentButton"].exists)

        app.buttons["closeDocumentButton"].tap()

        XCTAssertTrue(element("emptyStateView").waitForExistence(timeout: 5))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
