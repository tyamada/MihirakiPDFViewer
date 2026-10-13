import PDFKit
import XCTest

final class AppStoreScreenshotTests: XCTestCase {
    private struct Localization {
        let code: String
        let locale: String
        let pdfFileName: String
        let pdfMarker: String
        let searchTerm: String
        let settingsTitle: String
        let closeLabel: String
        let spreadLabels: [String]
        let rightToLeftLabels: [String]

        static let japanese = Localization(
            code: "ja",
            locale: "ja_JP",
            pdfFileName: "tameshibu_episode1_2_ja",
            pdfMarker: "ためし部",
            searchTerm: "ためし部",
            settingsTitle: "設定",
            closeLabel: "閉じる",
            spreadLabels: ["見開き表示"],
            rightToLeftLabels: ["右から左 (R2L)"]
        )

        static let english = Localization(
            code: "en",
            locale: "en_US",
            pdfFileName: "tameshibu_episode1_2_en",
            pdfMarker: "THE TRY-IT CLUB",
            searchTerm: "THE TRY-IT CLUB",
            settingsTitle: "Settings",
            closeLabel: "Close",
            spreadLabels: ["Two-page View"],
            rightToLeftLabels: ["Right to Left (R2L)"]
        )

        static let korean = Localization(
            code: "ko",
            locale: "ko_KR",
            pdfFileName: "tameshibu_episode1_2_ko",
            pdfMarker: "해봄부",
            searchTerm: "해봄부",
            settingsTitle: "설정",
            closeLabel: "닫기",
            spreadLabels: ["두 페이지 보기"],
            rightToLeftLabels: ["오른쪽에서 왼쪽 (R2L)"]
        )

        static let simplifiedChinese = Localization(
            code: "zh-Hans",
            locale: "zh_CN",
            pdfFileName: "tameshibu_episode1_2_zh_cn",
            pdfMarker: "试试社",
            searchTerm: "试试社",
            settingsTitle: "设置",
            closeLabel: "关闭",
            spreadLabels: ["双页视图"],
            rightToLeftLabels: ["从右到左 (R2L)"]
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
    func testCaptureJapaneseAppStoreScreenshots() throws {
        try captureScreenshots(for: .japanese)
    }

    @MainActor
    func testCaptureEnglishAppStoreScreenshots() throws {
        try captureScreenshots(for: .english)
    }

    @MainActor
    func testCaptureKoreanAppStoreScreenshots() throws {
        try captureScreenshots(for: .korean)
    }

    @MainActor
    func testCaptureSimplifiedChineseAppStoreScreenshots() throws {
        try captureScreenshots(for: .simplifiedChinese)
    }

    @MainActor
    private func captureScreenshots(for localization: Localization) throws {
        let pdfURL = try screenshotPDFURL(named: localization.pdfFileName)
        try validatePDF(pdfURL, contains: localization.pdfMarker)

        XCUIDevice.shared.orientation = primaryScreenshotOrientation
        app.launchArguments = [
            "-AppleLanguages", "(\(localization.code))",
            "-AppleLocale", localization.locale,
            "-uiTestResetReadingSession",
            "-uiTestResetRenderingPreferences",
            "-uiTestPDFPath", pdfURL.path
        ]
        app.launch()

        XCTAssertTrue(element("pdfViewerScreen").waitForExistence(timeout: 15))
        rotate(to: primaryScreenshotOrientation)

        if firstPDFPageIsBlank(at: pdfURL) {
            showViewerControls()
            let slider = app.sliders["pageSlider"]
            XCTAssertTrue(slider.waitForExistence(timeout: 5))
            slider.adjust(toNormalizedSliderPosition: 0.2)
            hideViewerControls()
            waitForRendering()
        }

        if UIDevice.current.userInterfaceIdiom == .pad {
            try captureIPadScreenshots(for: localization)
            return
        }

        try capture(
            number: 1,
            slug: "reader",
            localization: localization,
            orientation: primaryScreenshotOrientation,
            requiredElement: "pdfViewerScreen",
            languageMarkers: []
        )

        showViewerControls()
        openSettings(localization)
        setToggle(labels: localization.spreadLabels, enabled: true)
        closeSettings()
        rotate(to: .landscapeLeft)
        showViewerControls()
        app.sliders["pageSlider"].adjust(toNormalizedSliderPosition: 0.3)
        hideViewerControls()
        waitForRendering()

        try capture(
            number: 2,
            slug: "spread",
            localization: localization,
            orientation: .landscapeLeft,
            requiredElement: "pdfViewerScreen",
            languageMarkers: []
        )

        showViewerControls()
        openSettings(localization)
        tapButton(labels: localization.rightToLeftLabels)
        closeSettings()
        hideViewerControls()
        waitForRendering()

        try capture(
            number: 3,
            slug: "right-to-left",
            localization: localization,
            orientation: .landscapeLeft,
            requiredElement: "pdfViewerScreen",
            languageMarkers: []
        )

        rotate(to: primaryScreenshotOrientation)
        showViewerControls()
        let searchField = app.textFields["searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText(localization.searchTerm)
        dismissKeyboard()
        waitForRendering()

        try capture(
            number: 4,
            slug: "search",
            localization: localization,
            orientation: primaryScreenshotOrientation,
            requiredElement: "searchField",
            languageMarkers: [localization.closeLabel]
        )

        searchField.tap()
        searchField.typeText(
            String(repeating: XCUIKeyboardKey.delete.rawValue, count: localization.searchTerm.count)
        )
        dismissKeyboard()
        let slider = app.sliders["pageSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.7)
        waitForRendering()

        try capture(
            number: 5,
            slug: "page-navigation",
            localization: localization,
            orientation: primaryScreenshotOrientation,
            requiredElement: "pageIndicator",
            languageMarkers: [localization.closeLabel]
        )

        app.buttons["settingsButton"].tap()
        XCTAssertTrue(element("settingsScreen").waitForExistence(timeout: 5))

        try capture(
            number: 6,
            slug: "settings",
            localization: localization,
            orientation: primaryScreenshotOrientation,
            requiredElement: "settingsScreen",
            languageMarkers: [localization.settingsTitle]
        )
    }

    @MainActor
    private func captureIPadScreenshots(for localization: Localization) throws {
        let orientation = UIDeviceOrientation.landscapeLeft

        // Lead with the iPad's primary experience: a clean, full-screen two-page spread.
        showViewerControls()
        openSettings(localization)
        setToggle(labels: localization.spreadLabels, enabled: true)
        closeSettings()

        showViewerControls()
        let slider = app.sliders["pageSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.3)
        hideViewerControls()
        waitForRendering()

        try capture(
            number: 1,
            slug: "spread-reader",
            localization: localization,
            orientation: orientation,
            requiredElement: "pdfViewerScreen",
            languageMarkers: []
        )

        // Show that the reading controls are available without leaving the document.
        showViewerControls()
        try capture(
            number: 2,
            slug: "reader-controls",
            localization: localization,
            orientation: orientation,
            requiredElement: "searchField",
            languageMarkers: [localization.closeLabel]
        )

        let searchField = app.textFields["searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText(localization.searchTerm)
        dismissKeyboard()
        waitForRendering()

        try capture(
            number: 3,
            slug: "search",
            localization: localization,
            orientation: orientation,
            requiredElement: "searchField",
            languageMarkers: [localization.closeLabel]
        )

        searchField.tap()
        searchField.typeText(
            String(repeating: XCUIKeyboardKey.delete.rawValue, count: localization.searchTerm.count)
        )
        dismissKeyboard()
        slider.adjust(toNormalizedSliderPosition: 0.7)
        waitForRendering()

        try capture(
            number: 4,
            slug: "page-navigation",
            localization: localization,
            orientation: orientation,
            requiredElement: "pageIndicator",
            languageMarkers: [localization.closeLabel]
        )

        openSettings(localization)
        tapButton(labels: localization.rightToLeftLabels)
        closeSettings()
        hideViewerControls()
        waitForRendering()

        try capture(
            number: 5,
            slug: "right-to-left",
            localization: localization,
            orientation: orientation,
            requiredElement: "pdfViewerScreen",
            languageMarkers: []
        )

        showViewerControls()
        openSettings(localization)
        try capture(
            number: 6,
            slug: "settings",
            localization: localization,
            orientation: orientation,
            requiredElement: "settingsScreen",
            languageMarkers: [localization.settingsTitle]
        )
    }

    @MainActor
    private func capture(
        number: Int,
        slug: String,
        localization: Localization,
        orientation: UIDeviceOrientation,
        requiredElement: String,
        languageMarkers: [String]
    ) throws {
        let name = String(
            format: "%@-%@-%02d-%@",
            localization.code,
            deviceName,
            number,
            slug
        )
        try AppStoreScreenshotCapture.capture(
            named: name,
            app: app,
            expectation: AppStoreScreenshotExpectation(
                requiredElementIdentifier: requiredElement,
                languageMarkers: languageMarkers,
                allowedPixelSizes: [expectedPixelSize(for: orientation)]
            ),
            testCase: self
        )
    }

    private var deviceName: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPadPro13M5" : "iPhone18Pro"
    }

    private var primaryScreenshotOrientation: UIDeviceOrientation {
        UIDevice.current.userInterfaceIdiom == .pad ? .landscapeLeft : .portrait
    }

    private func expectedPixelSize(for orientation: UIDeviceOrientation) -> CGSize {
        let isLandscape = orientation == .landscapeLeft || orientation == .landscapeRight
        if UIDevice.current.userInterfaceIdiom == .pad {
            return isLandscape
                ? CGSize(width: 2752, height: 2064)
                : CGSize(width: 2064, height: 2752)
        }
        return isLandscape
            ? CGSize(width: 2622, height: 1206)
            : CGSize(width: 1206, height: 2622)
    }

    private func screenshotPDFURL(named fileName: String) throws -> URL {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = projectRoot
            .appendingPathComponent("testdata")
            .appendingPathComponent(fileName)
            .appendingPathExtension("pdf")

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path),
            "Missing App Store screenshot material: \(url.path)"
        )
        return url
    }

    private func firstPDFPageIsBlank(at url: URL) -> Bool {
        guard let firstPageText = PDFDocument(url: url)?.page(at: 0)?.string else {
            return true
        }
        return firstPageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func validatePDF(_ url: URL, contains marker: String) throws {
        let document = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertEqual(document.pageCount, 8)
        XCTAssertFalse(
            document.findString(marker, withOptions: .caseInsensitive).isEmpty,
            "The PDF does not contain the expected language marker “\(marker)”."
        )
    }

    @MainActor
    private func openSettings(_ localization: Localization) {
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 5))
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(element("settingsScreen").waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.navigationBars[localization.settingsTitle].waitForExistence(timeout: 5),
            "The settings title does not match the requested language."
        )
    }

    @MainActor
    private func closeSettings() {
        XCTAssertTrue(app.buttons["settingsCloseButton"].waitForExistence(timeout: 5))
        app.buttons["settingsCloseButton"].tap()
        XCTAssertTrue(element("pdfViewerScreen").waitForExistence(timeout: 5))
    }

    @MainActor
    private func setToggle(labels: [String], enabled: Bool) {
        let toggle = app.switches.matching(
            NSPredicate(format: "label IN %@", labels)
        ).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let expectedValue = enabled ? "1" : "0"
        if toggle.value as? String != expectedValue {
            toggle.tap()
        }
        XCTAssertEqual(toggle.value as? String, expectedValue)
    }

    @MainActor
    private func tapButton(labels: [String]) {
        let button = app.buttons.matching(
            NSPredicate(format: "label IN %@", labels)
        ).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }

    @MainActor
    private func showViewerControls() {
        if !app.buttons["settingsButton"].exists {
            tapViewer()
        }
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func hideViewerControls() {
        if app.buttons["settingsButton"].exists {
            tapViewer()
        }
        XCTAssertFalse(app.buttons["settingsButton"].waitForExistence(timeout: 2))
    }

    @MainActor
    private func tapViewer() {
        element("pdfViewerScreen")
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .tap()
    }

    @MainActor
    private func dismissKeyboard() {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists, !keyboard.frame.isEmpty else { return }

        app.textFields["searchField"].typeText(XCUIKeyboardKey.return.rawValue)

        let keyboardIsStillVisible = keyboard.waitForExistence(timeout: 1)
            && !keyboard.frame.isEmpty
        XCTAssertFalse(keyboardIsStillVisible)
        showViewerControls()
    }

    @MainActor
    private func rotate(to orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        let expectsLandscape = orientation == .landscapeLeft || orientation == .landscapeRight
        let predicate = NSPredicate { [self] _, _ in
            let frame = app.windows.firstMatch.frame
            return expectsLandscape ? frame.width > frame.height : frame.height > frame.width
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
        XCTAssertTrue(element("pdfViewerScreen").exists)
        waitForRendering()
    }

    private func waitForRendering() {
        RunLoop.current.run(until: Date().addingTimeInterval(1))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
