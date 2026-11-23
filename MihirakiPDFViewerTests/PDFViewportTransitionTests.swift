import PDFKit
import SwiftUI
import Testing
@testable import MihirakiPDFViewer

@MainActor
struct PDFViewportTransitionTests {
    private let compactSize = CGSize(width: 400, height: 800)
    private let regularSize = CGSize(width: 1000, height: 800)

    @Test(arguments: [false, true], [false, true])
    func repeatedResizePreservesEveryPage(cover: Bool, rightToLeft: Bool) throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let model = try makeModel(fixture, cover: cover, rightToLeft: rightToLeft)
        model.searchQuery = "retained query"

        for page in 0..<7 {
            model.updateViewportSize(compactSize, horizontalSizeClass: .compact)
            model.jumpToPDFPage(page)
            for _ in 0..<3 {
                model.updateViewportSize(regularSize, horizontalSizeClass: .regular)
                #expect(model.displayedPDFPageIndices.contains(page))
                // Intermediate geometry and size-class notifications must not lose the anchor.
                model.updateViewportSize(CGSize(width: 700, height: 850), horizontalSizeClass: .regular)
                model.updateViewportSize(compactSize, horizontalSizeClass: .compact)
                #expect(model.displayedPDFPageIndices == [page])
                #expect(model.searchQuery == "retained query")
            }
        }
    }

    @Test
    func sizeClassChangeWithoutResizePreservesSecondPage() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let model = try makeModel(fixture)
        model.updateViewportSize(compactSize, horizontalSizeClass: .compact)
        model.jumpToPDFPage(3)
        model.updateViewportSize(compactSize, horizontalSizeClass: .regular)
        #expect(model.displayedPDFPageIndices == [3])
        model.updateViewportSize(compactSize, horizontalSizeClass: .compact)
        #expect(model.displayedPDFPageIndices == [3])
    }

    @Test
    func navigationReplacesPreviousAnchor() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let model = try makeModel(fixture)
        model.updateViewportSize(compactSize, horizontalSizeClass: .compact)
        model.jumpToPDFPage(3)
        model.updateViewportSize(regularSize, horizontalSizeClass: .regular)
        model.currentPageIndex = 2
        model.updateViewportSize(compactSize, horizontalSizeClass: .compact)
        #expect(model.displayedPDFPageIndices == [4])

        model.updateViewportSize(regularSize, horizontalSizeClass: .regular)
        model.jumpToPDFPage(5) // A new target within the already selected spread.
        model.updateViewportSize(compactSize, horizontalSizeClass: .compact)
        #expect(model.displayedPDFPageIndices == [5])
    }

    @Test
    func relaunchAtDifferentSizeRestoresExactPDFPage() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let model = try makeModel(fixture, sessionURL: fixture.sessionURL)
        model.updateViewportSize(compactSize, horizontalSizeClass: .compact)
        model.jumpToPDFPage(3)
        model.updateViewportSize(regularSize, horizontalSizeClass: .regular)
        model.saveReadingSession()

        let restored = PDFViewerViewModel(
            settings: PDFViewerSettings(isSinglePageInPortraitEnabled: true),
            sessionURL: fixture.sessionURL
        )
        restored.updateViewportSize(compactSize, horizontalSizeClass: .compact)
        let url = try #require(restored.documentURLForRestoration())
        #expect(restored.loadDocument(from: url) == .loaded)
        #expect(restored.displayedPDFPageIndices == [3])
    }

    @Test
    func newDocumentDoesNotInheritAnchor() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let model = try makeModel(fixture)
        model.updateViewportSize(compactSize, horizontalSizeClass: .compact)
        model.jumpToPDFPage(1)
        model.updateViewportSize(regularSize, horizontalSizeClass: .regular)
        #expect(model.loadDocument(from: fixture.pdfURL) == .loaded)
        model.settings.isSpreadViewEnabled = true
        model.updateViewportSize(compactSize, horizontalSizeClass: .compact)
        #expect(model.displayedPDFPageIndices == [0])
    }

    @Test
    func zoomOffsetScalesAndClampsOnResize() {
        let offset = PDFViewportZoom.resizedOffset(
            CGSize(width: 100, height: -200),
            from: CGSize(width: 800, height: 1000),
            to: CGSize(width: 400, height: 500),
            zoomScale: 2
        )
        #expect(offset == CGSize(width: 50, height: -100))
        #expect(PDFViewportZoom.resizedOffset(
            CGSize(width: 2000, height: -2000),
            from: CGSize(width: 800, height: 1000),
            to: CGSize(width: 400, height: 500),
            zoomScale: 2
        ) == CGSize(width: 200, height: -250))
        #expect(PDFViewportZoom.resizedOffset(
            offset, from: compactSize, to: regularSize, zoomScale: 1
        ) == .zero)
        #expect(PDFViewportZoom.resizedOffset(
            offset, from: .zero, to: regularSize, zoomScale: 2
        ) == .zero)
    }

    @Test
    func legacySessionWithoutPDFPageRemainsDecodable() throws {
        let json = """
        {"bookmark":"","pageIndex":2,"searchQuery":"","isSpread":true,"isCover":false,"isRightToLeft":false}
        """
        let state = try JSONDecoder().decode(ReadingSessionStore.State.self, from: Data(json.utf8))
        #expect(state.pageIndex == 2)
        #expect(state.pdfPageIndex == nil)
    }

    private func makeModel(
        _ fixture: Fixture,
        cover: Bool = false,
        rightToLeft: Bool = false,
        sessionURL: URL? = nil
    ) throws -> PDFViewerViewModel {
        let model = PDFViewerViewModel(
            settings: PDFViewerSettings(isSinglePageInPortraitEnabled: true),
            sessionURL: sessionURL
        )
        #expect(model.loadDocument(from: fixture.pdfURL) == .loaded)
        model.updateSettings(
            isSpreadViewEnabled: true,
            isCoverPageEnabled: cover,
            layoutDirection: rightToLeft ? .rightToLeft : .leftToRight
        )
        return model
    }

    private struct Fixture {
        let directory: URL
        var pdfURL: URL { directory.appendingPathComponent("sample.pdf") }
        var sessionURL: URL { directory.appendingPathComponent("session.json") }

        init() throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let document = PDFDocument()
            let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 150)).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 100, height: 150))
            }
            for index in 0..<7 {
                document.insert(try #require(PDFPage(image: image)), at: index)
            }
            try #require(document.dataRepresentation()).write(to: pdfURL)
        }

        func remove() {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
