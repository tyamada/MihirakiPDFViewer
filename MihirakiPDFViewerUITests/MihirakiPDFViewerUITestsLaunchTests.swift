//
//  MihirakiPDFViewerUITestsLaunchTests.swift
//  MihirakiPDFViewerUITests
//
//  Created by 山田 琢磨 on 2026/08/21.
//

import XCTest

final class MihirakiPDFViewerUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(ja)",
            "-AppleLocale", "ja_JP",
            "-uiTestResetReadingSession",
            "-uiTestResetRenderingPreferences"
        ]
        app.launch()

        XCTAssertTrue(app.buttons.firstMatch.waitForExistence(timeout: 5))
        try AppStoreScreenshotCapture.capture(
            named: "00-launch-ja",
            app: app,
            expectation: AppStoreScreenshotExpectation(
                requiredElementIdentifier: "emptyStateView",
                languageMarkers: ["PDFファイルを選択してください", "ファイルを選択"],
                allowsMostlyWhite: true
            ),
            testCase: self
        )
    }
}
