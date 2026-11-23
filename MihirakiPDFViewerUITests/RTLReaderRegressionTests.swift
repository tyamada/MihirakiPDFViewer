import XCTest

final class RTLReaderRegressionTests: XCTestCase {
    // Run this alone on a newly created simulator: no reset launch arguments.
    @MainActor
    func testActualPDFFirstInstallThenSubsequentOpens() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for (index, name) in ["tameshibu_episode1_2_en", "Regression8_L2R_Single", "tameshibu_episode1_2_en"].enumerated() {
            let app = XCUIApplication()
            app.launchEnvironment["MIHIRAKI_OFFLINE_VALIDATION"] = "1"
            app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                "-uiTestPDFPath", (name.hasPrefix("tameshibu") ? try SamplePDFFixture.url(named: name) : root.appendingPathComponent("testdata/\(name).pdf")).path]
            app.launch()
            let reader = app.descendants(matching: .any)["pdfViewerScreen"].firstMatch
            XCTAssertTrue(reader.waitForExistence(timeout: 20))
            Thread.sleep(forTimeInterval: 10)
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "Open \(index + 1) \(name) after 10s idle"
            shot.lifetime = .keepAlways; add(shot)
            let indicator = app.descendants(matching: .any)["pageIndicator"].firstMatch
            if !indicator.exists {
                reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            XCTAssertTrue(indicator.waitForExistence(timeout: 5))
            XCTAssertEqual(indicator.label, "1 / 8", app.debugDescription)
            XCTAssertTrue(app.images["Page 1"].isHittable)
            app.terminate()
        }
    }

    @MainActor
    func testEightPageRTLAndLTRInitialDisplaySwipeAndResume() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        for direction in ["R2L", "L2R"] {
            let app = XCUIApplication()
            app.launchEnvironment["MIHIRAKI_OFFLINE_VALIDATION"] = "1"
            let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .deletingLastPathComponent().appendingPathComponent("testdata/Regression8_\(direction)_Single.pdf")
            app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                "-uiTestResetReadingSession", "-uiTestResetRenderingPreferences", "-uiTestPDFPath", url.path]
            app.launch()
            let reader = app.descendants(matching: .any)["pdfViewerScreen"].firstMatch
            XCTAssertTrue(reader.waitForExistence(timeout: 15))
            func indicator() -> XCUIElement {
                let element = app.descendants(matching: .any)["pageIndicator"].firstMatch
                if !element.exists { reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
                XCTAssertTrue(element.waitForExistence(timeout: 5))
                return element
            }
            XCTAssertEqual(indicator().label, "1 / 8")
            Thread.sleep(forTimeInterval: 3)
            XCTAssertEqual(indicator().label, "1 / 8")
            if direction == "R2L" { reader.swipeRight() } else { reader.swipeLeft() }
            XCTAssertEqual(indicator().label, "2 / 8")
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "\(direction) next page 2 of 8"; shot.lifetime = .keepAlways; add(shot)
            if direction == "R2L" { reader.swipeLeft() } else { reader.swipeRight() }
            XCTAssertEqual(indicator().label, "1 / 8")
            for _ in 0..<3 {
                if direction == "R2L" { reader.swipeRight() } else { reader.swipeLeft() }
            }
            XCTAssertEqual(indicator().label, "4 / 8")
            XCUIDevice.shared.press(.home)
            app.terminate()
            app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            app.launch()
            XCTAssertTrue(reader.waitForExistence(timeout: 15))
            XCTAssertEqual(indicator().label, "4 / 8")
            app.terminate()
        }
    }
    @MainActor
    func testRightToLeftSpreadPlacementAndRotation() throws {
        continueAfterFailure = false
        defer { XCUIDevice.shared.orientation = .portrait }
        for cover in [false, true] {
            let app = XCUIApplication()
            app.launchEnvironment["MIHIRAKI_OFFLINE_VALIDATION"] = "1"
            let name = cover ? "R2L_TwoPageRight" : "R2L_TwoPageLeft"
            let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .deletingLastPathComponent().appendingPathComponent("testdata/Regression8_\(name).pdf")
            app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                "-uiTestResetReadingSession", "-uiTestResetRenderingPreferences", "-uiTestPDFPath", url.path]
            XCUIDevice.shared.orientation = .landscapeLeft
            app.launch()
            let reader = app.descendants(matching: .any)["pdfViewerScreen"].firstMatch
            XCTAssertTrue(reader.waitForExistence(timeout: 15))
            XCTAssertTrue(app.images["Page 1"].waitForExistence(timeout: 5))
            if !cover {
                XCTAssertTrue(app.images["Page 2"].exists)
                XCTAssertLessThan(app.images["Page 2"].frame.midX, app.images["Page 1"].frame.midX)
            }
            XCUIDevice.shared.orientation = .portrait
            XCTAssertTrue(app.images["Page 1"].waitForExistence(timeout: 5))
            Thread.sleep(forTimeInterval: 1)
            for page in 2...4 {
                reader.swipeRight()
                XCTAssertTrue(app.images["Page \(page)"].waitForExistence(timeout: 5), app.debugDescription)
            }
            XCTAssertTrue(app.images["Page 4"].waitForExistence(timeout: 5), app.debugDescription)
            XCUIDevice.shared.orientation = .landscapeLeft
            XCTAssertTrue(app.images["Page 4"].waitForExistence(timeout: 5))
            let left = cover ? "Page 5" : "Page 4"
            let right = cover ? "Page 4" : "Page 3"
            XCTAssertTrue(app.images[left].exists)
            XCTAssertTrue(app.images[right].exists)
            XCTAssertLessThan(app.images[left].frame.midX, app.images[right].frame.midX)
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "RTL spread cover=\(cover), anchor PDF page 4"
            shot.lifetime = .keepAlways; add(shot)
            XCUIDevice.shared.orientation = .portrait
            XCTAssertTrue(app.images["Page 4"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }

    @MainActor
    func testZoomDragKeepsPage() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        for direction in ["R2L", "L2R"] {
            let app = XCUIApplication()
            app.launchEnvironment["MIHIRAKI_OFFLINE_VALIDATION"] = "1"
            let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .deletingLastPathComponent().appendingPathComponent("testdata/Regression8_\(direction)_Single.pdf")
            app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                "-uiTestResetReadingSession", "-uiTestResetRenderingPreferences", "-uiTestPDFPath", url.path]
            app.launch()
            let reader = app.descendants(matching: .any)["pdfViewerScreen"].firstMatch
            XCTAssertTrue(reader.waitForExistence(timeout: 15))
            reader.pinch(withScale: 2, velocity: 1)
            let start = reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.5, thenDragTo: reader.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)))
            let indicator = app.descendants(matching: .any)["pageIndicator"].firstMatch
            if !indicator.exists { start.tap() }
            XCTAssertTrue(indicator.waitForExistence(timeout: 5))
            XCTAssertEqual(indicator.label, "1 / 8")
            XCTAssertTrue(app.images["Page 1"].exists)
            app.terminate()
        }
    }

}
