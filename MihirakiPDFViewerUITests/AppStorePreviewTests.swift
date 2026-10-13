import XCTest

/// Deterministic interaction sequences intended for App Store Preview recording.
///
/// Start a Simulator screen recording before running one test, then trim the
/// launch/setup portion. The deliberate holds make clean edit points available.
final class AppStorePreviewTests: XCTestCase {
    private struct Localization {
        let code: String
        let locale: String
        let pdfFileName: String
        let searchTerm: String
        let settingsTitle: String
        let spreadLabel: String
        let rightToLeftLabel: String

        static let japanese = Localization(
            code: "ja",
            locale: "ja_JP",
            pdfFileName: "tameshibu_episode1_2_ja",
            searchTerm: "ためし部",
            settingsTitle: "設定",
            spreadLabel: "見開き表示",
            rightToLeftLabel: "右から左 (R2L)"
        )

        static let english = Localization(
            code: "en",
            locale: "en_US",
            pdfFileName: "tameshibu_episode1_2_en",
            searchTerm: "THE TRY-IT CLUB",
            settingsTitle: "Settings",
            spreadLabel: "Two-page View",
            rightToLeftLabel: "Right to Left (R2L)"
        )
    }

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
        app?.terminate()
        app = nil
    }

    @MainActor
    func testJapaneseReaderPreview() throws {
        try recordReaderSequence(for: .japanese)
    }

    @MainActor
    func testEnglishReaderPreview() throws {
        try recordReaderSequence(for: .english)
    }

    @MainActor
    func testJapaneseSpreadPreview() throws {
        try recordSpreadSequence(for: .japanese)
    }

    @MainActor
    func testEnglishSpreadPreview() throws {
        try recordSpreadSequence(for: .english)
    }

    @MainActor
    func testJapaneseIPadAdaptiveLayoutPreview() throws {
        try recordIPadAdaptiveLayoutSequence(for: .japanese)
    }

    @MainActor
    func testEnglishIPadAdaptiveLayoutPreview() throws {
        try recordIPadAdaptiveLayoutSequence(for: .english)
    }

    @MainActor
    private func recordReaderSequence(for localization: Localization) throws {
        XCUIDevice.shared.orientation = .portrait
        try launch(localization)

        // Opening hero shot and clean edit point.
        hold(for: 3)
        viewer.swipeLeft()
        hold(for: 2)

        showViewerControls()
        let slider = app.sliders["pageSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.62)
        hold(for: 2)

        let searchField = app.textFields["searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText(localization.searchTerm)
        searchField.typeText(XCUIKeyboardKey.return.rawValue)
        hold(for: 4)

        hideViewerControls()
        hold(for: 3)
    }

    @MainActor
    private func recordSpreadSequence(for localization: Localization) throws {
        XCUIDevice.shared.orientation = .portrait
        try launch(localization)

        showViewerControls()
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(element("settingsScreen").waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars[localization.settingsTitle].waitForExistence(timeout: 5))
        enableSwitch(label: localization.spreadLabel)
        app.buttons[localization.rightToLeftLabel].tap()
        app.buttons["settingsCloseButton"].tap()

        rotate(to: .landscapeLeft)
        hideViewerControls()

        // Trim the setup before this clean hero shot.
        hold(for: 4)
        viewer.swipeRight()
        hold(for: 3)
        viewer.swipeRight()
        hold(for: 3)

        showViewerControls()
        let slider = app.sliders["pageSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.55)
        hold(for: 2)
        hideViewerControls()
        hold(for: 3)
    }

    @MainActor
    private func recordIPadAdaptiveLayoutSequence(for localization: Localization) throws {
        XCUIDevice.shared.orientation = .portrait
        try launch(localization)

        // The new default: one full-size page whenever the viewport is portrait.
        hideViewerControls()
        hold(for: 4)
        viewer.swipeLeft()
        hold(for: 3)

        showViewerControls()
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(element("settingsScreen").waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars[localization.settingsTitle].waitForExistence(timeout: 5))

        let portraitToggle = app.switches["singlePageInPortraitToggle"]
        XCTAssertTrue(portraitToggle.waitForExistence(timeout: 5))
        if portraitToggle.value as? String != "0" {
            portraitToggle.tap()
        }
        XCTAssertEqual(portraitToggle.value as? String, "0")
        hold(for: 2)

        app.buttons["settingsCloseButton"].tap()
        XCTAssertTrue(viewer.waitForExistence(timeout: 5))
        hideViewerControls()

        // With the option disabled, spread view remains active in portrait.
        hold(for: 5)
        viewer.swipeRight()
        hold(for: 3)
    }

    @MainActor
    private func launch(_ localization: Localization) throws {
        let pdfURL = try previewPDFURL(named: localization.pdfFileName)
        app.launchArguments = [
            "-AppleLanguages", "(\(localization.code))",
            "-AppleLocale", localization.locale,
            "-uiTestResetReadingSession",
            "-uiTestResetRenderingPreferences",
            "-uiTestPDFPath", pdfURL.path
        ]
        app.launch()
        XCTAssertTrue(viewer.waitForExistence(timeout: 15))
        hold(for: 2)
    }

    private func previewPDFURL(named fileName: String) throws -> URL {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = projectRoot
            .appendingPathComponent("testdata", isDirectory: true)
            .appendingPathComponent(fileName)
            .appendingPathExtension("pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        return url
    }

    @MainActor
    private func enableSwitch(label: String) {
        let toggle = app.switches[label]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if toggle.value as? String != "1" {
            toggle.tap()
        }
        XCTAssertEqual(toggle.value as? String, "1")
    }

    @MainActor
    private func showViewerControls() {
        if !app.buttons["settingsButton"].exists {
            viewer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func hideViewerControls() {
        if app.buttons["settingsButton"].exists {
            viewer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertFalse(app.buttons["settingsButton"].waitForExistence(timeout: 2))
    }

    @MainActor
    private func rotate(to orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        let predicate = NSPredicate { [self] _, _ in
            let frame = app.windows.firstMatch.frame
            return frame.width > frame.height
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
        hold(for: 2)
    }

    private func hold(for seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private var viewer: XCUIElement {
        element("pdfViewerScreen")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
