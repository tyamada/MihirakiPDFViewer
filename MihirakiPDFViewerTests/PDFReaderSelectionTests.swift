import PDFKit
import SwiftUI
import Testing
@testable import MihirakiPDFViewer

@MainActor
@Suite(.serialized)
struct PDFReaderSelectionTests {
    private func pdfURL(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("testdata/\("Regression8_" + name).pdf")
    }

    // Calls the UIKit activation entry point; real VoiceOver gestures still need SE verification.
    @Test(arguments: ["R2L_TwoPageLeft", "L2R_TwoPageLeft"])
    func pageActivationTogglesChromeWithoutChangingReadingPosition(name: String) async throws {
        let model = PDFViewerViewModel()
        #expect(model.loadDocument(from: pdfURL(name)) == .loaded)
        model.jumpToPDFPage(3)
        var chromeVisible = false
        let binding = Binding(get: { chromeVisible }, set: { chromeVisible = $0 })
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        func root(_ landscape: Bool) -> some View {
            PDFContainerView(viewModel: model, isPDFChromeVisible: binding,
                             isScrollDirectionHintVisible: false, accessibilitySurfaceOverride: true)
                .frame(width: landscape ? 667 : 375, height: landscape ? 375 : 667)
                .environment(\.horizontalSizeClass, .compact)
        }
        let controller = UIHostingController(rootView: root(false))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        func images(_ view: UIView) -> [PDFPageAccessibilityImageView] {
            (view as? PDFPageAccessibilityImageView).map { [$0] } ?? view.subviews.flatMap { images($0) }
        }
        for landscape in [false, true, false] {
            controller.rootView = root(landscape)
            try await Task.sleep(for: .milliseconds(500))
            let pages = images(controller.view)
            #expect(!pages.isEmpty)
            let selection = model.currentPageIndex
            let displayed = model.displayedPDFPageIndices
            let retainedPage = model.accessibilityFocusPageNumber
            for page in pages {
                #expect(page.accessibilityActivate())
                #expect(chromeVisible)
                #expect(page.accessibilityActivate())
                #expect(!chromeVisible)
                #expect(model.currentPageIndex == selection)
                #expect(model.displayedPDFPageIndices == displayed)
                #expect(model.accessibilityFocusPageNumber == retainedPage)
            }
        }
        let detached = PDFPageAccessibilityImageView(frame: .zero)
        #expect(!detached.accessibilityActivate())
        detached.chromeVisibility = binding
        detached.invalidateFocusRequest()
        #expect(!detached.accessibilityActivate())
        #expect(!chromeVisible)
    }

    // Debug override exercises the view branch, not real VoiceOver.
    @Test(arguments: [false, true])
    func firstPageSurvivesPagerMountAndDocumentSwitch(voiceOverSurface: Bool) async throws {
        for name in ["R2L_Single", "L2R_Single", "R2L_TwoPageLeft", "R2L_TwoPageRight"] {
            for landscape in [false, true] {
                try await checkPager(name, landscape: landscape, voiceOverSurface: voiceOverSurface)
            }
        }
    }

    private func checkPager(_ name: String, landscape: Bool, voiceOverSurface: Bool) async throws {
        let model = PDFViewerViewModel()
        #expect(model.loadDocument(from: pdfURL(name)) == .loaded)
        #expect(model.displayedPDFPageIndices.contains(0))
        #expect(model.document?.totalPageCount == 8)
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let controller = UIHostingController(rootView: PDFContainerView(
            viewModel: model, isPDFChromeVisible: .constant(true), isScrollDirectionHintVisible: false,
            accessibilitySurfaceOverride: voiceOverSurface
        ).frame(width: landscape ? 667 : 375, height: landscape ? 375 : 667)
            .environment(\.horizontalSizeClass, .compact))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        for _ in 0..<10 {
            try await Task.sleep(for: .milliseconds(200))
            #expect(model.displayedPDFPageIndices.contains(0))
        }
        if voiceOverSurface {
            func containsScrollView(_ view: UIView) -> Bool {
                view is UIScrollView || view.subviews.contains(where: containsScrollView)
            }
            #expect(!containsScrollView(controller.view))
        }
        model.jumpToPDFPage(3)
        try await Task.sleep(for: .milliseconds(500))
        #expect(model.displayedPDFPageIndices.contains(3))
        controller.rootView = PDFContainerView(
            viewModel: model, isPDFChromeVisible: .constant(true), isScrollDirectionHintVisible: false,
            accessibilitySurfaceOverride: voiceOverSurface
        ).frame(width: landscape ? 375 : 667, height: landscape ? 667 : 375)
            .environment(\.horizontalSizeClass, .compact)
        try await Task.sleep(for: .milliseconds(500))
        #expect(model.displayedPDFPageIndices.contains(3))
        #expect(model.loadDocument(from: pdfURL("L2R_Single")) == .loaded)
        try await Task.sleep(for: .milliseconds(500))
        #expect(model.displayedPDFPageIndices.contains(0))
        #expect(model.loadDocument(from: pdfURL(name)) == .loaded)
        for _ in 0..<10 {
            try await Task.sleep(for: .milliseconds(200))
            #expect(model.displayedPDFPageIndices.contains(0))
        }
    }
    @Test
    func switchingAccessibilitySurfacePreservesMiddlePage() async throws {
        for name in ["R2L_TwoPageLeft", "L2R_TwoPageLeft"] {
            let model = PDFViewerViewModel()
            #expect(model.loadDocument(from: pdfURL(name)) == .loaded)
            model.updateViewportSize(CGSize(width: 375, height: 667), horizontalSizeClass: .compact)
            model.jumpToPDFPage(3)
            func root(_ enabled: Bool, landscape: Bool) -> some View {
                PDFContainerView(
                    viewModel: model, isPDFChromeVisible: .constant(true),
                    isScrollDirectionHintVisible: false, accessibilitySurfaceOverride: enabled
                ).frame(width: landscape ? 667 : 375, height: landscape ? 375 : 667)
                    .environment(\.horizontalSizeClass, .compact)
            }
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            let controller = UIHostingController(rootView: root(false, landscape: false))
            window.rootViewController = controller
            window.isHidden = false
            defer { window.isHidden = true; window.rootViewController = nil }
            for landscape in [false, true, false] {
                for enabled in [true, false, true] {
                    controller.rootView = root(enabled, landscape: landscape)
                    try await Task.sleep(for: .milliseconds(500))
                    #expect(model.displayedPDFPageIndices.contains(3))
                    #expect(model.accessibilityFocusPageNumber == 4)
                }
            }
        }
    }

    @Test
    func rotationFocusRequestsPreserveEveryPDFPage() async throws {
        // Hosted view requests, not real VoiceOver focus or speech.
        for name in ["R2L_TwoPageLeft", "L2R_TwoPageLeft"] {
            for cover in [false, true] {
                let model = PDFViewerViewModel()
                #expect(model.loadDocument(from: pdfURL(name)) == .loaded)
                model.settings.isCoverPageEnabled = cover
                func root(_ landscape: Bool) -> some View {
                    PDFContainerView(viewModel: model, isPDFChromeVisible: .constant(true),
                                     isScrollDirectionHintVisible: false, accessibilitySurfaceOverride: true)
                        .frame(width: landscape ? 667 : 375, height: landscape ? 375 : 667)
                        .environment(\.horizontalSizeClass, .compact)
                }
                let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
                let window = UIWindow(windowScene: scene)
                let controller = UIHostingController(rootView: root(false))
                window.rootViewController = controller
                window.isHidden = false
                defer { window.isHidden = true; window.rootViewController = nil }
                func imageViews(_ view: UIView) -> [PDFPageAccessibilityImageView] {
                    (view as? PDFPageAccessibilityImageView).map { [$0] } ??
                        view.subviews.flatMap { imageViews($0) }
                }
                func waitForRequest(page: Int, after count: Int) async throws {
                    for _ in 0..<50 {
                        if model.accessibilityFocusRequestCount > count,
                           model.lastIssuedAccessibilityFocusRequest == model.accessibilityFocusRequest,
                           model.lastIssuedAccessibilityFocusRequest?.pageNumber == page {
                            let images = imageViews(controller.view)
                            let target = try #require(images.first { $0.pageNumber == page })
                            // Retained image stays first even when physically on the right.
                            #expect(images.first === target)
                            #expect(target.isAccessibilityElement)
                            #expect(target.accessibilityTraits.contains(.image))
                            #expect(target.window === window)
                            #expect(target.bounds.width > 0 && target.bounds.height > 0)
                            #expect(Set(images.map(\.pageNumber)) == Set(model.displayedPDFPageIndices.map { $0 + 1 }))
                            if model.displayedPDFPageIndices == [4, 3] {
                                let left = try #require(images.first { $0.pageNumber == 5 })
                                let right = try #require(images.first { $0.pageNumber == 4 })
                                #expect(left.convert(left.bounds, to: window).midX < right.convert(right.bounds, to: window).midX)
                            }
                            return
                        }
                        try await Task.sleep(for: .milliseconds(20))
                    }
                    Issue.record("No current hosted focus request for PDF \(page)")
                }
                try await waitForRequest(page: 1, after: 0)
                for page in 1...8 {
                    model.jumpToPDFPage(page - 1)
                    // The initial page already has a request; subsequent navigation must update it.
                    try await waitForRequest(page: page, after: 0)
                    let retainedImage = try #require(imageViews(controller.view).first { $0.pageNumber == page })
                    let portrait = model.accessibilityFocusRequest
                    var count = model.accessibilityFocusRequestCount
                    controller.rootView = root(true)
                    try await waitForRequest(page: page, after: count)
                    #expect(model.displayedPDFPageIndices.contains(page - 1))
                    #expect(model.accessibilityFocusPageNumber == page)
                    #expect(imageViews(controller.view).first { $0.pageNumber == page } === retainedImage)
                    let issuedCount = model.accessibilityFocusRequestCount
                    // Observe subsequent layout passes as well as the first request.
                    for _ in 0..<10 {
                        controller.view.setNeedsLayout()
                        controller.view.layoutIfNeeded()
                        try await Task.sleep(for: .milliseconds(20))
                        #expect(imageViews(controller.view).first { $0.pageNumber == page } === retainedImage)
                        #expect(model.accessibilityFocusRequestCount == issuedCount)
                        #expect(!model.accessibilityFocusObservation.departedAfterTarget)
                    }
                    #expect(model.accessibilityFocusRequest != portrait) // Same PDF, new layout identity.
                    if name == "R2L_TwoPageLeft", cover, page == 4 {
                        #expect(model.displayedPDFPageIndices == [4, 3]) // Left PDF5, right PDF4.
                        #expect(model.lastIssuedAccessibilityFocusRequest?.pageNumber == 4)
                        let neighbor = try #require(imageViews(controller.view).first { $0.pageNumber == 5 })
                        // Synthetic UIKit callbacks test our observer and non-interference;
                        // they do not simulate OS VoiceOver or prove audible speech.
                        retainedImage.accessibilityElementDidBecomeFocused()
                        neighbor.accessibilityElementDidBecomeFocused()
                        retainedImage.accessibilityElementDidBecomeFocused()
                        #expect(model.accessibilityFocusObservation.pages == [4, 5, 4])
                        #expect(model.accessibilityFocusObservation.departedAfterTarget)
                        neighbor.accessibilityElementDidBecomeFocused()
                        controller.view.setNeedsLayout()
                        controller.view.layoutIfNeeded()
                        try await Task.sleep(for: .milliseconds(200))
                        #expect(model.accessibilityFocusRequestCount == issuedCount)
                    }
                    count = model.accessibilityFocusRequestCount
                    controller.rootView = root(false)
                    try await waitForRequest(page: page, after: count)
                    #expect(model.displayedPDFPageIndices == [page - 1])
                    #expect(imageViews(controller.view).first { $0.pageNumber == page } === retainedImage)
                }
                model.jumpToPDFPage(3)
                try await waitForRequest(page: 4, after: 0)
                let beforeRotationCount = model.accessibilityFocusRequestCount
                controller.rootView = root(true)
                try await waitForRequest(page: 4, after: beforeRotationCount)
                let identity = model.pagerIdentity
                let next: Edge = identity.isRightToLeft ? .trailing : .leading
                let previous: Edge = identity.isRightToLeft ? .leading : .trailing
                for edge in [next, previous] {
                    let count = model.accessibilityFocusRequestCount
                    model.scrollAccessibilityPage(toward: edge, pager: identity)
                    let expected = try #require(model.displayedPDFPageIndices.min()) + 1
                    try await waitForRequest(page: expected, after: count)
                    #expect(model.lastIssuedAccessibilityFocusRequest?.pageNumber == expected)
                }
            }
        }
    }

    @Test
    func interveningFocusCancelsQueuedRequestWithoutRetry() async throws {
        let model = PDFViewerViewModel()
        #expect(model.loadDocument(from: pdfURL("R2L_TwoPageLeft")) == .loaded)
        model.updateViewportSize(CGSize(width: 667, height: 375), horizontalSizeClass: .compact)
        model.jumpToPDFPage(3)
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        let size = CGSize(width: 200, height: 300)
        let image = PDFPageAccessibilityImageView(frame: CGRect(origin: .zero, size: size))
        controller.view.addSubview(image)
        image.configure(pageNumber: 4, displaySize: size, focus: PDFPageFocusContext(
            model: model, request: model.accessibilityFocusRequest, isViewportReady: true))
        image.layoutIfNeeded() // Enqueue, but do not drain the main queue yet.
        model.recordAccessibilityImageFocus(event: "focus.elementFocused", page: 5)
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.accessibilityFocusRequestCount == 0)
        for _ in 0..<3 {
            image.setNeedsLayout()
            image.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(20))
            #expect(model.accessibilityFocusRequestCount == 0)
        }
    }

    @Test
    func stalePagerCallbacksCannotOverwriteNewDocumentOrGrouping() throws {
        let model = PDFViewerViewModel()
        #expect(model.loadDocument(from: pdfURL("R2L_TwoPageLeft")) == .loaded)
        let original = model.pagerIdentity
        model.updateViewportSize(CGSize(width: 375, height: 667), horizontalSizeClass: .compact)
        model[pager: original] = 6 // A late selection from the old spread pager.
        #expect(model.displayedPDFPageIndices == [0])
        let portrait = model.pagerIdentity
        model.jumpToPDFPage(3)
        model.updateViewportSize(CGSize(width: 667, height: 375), horizontalSizeClass: .compact)
        model[pager: portrait] = 7
        #expect(model.displayedPDFPageIndices.contains(3))
        let spread = model.pagerIdentity
        model[pager: spread] = model[pager: spread] // Redundant callback must keep exact anchor.
        model.updateViewportSize(CGSize(width: 375, height: 667), horizontalSizeClass: .compact)
        #expect(model.displayedPDFPageIndices == [3])
        let previousDocument = model.pagerIdentity
        #expect(model.loadDocument(from: pdfURL("R2L_Single")) == .loaded)
        model[pager: previousDocument] = 7
        #expect(model.displayedPDFPageIndices == [0])
        model[pager: model.pagerIdentity] = 1
        #expect(model.displayedPDFPageIndices == [1])
        model[pager: model.pagerIdentity] = 0
        #expect(model.displayedPDFPageIndices == [0])
    }

    @Test
    func savedPDFPageSurvivesDifferentLaunchLayout() throws {
        for name in ["R2L_TwoPageLeft", "R2L_TwoPageRight", "L2R_TwoPageLeft"] {
            for portrait in [false, true] {
                try checkRestoration(name, launchInPortrait: portrait)
            }
        }
    }

    private func checkRestoration(_ name: String, launchInPortrait: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sessionURL = directory.appendingPathComponent("session.json")
        let model = PDFViewerViewModel(sessionURL: sessionURL)
        #expect(model.loadDocument(from: pdfURL(name)) == .loaded)
        model.updateViewportSize(CGSize(width: 375, height: 667), horizontalSizeClass: .compact)
        model.jumpToPDFPage(3)
        model.updateViewportSize(CGSize(width: 667, height: 375), horizontalSizeClass: .compact)
        model.saveReadingSession()
        let restored = PDFViewerViewModel(sessionURL: sessionURL)
        if launchInPortrait {
            restored.updateViewportSize(CGSize(width: 375, height: 667), horizontalSizeClass: .compact)
        }
        #expect(restored.loadDocument(from: try #require(restored.documentURLForRestoration())) == .loaded)
        #expect(restored.displayedPDFPageIndices.contains(3))
        restored.updateViewportSize(CGSize(width: 375, height: 667), horizontalSizeClass: .compact)
        #expect(restored.displayedPDFPageIndices == [3])
    }

    @Test
    func legacyGroupOnlySessionStillRestores() throws {
        let sessionURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: sessionURL) }
        let store = ReadingSessionStore(fileURL: sessionURL)
        try store.save(ReadingSessionStore.State(
            bookmark: try store.makeBookmark(for: pdfURL("R2L_TwoPageLeft")),
            pageIndex: 2, searchQuery: "", isSpread: true, isCover: false, isRightToLeft: true
        ))
        let model = PDFViewerViewModel(sessionURL: sessionURL)
        #expect(model.loadDocument(from: try #require(model.documentURLForRestoration())) == .loaded)
        #expect(model.currentPageIndex == 2)
        #expect(model.displayedPDFPageIndices == [5, 4])
        model.updateViewportSize(CGSize(width: 375, height: 667), horizontalSizeClass: .compact)
        #expect(model.displayedPDFPageIndices == [4])
    }

    @Test
    func candidateEdgesMatchPhysicalSwipeAcceptancePages() throws {
        // Acceptance pages come from the owner's physical-finger specification.
        // Edge inputs are the NEW candidate mapping inferred from the report that
        // both bindings were reversed. These are NOT measured gesture/Edge pairs.
        // No physical gesture or OS accessibility delivery is exercised here.
        let cases: [(fixture: String, fingerMotion: String, candidateEdge: Edge, expectedPDF: Int)] = [
            ("R2L_Single", "left to right", .trailing, 5),
            ("R2L_Single", "right to left", .leading, 3),
            ("L2R_Single", "left to right", .trailing, 3),
            ("L2R_Single", "right to left", .leading, 5)
        ]
        for testCase in cases {
            let model = PDFViewerViewModel()
            #expect(model.loadDocument(from: pdfURL(testCase.fixture)) == .loaded)
            model.updateViewportSize(CGSize(width: 375, height: 667), horizontalSizeClass: .compact)
            model.jumpToPDFPage(3) // Each independent acceptance case starts at PDF 4.
            let request = model.makeAccessibilityScrollRequest(
                toward: testCase.candidateEdge, pager: model.pagerIdentity
            )
            #expect(model.applyAccessibilityScroll(request))
            #expect(model.displayedPDFPageIndices == [testCase.expectedPDF - 1],
                    "Candidate for physical motion: \(testCase.fingerMotion)")
            #expect(model.accessibilityFocusPageNumber == testCase.expectedPDF)
        }
    }

    @Test
    func accessibilityRequestsRejectDuplicatesAndStaleSelections() throws {
        for name in ["R2L_Single", "L2R_Single", "R2L_TwoPageLeft", "R2L_TwoPageRight", "L2R_TwoPageLeft"] {
            let model = PDFViewerViewModel()
            #expect(model.loadDocument(from: pdfURL(name)) == .loaded)
            let identity = model.pagerIdentity
            let next: Edge = identity.isRightToLeft ? .trailing : .leading
            let previous: Edge = identity.isRightToLeft ? .leading : .trailing
            // The action closure retains only the pager, as the stable surface does.
            let retainedAction = { (edge: Edge) in
                model.scrollAccessibilityPage(toward: edge, pager: identity)
            }
            let first = model.makeAccessibilityScrollRequest(toward: next, pager: identity)
            let stale = model.makeAccessibilityScrollRequest(toward: next, pager: identity)
            #expect(model.applyAccessibilityScroll(first))
            #expect(!model.applyAccessibilityScroll(first))
            #expect(!model.applyAccessibilityScroll(stale))
            #expect(model.currentPageIndex == 1)
            retainedAction(next)
            #expect(model.currentPageIndex == 2)
            retainedAction(previous)
            #expect(model.currentPageIndex == 1)
            // A selection that leaves and returns is still a new selection.
            let oldSelection = model.makeAccessibilityScrollRequest(toward: next, pager: identity)
            retainedAction(next)
            retainedAction(previous)
            #expect(!model.applyAccessibilityScroll(oldSelection))
            #expect(model.currentPageIndex == 1)
            model.jumpToPDFPage(0)
            let boundary = model.makeAccessibilityScrollRequest(toward: previous, pager: identity)
            #expect(!model.applyAccessibilityScroll(boundary))
            #expect(!model.applyAccessibilityScroll(boundary))
            retainedAction(next)
            #expect(model.currentPageIndex == 1)
        }
    }

    @Test
    func queuedAccessibilityRequestRejectsChangedLayoutAndDocument() throws {
        let model = PDFViewerViewModel()
        #expect(model.loadDocument(from: pdfURL("R2L_TwoPageLeft")) == .loaded)
        model.updateViewportSize(CGSize(width: 375, height: 667), horizontalSizeClass: .compact)
        let portrait = model.makeAccessibilityScrollRequest(toward: .leading, pager: model.pagerIdentity)
        model.updateViewportSize(CGSize(width: 667, height: 375), horizontalSizeClass: .compact)
        #expect(!model.applyAccessibilityScroll(portrait))
        // Returning to the original arrangement must not revive a queued request.
        let landscape = model.makeAccessibilityScrollRequest(toward: .leading, pager: model.pagerIdentity)
        model.updateViewportSize(CGSize(width: 375, height: 667), horizontalSizeClass: .compact)
        model.updateViewportSize(CGSize(width: 667, height: 375), horizontalSizeClass: .compact)
        #expect(!model.applyAccessibilityScroll(landscape))
        let oldDocument = model.makeAccessibilityScrollRequest(toward: .leading, pager: model.pagerIdentity)
        #expect(model.loadDocument(from: pdfURL("L2R_Single")) == .loaded)
        #expect(!model.applyAccessibilityScroll(oldDocument))
        #expect(model.currentPageIndex == 0)
    }

    @Test(arguments: [false, true])
    func accessibilityScrollDirectionsBoundariesAndRotation(cover: Bool) throws {
        for name in ["R2L_Single", "L2R_Single", "R2L_TwoPageLeft", "R2L_TwoPageRight", "L2R_TwoPageLeft"] {
            for landscape in [false, true] {
                let model = PDFViewerViewModel()
                #expect(model.loadDocument(from: pdfURL(name)) == .loaded)
                model.settings.isCoverPageEnabled = cover
                model.updateViewportSize(CGSize(width: landscape ? 667 : 375, height: landscape ? 375 : 667), horizontalSizeClass: .compact)
                let identity = model.pagerIdentity
                let next: Edge = identity.isRightToLeft ? .trailing : .leading
                let previous: Edge = identity.isRightToLeft ? .leading : .trailing
                model.scrollAccessibilityPage(toward: previous, pager: identity)
                #expect(model.currentPageIndex == 0)
                for (edge, expectedGroup) in [(next, 1), (next, 2), (previous, 1), (previous, 0), (next, 1)] {
                    model.scrollAccessibilityPage(toward: edge, pager: identity)
                    #expect(model.currentPageIndex == expectedGroup)
                }
                model.jumpToPDFPage(0)
                for index in 1..<model.pageGroups.count {
                    model.scrollAccessibilityPage(toward: next, pager: identity)
                    #expect(model.currentPageIndex == index)
                    #expect(model.displayedPDFPageIndices == model.pageGroups[index].pageIndices)
                    #expect(model.accessibilityFocusPageNumber == model.pageGroups[index].pageIndices.min().map { $0 + 1 })
                    model[pager: identity] = model.pageGroups[index].id
                    #expect(model.currentPageIndex == index) // Same selection is not a second turn.
                }
                model.scrollAccessibilityPage(toward: next, pager: identity)
                #expect(model.currentPageIndex == model.pageGroups.count - 1)
                for index in (0..<(model.pageGroups.count - 1)).reversed() {
                    model.scrollAccessibilityPage(toward: previous, pager: identity)
                    #expect(model.currentPageIndex == index)
                }
                model.scrollAccessibilityPage(toward: .top, pager: identity)
                model.scrollAccessibilityPage(toward: .bottom, pager: identity)
                #expect(model.currentPageIndex == 0)
                model.jumpToPDFPage(3)
                model.updateViewportSize(CGSize(width: landscape ? 375 : 667, height: landscape ? 667 : 375), horizontalSizeClass: .compact)
                #expect(model.displayedPDFPageIndices.contains(3))
                #expect(model.accessibilityFocusPageNumber == 4)
                if model.pagerIdentity != identity {
                    model.scrollAccessibilityPage(toward: next, pager: identity)
                    #expect(model.displayedPDFPageIndices.contains(3))
                }
                let current = model.pagerIdentity
                let before = model.currentPageIndex
                model.scrollAccessibilityPage(toward: next, pager: current)
                #expect(model.currentPageIndex == min(before + 1, model.pageGroups.count - 1))
                #expect(model.loadDocument(from: pdfURL("R2L_Single")) == .loaded)
                model.scrollAccessibilityPage(toward: next, pager: current)
                #expect(model.displayedPDFPageIndices.contains(0))
            }
        }
    }


}
