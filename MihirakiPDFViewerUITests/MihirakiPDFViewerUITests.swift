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
        app.launchArguments.append("-uiTestDisableAutoFilePicker")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testEmptyStateScreen() throws {
        app.launch()

        XCTAssertTrue(element("emptyStateView").waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(app.buttons.count, 2)
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsScreen() throws {
        app.launch()

        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 5))
        app.buttons["settingsButton"].tap()

        XCTAssertTrue(element("settingsScreen").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settingsCloseButton"].exists)
        XCTAssertTrue(app.buttons["helpButton"].waitForExistence(timeout: 5))

        app.buttons["helpButton"].tap()

        XCTAssertTrue(element("helpScreen").waitForExistence(timeout: 5))
        XCTAssertFalse(element("tipSelectionScreen").exists)
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

        let pdfViewer = element("pdfViewerScreen")
        XCTAssertTrue(pdfViewer.waitForExistence(timeout: 5))
        XCTAssertFalse(element("pageSlider").exists)
        XCTAssertFalse(element("pageIndicator").exists)
        XCTAssertFalse(app.buttons["settingsButton"].exists)
        XCTAssertFalse(app.buttons["closeDocumentButton"].exists)

        tapPDFViewer()

        XCTAssertTrue(element("pageSlider").waitForExistence(timeout: 5))
        XCTAssertTrue(element("pageIndicator").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["closeDocumentButton"].waitForExistence(timeout: 5))

        tapPDFViewer()

        XCTAssertFalse(element("pageSlider").waitForExistence(timeout: 1))
        XCTAssertFalse(element("pageIndicator").exists)
        XCTAssertFalse(app.buttons["settingsButton"].exists)
        XCTAssertFalse(app.buttons["closeDocumentButton"].exists)

        tapPDFViewer()
        XCTAssertTrue(app.buttons["closeDocumentButton"].waitForExistence(timeout: 5))
        app.buttons["closeDocumentButton"].tap()

        XCTAssertTrue(element("emptyStateView").waitForExistence(timeout: 5))
    }

    @MainActor
    func testAccessibilityAuditForPrimaryScreens() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 17,
            "XCTest accessibility audits require iOS 17 or later."
        )

        app.launchArguments.append("-uiTestLoadSamplePDF")
        app.launch()

        XCTAssertTrue(element("pdfViewerScreen").waitForExistence(timeout: 5))
        try performPrimaryAccessibilityAudit()

        tapPDFViewer()

        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 5))
        app.buttons["settingsButton"].tap()

        XCTAssertTrue(element("settingsScreen").waitForExistence(timeout: 5))
        try performPrimaryAccessibilityAudit(allowSwiftUIStaticTextContrastIssues: true)

        app.swipeUp()
        XCTAssertTrue(app.buttons["supportButton"].waitForExistence(timeout: 5))
        app.buttons["supportButton"].tap()

        XCTAssertTrue(element("tipSelectionScreen").waitForExistence(timeout: 5))
        try performPrimaryAccessibilityAudit(allowSwiftUIStaticTextContrastIssues: true)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func tapPDFViewer() {
        let pdfViewer = element("pdfViewerScreen")
        pdfViewer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func performPrimaryAccessibilityAudit(allowSwiftUIStaticTextContrastIssues: Bool = false) throws {
        try app.performAccessibilityAudit(for: accessibilityAuditTypesExcludingDynamicType) { issue in
            XCTContext.runActivity(named: "Accessibility issue: \(issue)") { _ in }

            guard allowSwiftUIStaticTextContrastIssues else {
                return false
            }

            let description = String(describing: issue)
            return description.contains("AuditType:\"1\"")
                && description.contains("SwiftUI.AccessibilityNode")
        }
    }

    private var accessibilityAuditTypesExcludingDynamicType: XCUIAccessibilityAuditType {
        var auditTypes = XCUIAccessibilityAuditType.all
        auditTypes.remove(.dynamicType)
        return auditTypes
    }

}
