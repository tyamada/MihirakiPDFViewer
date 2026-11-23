import CoreGraphics
import UIKit
import XCTest

enum AppStoreScreenshotValidationError: LocalizedError {
    case appNotForeground(XCUIApplication.State)
    case expectedElementMissing(String)
    case unexpectedAlert(String)
    case unexpectedSystemAlert(String)
    case languageMarkerMissing([String])
    case imageUnavailable
    case unexpectedPixelSize(actual: CGSize, allowed: Set<CGSize>)
    case mostlyBlack(Double)
    case mostlyWhite(Double)
    case insufficientVisualDetail(Double)

    var errorDescription: String? {
        switch self {
        case .appNotForeground(let state):
            return "The target app is not in the foreground (state: \(state.rawValue)). The screenshot may show the Home Screen or another app."
        case .expectedElementMissing(let identifier):
            return "The expected screen element “\(identifier)” is missing."
        case .unexpectedAlert(let label):
            return "An unexpected in-app alert is visible: \(label)"
        case .unexpectedSystemAlert(let label):
            return "An unexpected system alert is visible: \(label)"
        case .languageMarkerMissing(let markers):
            return "None of the expected language markers are visible: \(markers.joined(separator: ", "))"
        case .imageUnavailable:
            return "The screenshot could not be converted to pixel data."
        case .unexpectedPixelSize(let actual, let allowed):
            let sizes = allowed
                .map { "\(Int($0.width)) × \(Int($0.height))" }
                .sorted()
                .joined(separator: ", ")
            return "Unexpected screenshot size \(Int(actual.width)) × \(Int(actual.height)); expected one of: \(sizes)."
        case .mostlyBlack(let ratio):
            return String(format: "The screenshot is mostly black (%.1f%% dark pixels).", ratio * 100)
        case .mostlyWhite(let ratio):
            return String(format: "The screenshot is mostly white (%.1f%% near-white pixels).", ratio * 100)
        case .insufficientVisualDetail(let deviation):
            return String(format: "The screenshot has too little visual detail (luminance deviation %.4f).", deviation)
        }
    }
}

struct AppStoreScreenshotExpectation {
    let requiredElementIdentifier: String
    let languageMarkers: [String]
    var allowedAlertLabels: Set<String> = []
    var allowedPixelSizes: Set<CGSize> = []
    var allowsMostlyWhite = false
}

@MainActor
enum AppStoreScreenshotCapture {
    static func capture(
        named name: String,
        app: XCUIApplication,
        expectation: AppStoreScreenshotExpectation,
        testCase: XCTestCase,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try validateUI(app: app, expectation: expectation)

        let screenshot = XCUIScreen.main.screenshot()
        let image = normalizedImage(screenshot.image)
        try validatePixels(
            in: image,
            allowedPixelSizes: expectation.allowedPixelSizes,
            allowsMostlyWhite: expectation.allowsMostlyWhite
        )

        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        testCase.add(attachment)
    }

    private static func validateUI(
        app: XCUIApplication,
        expectation: AppStoreScreenshotExpectation
    ) throws {
        guard app.state == .runningForeground else {
            throw AppStoreScreenshotValidationError.appNotForeground(app.state)
        }

        let expectedElement = app.descendants(matching: .any)[expectation.requiredElementIdentifier]
        guard expectedElement.waitForExistence(timeout: 5) else {
            throw AppStoreScreenshotValidationError.expectedElementMissing(
                expectation.requiredElementIdentifier
            )
        }

        let visibleAlerts = app.alerts.allElementsBoundByIndex.filter(\.exists)
        if let unexpected = visibleAlerts.first(where: {
            !expectation.allowedAlertLabels.contains($0.label)
        }) {
            throw AppStoreScreenshotValidationError.unexpectedAlert(unexpected.label)
        }

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if let systemAlert = springboard.alerts.allElementsBoundByIndex.first(where: \.exists) {
            throw AppStoreScreenshotValidationError.unexpectedSystemAlert(systemAlert.label)
        }

        guard expectation.languageMarkers.isEmpty || expectation.languageMarkers.contains(where: {
            app.staticTexts[$0].exists || app.buttons[$0].exists || app.navigationBars[$0].exists
        }) else {
            throw AppStoreScreenshotValidationError.languageMarkerMissing(
                expectation.languageMarkers
            )
        }
    }

    private static func normalizedImage(_ source: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = source.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: source.size, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: source.size))
        }
    }

    private static func validatePixels(
        in image: UIImage,
        allowedPixelSizes: Set<CGSize>,
        allowsMostlyWhite: Bool
    ) throws {
        guard let cgImage = image.cgImage else {
            throw AppStoreScreenshotValidationError.imageUnavailable
        }

        let actualSize = CGSize(width: cgImage.width, height: cgImage.height)
        if !allowedPixelSizes.isEmpty, !allowedPixelSizes.contains(actualSize) {
            throw AppStoreScreenshotValidationError.unexpectedPixelSize(
                actual: actualSize,
                allowed: allowedPixelSizes
            )
        }

        let sampleWidth = 64
        let sampleHeight = 64
        let bytesPerPixel = 4
        let bytesPerRow = sampleWidth * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: sampleHeight * bytesPerRow)

        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw AppStoreScreenshotValidationError.imageUnavailable
        }

        context.interpolationQuality = .low
        context.draw(
            cgImage,
            in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight)
        )

        var darkPixelCount = 0
        var nearWhitePixelCount = 0
        var luminanceSum = 0.0
        var squaredLuminanceSum = 0.0
        let pixelCount = sampleWidth * sampleHeight

        for offset in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let red = Double(pixels[offset]) / 255
            let green = Double(pixels[offset + 1]) / 255
            let blue = Double(pixels[offset + 2]) / 255
            let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue

            if luminance < 0.025 {
                darkPixelCount += 1
            }
            if luminance > 0.975 {
                nearWhitePixelCount += 1
            }
            luminanceSum += luminance
            squaredLuminanceSum += luminance * luminance
        }

        let darkRatio = Double(darkPixelCount) / Double(pixelCount)
        guard darkRatio < 0.98 else {
            throw AppStoreScreenshotValidationError.mostlyBlack(darkRatio)
        }

        let nearWhiteRatio = Double(nearWhitePixelCount) / Double(pixelCount)
        guard allowsMostlyWhite || nearWhiteRatio < 0.98 else {
            throw AppStoreScreenshotValidationError.mostlyWhite(nearWhiteRatio)
        }

        let mean = luminanceSum / Double(pixelCount)
        let variance = max(0, squaredLuminanceSum / Double(pixelCount) - mean * mean)
        let standardDeviation = sqrt(variance)
        guard standardDeviation > 0.01 else {
            throw AppStoreScreenshotValidationError.insufficientVisualDetail(standardDeviation)
        }
    }
}
