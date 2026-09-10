//
//  MihirakiPDFViewerUITests.swift
//  MihirakiPDFViewerUITests
//
//  Created by 山田 琢磨 on 2026/08/21.
//

import XCTest
import PDFKit

final class MihirakiPDFViewerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-uiTestDisableAutoFilePicker")
        app.launchArguments.append("-uiTestResetReadingSession")
        app.launchArguments.append("-uiTestResetRenderingPreferences")
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
    func testZoomedEdgeDraggingDoesNotTurnPages() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments.append("-uiTestLoadSamplePDF")
        app.launch()
        XCTAssertTrue(element("pdfViewerScreen").waitForExistence(timeout: 10))
        XCTAssertTrue(showPageIndicatorIfNeeded().waitForExistence(timeout: 5))
        app.sliders["pageSlider"].adjust(toNormalizedSliderPosition: 0.5)
        let expectedPage = element("pageIndicator").label
        XCTAssertEqual(expectedPage, "2 / 3")
        recordResumeScreen("Before zoom, page \(expectedPage)")
        element("pdfViewerScreen").pinch(withScale: 2, velocity: 1)
        recordResumeScreen("After 2x pinch, page \(expectedPage)")
        let window = app.windows.firstMatch
        let left = window.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
        let right = window.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        var unexpectedPages: [String] = []
        for step in 0..<8 {
            if step < 3 {
                right.press(forDuration: 0.4, thenDragTo: left)
            } else {
                left.press(forDuration: 0.4, thenDragTo: right)
            }
            let actualPage = element("pageIndicator").label
            recordResumeScreen("Zoomed long-press drag \(step + 1), page \(actualPage)")
            if actualPage != expectedPage { unexpectedPages.append("drag \(step + 1): \(actualPage)") }
        }
        XCTAssertTrue(unexpectedPages.isEmpty, "Unexpected page turns while zoomed: \(unexpectedPages)")
    }

    @MainActor
    func testLargePDFSliderSelectsExactPages() throws {
        XCUIDevice.shared.orientation = .portrait
        let url = try largePDFLoadTestURL()
        let totalPages = try XCTUnwrap(PDFDocument(url: url)).pageCount
        XCTAssertGreaterThan(totalPages, 1_000)
        app.launchArguments.append(contentsOf: ["-uiTestPDFPath", url.path])
        app.launch()
        XCTAssertTrue(element("pdfViewerScreen").waitForExistence(timeout: 30))
        XCTAssertTrue(showPageIndicatorIfNeeded().waitForExistence(timeout: 5))
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(element("settingsScreen").waitForExistence(timeout: 5))
        let spreadToggle = app.switches.matching(NSPredicate(format: "label IN %@", ["見開き表示", "Two-page View"])).firstMatch
        XCTAssertTrue(spreadToggle.waitForExistence(timeout: 5))
        if spreadToggle.value as? String == "1" { spreadToggle.tap() }
        app.buttons.matching(NSPredicate(format: "label IN %@", ["左から右 (L2R)", "Left to Right (L2R)"])).firstMatch.tap()
        app.buttons["settingsCloseButton"].tap()
        XCTAssertTrue(showPageIndicatorIfNeeded().waitForExistence(timeout: 5))
        XCTAssertEqual(element("pageIndicator").label.replacingOccurrences(of: ",", with: ""), "1 / \(totalPages)")
        let slider = app.sliders["pageSlider"]
        var mismatches: [String] = []
        for target in [1, 2, 137, 550, 551, 999, totalPages] {
            slider.adjust(toNormalizedSliderPosition: CGFloat(target - 1) / CGFloat(totalPages - 1))
            let actual = element("pageIndicator").label.replacingOccurrences(of: ",", with: "")
            let expected = "\(target) / \(totalPages)"
            XCTContext.runActivity(named: "Slider target \(target): actual \(actual), track width \(slider.frame.width)") { _ in
                recordResumeScreen("Slider target \(target), actual \(actual)")
            }
            if actual != expected { mismatches.append("target \(target): \(actual)") }
        }
        XCTAssertTrue(mismatches.isEmpty, "Slider did not select exact pages: \(mismatches)")
    }

    @MainActor
    func testHighQualitySettingSurvivesTermination() throws {
        try assertRenderingSettingSurvivesTermination(labels: ["高画質化", "High Quality"])
    }

    @MainActor
    func testSharpnessSettingSurvivesTermination() throws {
        try assertRenderingSettingSurvivesTermination(labels: ["シャープネス", "Sharpness"])
    }

    @MainActor
    private func assertRenderingSettingSurvivesTermination(labels: [String]) throws {
        app.launchArguments.append("-uiTestLoadSamplePDF")
        app.launch()
        XCTAssertTrue(element("pdfViewerScreen").waitForExistence(timeout: 10))
        tapPDFViewer()
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(element("settingsScreen").waitForExistence(timeout: 5))
        let toggle = app.switches.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if toggle.value as? String != "1" { toggle.tap() }
        XCTAssertEqual(toggle.value as? String, "1")
        recordResumeScreen("\(labels[0]) enabled before termination")

        XCUIDevice.shared.press(.home)
        app.terminate()
        XCTAssertEqual(app.state, .notRunning)
        app.launchArguments = ["-uiTestDisableAutoFilePicker"]
        app.launch()
        XCTAssertTrue(element("pdfViewerScreen").waitForExistence(timeout: 10))
        tapPDFViewer()
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(element("settingsScreen").waitForExistence(timeout: 5))
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        recordResumeScreen("\(labels[0]) after relaunch")
        XCTAssertEqual(toggle.value as? String, "1", "\(labels[0]) was reset after termination")
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
    func testLargePDFScrollingDoesNotCrashOrStall() throws {
        let largePDFURL = try largePDFLoadTestURL()
        let attributes = try FileManager.default.attributesOfItem(atPath: largePDFURL.path)
        let fileSize = try XCTUnwrap(attributes[.size] as? NSNumber).int64Value
        let document = try XCTUnwrap(PDFDocument(url: largePDFURL))

        XCTAssertGreaterThan(fileSize, 100 * 1024 * 1024)
        XCTAssertGreaterThan(document.pageCount, 1_000)

        app.launchArguments.append(contentsOf: ["-uiTestPDFPath", largePDFURL.path])
        app.launch()

        let pdfViewer = element("pdfViewerScreen")
        XCTAssertTrue(pdfViewer.waitForExistence(timeout: 20))

        XCTAssertTrue(showPageIndicatorIfNeeded().waitForExistence(timeout: 5))

        for _ in 0..<30 {
            app.swipeLeft()
        }

        XCTAssertTrue(pdfViewer.exists)
        XCTAssertTrue(app.state == .runningForeground)

        let pageIndicator = showPageIndicatorIfNeeded()
        XCTAssertTrue(pageIndicator.waitForExistence(timeout: 5))
        XCTAssertFalse(pageIndicator.label.hasPrefix("1 / "))
    }

    @MainActor
    func testRepeatedHighHitSearchesKeepViewerResponsive() throws {
        let cases: [(url: URL, terms: [String])] = [
            (
                try searchLoadTestURL(preferredFileName: "search_test_600_hits_jp", fallbackFileName: "search_test_600_hits"),
                ["負荷テスト", "LOADTEST600", "性能検証", "応答速度"]
            ),
            (
                try searchLoadTestURL(preferredFileName: "search_test_600_hits_en", fallbackFileName: nil),
                ["Load Testing", "LOADTEST600", "Performance Check", "Response Time"]
            )
        ]

        for testCase in cases {
            try runRepeatedSearches(in: testCase.url, terms: testCase.terms)
        }
    }

    @MainActor
    func testProtectedPDFRestoresPageAfterRelaunchAndPassword() throws {
        let url = try passwordProtectedLightNovelURL(password: "1234")
        app.launchArguments.append(contentsOf: ["-uiTestPDFPath", url.path])
        app.launch()
        func unlock() {
            let field = app.alerts.secureTextFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 10))
            field.tap()
            field.typeText("1234")
            app.alerts.firstMatch.buttons.element(boundBy: 1).tap()
            XCTAssertTrue(element("pdfViewerScreen").waitForExistence(timeout: 10))
        }
        unlock()
        XCTAssertTrue(showPageIndicatorIfNeeded().waitForExistence(timeout: 5))
        app.sliders["pageSlider"].adjust(toNormalizedSliderPosition: 0.5)
        let expectedPage = element("pageIndicator").label
        XCTAssertFalse(expectedPage.hasPrefix("1 / "))
        XCUIDevice.shared.press(.home)
        app.terminate()
        app.launchArguments = ["-uiTestDisableAutoFilePicker"]
        app.launch()
        unlock()
        XCTAssertTrue(showPageIndicatorIfNeeded().waitForExistence(timeout: 5))
        XCTAssertEqual(element("pageIndicator").label, expectedPage)
        recordResumeScreen("Protected PDF restored after password, page \(expectedPage)")
    }

    @MainActor
    func testReturningFromOtherAppsPreservesDisplayedPage() throws {
        try launchRotationTestPDF()
        let expectedPage = element("pageIndicator").label
        try visitOtherAppsWhilePDFIsInBackground()

        app.activate()
        XCTAssertTrue(element("pdfViewerScreen").waitForExistence(timeout: 10))
        XCTAssertTrue(showPageIndicatorIfNeeded().waitForExistence(timeout: 5))
        XCTAssertEqual(element("pageIndicator").label, expectedPage)
        recordResumeScreen("Returned from other apps, expected page \(expectedPage)")
    }

    @MainActor
    func testRelaunchAfterBackgroundTerminationRestoresDisplayedPage() throws {
        try launchRotationTestPDF()
        let expectedPage = element("pageIndicator").label
        app.textFields["searchField"].tap()
        app.textFields["searchField"].typeText("LOADTEST600")
        recordResumeScreen("Before termination, page \(expectedPage)")
        try visitOtherAppsWhilePDFIsInBackground()

        // Controlled process termination checks cold-launch restoration;
        // it does not reproduce an OS memory-pressure termination itself.
        app.terminate()
        XCTAssertEqual(app.state, .notRunning)
        // Do not let the test-only PDF loader mask missing restoration.
        app.launchArguments = ["-uiTestDisableAutoFilePicker"]
        app.launch()
        let restored = element("pdfViewerScreen").waitForExistence(timeout: 10)
        recordResumeScreen("After relaunch, expected page \(expectedPage)")
        XCTAssertTrue(restored, "The previously opened PDF was not restored after process termination")
        XCTAssertTrue(showPageIndicatorIfNeeded().waitForExistence(timeout: 5))
        XCTAssertEqual(element("pageIndicator").label, expectedPage)
        XCTAssertEqual(app.textFields["searchField"].value as? String, "LOADTEST600")
    }

    @MainActor
    private func visitOtherAppsWhilePDFIsInBackground() throws {
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5)
            || app.state == .runningBackgroundSuspended)
        for bundleID in ["com.apple.Preferences", "com.apple.mobilesafari", "com.apple.mobileslideshow"] {
            let otherApp = XCUIApplication(bundleIdentifier: bundleID)
            otherApp.activate()
            XCTAssertTrue(otherApp.wait(for: .runningForeground, timeout: 10), "Could not open \(bundleID)")
            XCUIDevice.shared.press(.home)
        }
    }

    @MainActor
    private func recordResumeScreen(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testRepeatedRotationPreservesDisplayedPage() throws {
        try launchRotationTestPDF()
        defer { XCUIDevice.shared.orientation = .portrait }

        let expectedPage = element("pageIndicator").label
        for orientation in rotationSequence {
            assertRotationPreservesState(orientation, page: expectedPage, query: "")
        }
    }

    @MainActor
    func testRepeatedRotationPreservesSearchWhileTyping() throws {
        try launchRotationTestPDF()
        defer { XCUIDevice.shared.orientation = .portrait }

        let expectedPage = element("pageIndicator").label
        let searchField = app.textFields["searchField"]
        searchField.tap()
        var query = ""
        let fragments = ["LO", "AD", "TEST", "6", "0", "0"]
        for (orientation, fragment) in zip(rotationSequence, fragments) {
            searchField.typeText(fragment)
            query += fragment
            assertRotationPreservesState(orientation, page: expectedPage, query: query)
            XCTAssertTrue(app.keyboards.firstMatch.exists, "Keyboard disappeared after rotation")
        }
        XCTAssertEqual(searchField.value as? String, "LOADTEST600")
    }

    private var rotationSequence: [UIDeviceOrientation] {
        [.landscapeLeft, .portrait, .landscapeRight, .portrait, .landscapeLeft, .portrait]
    }

    @MainActor
    private func launchRotationTestPDF() throws {
        XCUIDevice.shared.orientation = .portrait
        let url = try searchLoadTestURL(preferredFileName: "search_test_600_hits_en", fallbackFileName: nil)
        app.launchArguments.append(contentsOf: ["-uiTestPDFPath", url.path])
        app.launch()
        XCTAssertTrue(element("pdfViewerScreen").waitForExistence(timeout: 10))
        XCTAssertTrue(showPageIndicatorIfNeeded().waitForExistence(timeout: 5))
        app.sliders["pageSlider"].adjust(toNormalizedSliderPosition: 0.5)
        XCTAssertFalse(element("pageIndicator").label.hasPrefix("1 / "))
    }

    @MainActor
    private func assertRotationPreservesState(_ orientation: UIDeviceOrientation, page: String, query: String) {
        XCTContext.runActivity(named: "Rotate to \(orientation.rawValue), page \(page), query '\(query)'") { activity in
            XCUIDevice.shared.orientation = orientation
            let isLandscape = orientation == .landscapeLeft || orientation == .landscapeRight
            let rotated = NSPredicate { [self] _, _ in
                let frame = app.windows.firstMatch.frame
                return isLandscape ? frame.width > frame.height : frame.height > frame.width
            }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: rotated, object: nil)], timeout: 5), .completed)
            XCTAssertTrue(element("pdfViewerScreen").exists)
            XCTAssertEqual(element("pageIndicator").label, page)
            let value = app.textFields["searchField"].value as? String
            if !query.isEmpty {
                XCTAssertEqual(value, query)
            }
            XCTAssertEqual(app.state, .runningForeground)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.lifetime = .keepAlways
            activity.add(screenshot)
        }
    }

    @MainActor
    func testIncomingPDFURLCopiesThenSupportsViewingAndSearch() throws {
        let pdfURL = try searchLoadTestURL(
            preferredFileName: "search_test_600_hits_jp",
            fallbackFileName: "search_test_600_hits"
        )
        let document = try XCTUnwrap(PDFDocument(url: pdfURL))
        XCTAssertEqual(document.findString("LOADTEST600", withOptions: .caseInsensitive).count, 600)

        app.launchArguments.append(contentsOf: ["-uiTestIncomingPDFPath", pdfURL.path])
        app.launch()

        let pdfViewer = element("pdfViewerScreen")
        XCTAssertTrue(pdfViewer.waitForExistence(timeout: 10))

        XCTAssertTrue(showPageIndicatorIfNeeded().waitForExistence(timeout: 5))
        let searchField = app.textFields["searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.tap()
        searchField.typeText("LOADTEST600")

        let pageIndicator = showPageIndicatorIfNeeded()
        let previousPageLabel = pageIndicator.label
        pdfViewer.swipeLeft()

        XCTAssertTrue(pdfViewer.exists)
        XCTAssertTrue(app.state == .runningForeground)
        XCTAssertTrue(waitForPageIndicatorChange(from: previousPageLabel))
    }

    @MainActor
    func testPasswordProtectedPDFPromptHandlesWrongAndCorrectPassword() throws {
        let passwordPDFURL = try passwordProtectedLightNovelURL(password: "1234")
        let protectedDocument = try XCTUnwrap(PDFDocument(url: passwordPDFURL))
        XCTAssertTrue(protectedDocument.isEncrypted)
        XCTAssertTrue(protectedDocument.isLocked)

        func recordScreen(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        app.launchArguments.append(contentsOf: ["-uiTestPDFPath", passwordPDFURL.path])
        app.launch()

        let passwordAlert = app.alerts.firstMatch
        XCTAssertTrue(passwordAlert.waitForExistence(timeout: 10))

        let passwordField = passwordAlert.secureTextFields.firstMatch
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))

        let unlockButton = passwordAlert.buttons.element(boundBy: 1)
        XCTAssertTrue(unlockButton.exists)

        let messageText = passwordAlert.staticTexts.element(boundBy: 1)
        let initialMessage = messageText.label
        recordScreen("Password dialog")
        passwordField.tap()
        passwordField.typeText("0000")
        unlockButton.tap()

        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        XCTAssertNotEqual(messageText.label, initialMessage)
        XCTAssertFalse(messageText.label.isEmpty)
        XCTAssertFalse(element("pdfViewerScreen").exists)
        recordScreen("Incorrect password error")

        passwordField.tap()
        passwordField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4))
        passwordField.typeText("1234")
        unlockButton.tap()

        XCTAssertTrue(element("pdfViewerScreen").waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        recordScreen("PDF opened with correct password")
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

    private func largePDFLoadTestURL() throws -> URL {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return projectRoot
            .appendingPathComponent("testdata")
            .appendingPathComponent("load_test_1100_pages.pdf")
    }

    private func searchLoadTestURL(preferredFileName: String, fallbackFileName: String?) throws -> URL {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let preferredURL = projectRoot
            .appendingPathComponent("testdata")
            .appendingPathComponent(preferredFileName)
            .appendingPathExtension("pdf")

        if FileManager.default.fileExists(atPath: preferredURL.path) {
            return preferredURL
        }

        guard let fallbackFileName else {
            return preferredURL
        }

        return projectRoot
            .appendingPathComponent("testdata")
            .appendingPathComponent(fallbackFileName)
            .appendingPathExtension("pdf")
    }

    private func passwordProtectedLightNovelURL(password: String) throws -> URL {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let requestedURL = projectRoot
            .appendingPathComponent("testdata")
            .appendingPathComponent("TestLightNovel_password")
            .appendingPathExtension("pdf")

        if FileManager.default.fileExists(atPath: requestedURL.path) {
            return requestedURL
        }

        let sourceURL = projectRoot
            .appendingPathComponent("testdata")
            .appendingPathComponent("TestLightNovel")
            .appendingPathExtension("pdf")
        let sourceDocument = try XCTUnwrap(PDFDocument(url: sourceURL))
        let protectedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        let didWrite = sourceDocument.write(
            to: protectedURL,
            withOptions: [
                PDFDocumentWriteOption.userPasswordOption: password,
                PDFDocumentWriteOption.ownerPasswordOption: "owner-\(password)"
            ]
        )

        XCTAssertTrue(didWrite)
        return protectedURL
    }

    private func tapPDFViewer() {
        let pdfViewer = element("pdfViewerScreen")
        pdfViewer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func runRepeatedSearches(in pdfURL: URL, terms: [String]) throws {
        app.launchArguments.append(contentsOf: ["-uiTestPDFPath", pdfURL.path])
        app.launch()

        let pdfViewer = element("pdfViewerScreen")
        XCTAssertTrue(pdfViewer.waitForExistence(timeout: 10))
        XCTAssertTrue(showPageIndicatorIfNeeded().waitForExistence(timeout: 5))

        let searchField = app.textFields["searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        var currentSearchText = ""
        for term in terms {
            let pageIndicator = showPageIndicatorIfNeeded()
            let previousPageLabel = pageIndicator.label
            replaceSearchText(in: searchField, currentText: currentSearchText, newText: term)
            currentSearchText = term

            let startTime = Date()
            pdfViewer.swipeLeft()
            XCTAssertTrue(pdfViewer.exists)
            XCTAssertTrue(app.state == .runningForeground)
            XCTAssertTrue(waitForPageIndicatorChange(from: previousPageLabel))
            XCTAssertLessThan(Date().timeIntervalSince(startTime), 5)
        }

        app.terminate()
    }

    private func replaceSearchText(in searchField: XCUIElement, currentText: String, newText: String) {
        searchField.tap()
        if !currentText.isEmpty {
            let deleteCharacters = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentText.count)
            searchField.typeText(deleteCharacters)
        }
        searchField.typeText(newText)
    }

    private func showPageIndicatorIfNeeded() -> XCUIElement {
        let pageIndicator = element("pageIndicator")
        if !pageIndicator.exists {
            tapPDFViewer()
        }

        return pageIndicator
    }

    private func waitForPageIndicatorChange(from previousLabel: String, timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element("pageIndicator").label != previousLabel {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        return false
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
