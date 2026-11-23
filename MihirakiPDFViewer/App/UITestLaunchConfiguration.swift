//
// UITestLaunchConfiguration.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import Foundation
import UIKit

struct UITestLaunchConfiguration {
    private enum Argument {
        static let incomingPDFPath = "-uiTestIncomingPDFPath"
        static let loadSamplePDF = "-uiTestLoadSamplePDF"
        static let pdfPath = "-uiTestPDFPath"
        static let resetReadingSession = "-uiTestResetReadingSession"
        static let resetRenderingPreferences = "-uiTestResetRenderingPreferences"
    }

    let arguments: [String]

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.arguments = arguments
    }

    var shouldResetReadingSession: Bool {
        arguments.contains(Argument.resetReadingSession)
    }

    var shouldResetRenderingPreferences: Bool {
        arguments.contains(Argument.resetRenderingPreferences)
    }

    var shouldLoadSamplePDF: Bool {
        arguments.contains(Argument.loadSamplePDF)
    }

    var incomingPDFURL: URL? {
        fileURL(after: Argument.incomingPDFPath)
    }

    var pdfURL: URL? {
        fileURL(after: Argument.pdfPath)
    }

    func makeSamplePDF() -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MihirakiPDFViewerUITest")
            .appendingPathExtension("pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 320, height: 420))

        do {
            try renderer.writePDF(to: url) { context in
                for pageNumber in 1...3 {
                    context.beginPage()
                    let text = "UI Test Page \(pageNumber)"
                    text.draw(
                        at: CGPoint(x: 32, y: 32),
                        withAttributes: [.font: UIFont.systemFont(ofSize: 24)]
                    )
                }
            }
            return url
        } catch {
            return nil
        }
    }

    private func fileURL(after argument: String) -> URL? {
        guard let argumentIndex = arguments.firstIndex(of: argument),
              arguments.indices.contains(argumentIndex + 1) else {
            return nil
        }

        return URL(fileURLWithPath: arguments[argumentIndex + 1])
    }
}
