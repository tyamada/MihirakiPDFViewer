//
// PDFPageGroupingTests.swift
// MihirakiPDFViewerTests
//
// Copyright 2026 Takuma Yamada.
//

import SwiftUI
import Testing
@testable import MihirakiPDFViewer

struct PDFPageGroupingTests {
    @Test
    func emptyDocumentProducesNoGroups() {
        #expect(groups(pageCount: 0) == [])
    }

    @Test
    func spreadGroupsPagesInReadingOrder() {
        #expect(groups(pageCount: 5, spread: true) == [[0, 1], [2, 3], [4]])
        #expect(
            groups(pageCount: 5, spread: true, direction: .rightToLeft)
                == [[1, 0], [3, 2], [4]]
        )
    }

    @Test
    func coverRemainsSeparateFromFollowingSpread() {
        #expect(groups(pageCount: 4, spread: true, cover: true) == [[0], [1, 2], [3]])
    }

    @Test
    func portraitPreferenceTemporarilyDisablesSpread() {
        #expect(
            groups(
                pageCount: 4,
                spread: true,
                singlePageInPortrait: true,
                isPortrait: true
            ) == [[0], [1], [2], [3]]
        )
        #expect(
            groups(
                pageCount: 4,
                spread: true,
                singlePageInPortrait: true,
                isPortrait: false
            ) == [[0, 1], [2, 3]]
        )
    }

    @Test
    func regularWidthPortraitHonorsSinglePagePreference() {
        #expect(
            groups(
                pageCount: 4,
                spread: true,
                singlePageInPortrait: true,
                isPortrait: true,
                horizontalSizeClass: .regular
            ) == [[0], [1], [2], [3]]
        )
    }

    @Test
    func portraitOptionRespectsAllWidthClassesAndReadingDirections() {
        let widthClasses: [UserInterfaceSizeClass?] = [nil, .compact, .regular]
        for widthClass in widthClasses {
            for direction in [LayoutDirection.leftToRight, .rightToLeft] {
                for cover in [false, true] {
                    let portrait = groups(pageCount: 8, spread: true, cover: cover,
                        direction: direction, singlePageInPortrait: true,
                        isPortrait: true, horizontalSizeClass: widthClass)
                    #expect(portrait == (0..<8).map { [$0] })
                    let portraitOptionOff = groups(pageCount: 8, spread: true,
                        cover: cover, direction: direction, singlePageInPortrait: false,
                        isPortrait: true, horizontalSizeClass: widthClass)
                    let landscape = groups(pageCount: 8, spread: true, cover: cover,
                        direction: direction, singlePageInPortrait: true,
                        isPortrait: false, horizontalSizeClass: widthClass)
                    #expect(portraitOptionOff == landscape)
                    #expect(landscape.contains { $0.count == 2 })
                }
            }
        }
    }

    @Test
    func locatesGroupContainingDisplayedPage() {
        let groups = [[0], [2, 1], [4, 3]]

        #expect(PDFPageGrouping.groupIndex(containing: 3, in: groups) == 2)
        #expect(PDFPageGrouping.groupIndex(containing: 9, in: groups) == nil)
    }

    private func groups(
        pageCount: Int,
        spread: Bool = false,
        cover: Bool = false,
        direction: LayoutDirection = .leftToRight,
        singlePageInPortrait: Bool = false,
        isPortrait: Bool = false,
        horizontalSizeClass: UserInterfaceSizeClass? = nil
    ) -> [[Int]] {
        PDFPageGrouping.pageIndexGroups(
            totalPageCount: pageCount,
            settings: PDFViewerSettings(
                isSpreadViewEnabled: spread,
                isCoverPageEnabled: cover,
                layoutDirection: direction,
                isSinglePageInPortraitEnabled: singlePageInPortrait
            ),
            viewportLayout: PDFViewportLayout(
                size: isPortrait
                    ? CGSize(width: 600, height: 800)
                    : CGSize(width: 800, height: 600),
                horizontalSizeClass: horizontalSizeClass
            )
        )
    }
}


struct PDFFocusDeliveryTests {
    private let size = CGSize(width: 240, height: 360)

    @Test func waitsForMountedTargetAndMatchingLayout() throws {
        var state = PDFFocusDeliveryState<Int>()
        state.update(request: 4, expectedSize: size, isTarget: true, viewportReady: false)
        let observed106 = state.enqueue(current: 4, mounted: true, bounds: size, scale: 2) == nil
        #expect(observed106)
        state.update(request: 4, expectedSize: size, isTarget: true, viewportReady: true)
        let observed108 = state.enqueue(current: 4, mounted: false, bounds: size, scale: 2) == nil
        #expect(observed108)
        let observed109 = state.enqueue(current: 4, mounted: true, bounds: .zero, scale: 2) == nil
        #expect(observed109)
        let observed110 = state.enqueue(current: 4, mounted: true, bounds: CGSize(width: 360, height: 240), scale: 2) == nil
        #expect(observed110)
        let queued111 = state.enqueue(current: 4, mounted: true, bounds: size, scale: 2)
        let ticket = try #require(queued111)
        let observed112 = state.consume(ticket, current: 4, mounted: true, bounds: size, scale: 2)
        #expect(observed112)
        let observed113 = !state.consume(ticket, current: 4, mounted: true, bounds: size, scale: 2)
        #expect(observed113)
        let observed114 = state.enqueue(current: 4, mounted: true, bounds: size, scale: 2) == nil
        #expect(observed114)
    }

    @Test func leftNeighborCannotIssueRetainedRightPageFocus() throws {
        var left = PDFFocusDeliveryState<Int>()
        var right = PDFFocusDeliveryState<Int>()
        left.update(request: 4, expectedSize: size, isTarget: false, viewportReady: true)
        right.update(request: 4, expectedSize: size, isTarget: true, viewportReady: true)
        let observed122 = left.enqueue(current: 4, mounted: true, bounds: size, scale: 2) == nil
        #expect(observed122)
        let queued123 = right.enqueue(current: 4, mounted: true, bounds: size, scale: 2)
        let ticket = try #require(queued123)
        let observed124 = right.consume(ticket, current: 4, mounted: true, bounds: size, scale: 2)
        #expect(observed124)
    }

    @Test func staleCompletionAndDetachedOrChangedSelectionAreRejected() throws {
        var state = PDFFocusDeliveryState<Int>()
        state.update(request: 4, expectedSize: size, isTarget: true, viewportReady: true)
        let queued130 = state.enqueue(current: 4, mounted: true, bounds: size, scale: 2)
        let old = try #require(queued130)
        state.update(request: 5, expectedSize: size, isTarget: true, viewportReady: true)
        let observed132 = !state.consume(old, current: 5, mounted: true, bounds: size, scale: 2)
        #expect(observed132)
        let queued133 = state.enqueue(current: 5, mounted: true, bounds: size, scale: 2)
        let changed = try #require(queued133)
        let observed134 = !state.consume(changed, current: 6, mounted: true, bounds: size, scale: 2)
        #expect(observed134)
        let queued135 = state.enqueue(current: 5, mounted: true, bounds: size, scale: 2)
        let detached = try #require(queued135)
        let observed136 = !state.consume(detached, current: 5, mounted: false, bounds: size, scale: 2)
        #expect(observed136)
        let queued137 = state.enqueue(current: 5, mounted: true, bounds: size, scale: 2)
        let cancelled = try #require(queued137)
        state.invalidate()
        let observed139 = !state.consume(cancelled, current: 5, mounted: true, bounds: size, scale: 2)
        #expect(observed139)
    }
}

struct PDFRotationFocusRegressionTests {
    @Test func departureRemainsFailureAfterReturningToTarget() {
        var observation = PDFFocusObservation()
        observation.begin(target: 4)
        observation.acquired(4)
        #expect(!observation.departedAfterTarget)
        observation.acquired(5)
        #expect(observation.departedAfterTarget)
        observation.acquired(4)
        #expect(observation.pages == [4, 5, 4])
        #expect(observation.departedAfterTarget)
        observation.begin(target: 6)
        #expect(!observation.departedAfterTarget)
        #expect(observation.pages.isEmpty)
    }

    @Test func layoutReadinessChangesDoNotReplayCompletedRequest() throws {
        var state = PDFFocusDeliveryState<Int>()
        let size = CGSize(width: 200, height: 300)
        state.update(request: 4, expectedSize: size, isTarget: true, viewportReady: true)
        let queued = state.enqueue(current: 4, mounted: true, bounds: size, scale: 2)
        let ticket = try #require(queued)
        let consumed = state.consume(ticket, current: 4, mounted: true, bounds: size, scale: 2)
        #expect(consumed)
        for ready in [false, true, false, true] {
            state.update(request: 4, expectedSize: size, isTarget: true, viewportReady: ready)
            let next = state.enqueue(current: 4, mounted: true, bounds: size, scale: 2)
            #expect(next == nil)
        }
        state.update(request: 5, expectedSize: size, isTarget: true, viewportReady: true)
        let nextPage = state.enqueue(current: 5, mounted: true, bounds: size, scale: 2)
        #expect(nextPage != nil)
    }

    @Test func stablePageGeometryPreservesSpreadAndBlankPlacement() {
        let page = CGSize(width: 200, height: 300)
        for container in [CGSize(width: 667, height: 375), CGSize(width: 300, height: 600)] {
            let frames = PDFPageFrames.frames(pageSizes: [page, page], container: container,
                spread: true, isFirst: false, isLast: false, isRightToLeft: true)
            #expect(frames.count == 2)
            #expect(abs(frames[0].maxX - frames[1].minX) < 0.001)
            #expect(frames[0].midX < frames[1].midX)
            #expect(frames.allSatisfy { $0.minX >= 0 && $0.maxX <= container.width && $0.height <= container.height })
            for rtl in [false, true] {
                let last = PDFPageFrames.frames(pageSizes: [page], container: container,
                    spread: true, isFirst: false, isLast: true, isRightToLeft: rtl)[0]
                #expect(rtl ? last.midX > container.width / 2 : last.midX < container.width / 2)
                let cover = PDFPageFrames.frames(pageSizes: [page], container: container,
                    spread: true, isFirst: true, isLast: false, isRightToLeft: rtl)[0]
                #expect(abs(cover.midX - container.width / 2) < 0.001)
            }
        }
    }
}


struct PDFPageAccessibilityOrderTests {
    @Test(arguments: [[4, 3], [3, 4]])
    func rotationRetainsEitherPageBeforeItsNewNeighbor(physicalOrder: [Int]) {
        for retained in physicalOrder {
            let portrait = PDFPageAccessibilityOrder.indices([retained], retaining: retained)
            let spread = PDFPageAccessibilityOrder.indices(physicalOrder, retaining: retained)
            #expect(portrait.first == spread.first)
            #expect(spread.first == retained)
            #expect(Set(spread) == Set(physicalOrder))
            #expect(PDFPageAccessibilityOrder.priority(of: retained, in: spread) >
                    PDFPageAccessibilityOrder.priority(of: spread[1], in: spread))
            #expect(PDFPageAccessibilityOrder.indices([retained], retaining: retained) == portrait)
        }
    }

    @Test func missingOrAbsentTargetDoesNotInventPages() {
        #expect(PDFPageAccessibilityOrder.indices([], retaining: 3).isEmpty)
        #expect(PDFPageAccessibilityOrder.indices([4, 3], retaining: nil) == [4, 3])
        #expect(PDFPageAccessibilityOrder.indices([4, 3], retaining: 99) == [4, 3])
        #expect(PDFPageAccessibilityOrder.priority(of: 99, in: [4, 3]) == 0)
    }

    @Test func nextSpreadAndDocumentChangeUseOnlyTheirOwnPages() {
        #expect(PDFPageAccessibilityOrder.indices([6, 5], retaining: 5) == [5, 6])
        #expect(PDFPageAccessibilityOrder.indices([0], retaining: 0) == [0])
        #expect(PDFPageAccessibilityOrder.indices([7], retaining: 7) == [7])
    }
}

struct PDFFocusCompletionDecisionTests {
    @Test func systemRestoredTargetDoesNotReceiveDuplicateNotification() {
        let target = NSObject(), old = NSObject()
        #expect(PDFFocusCompletionDecision.decide(target: ObjectIdentifier(target),
            captured: ObjectIdentifier(old), current: ObjectIdentifier(target),
            capturedGeneration: 2, currentGeneration: 3) == .alreadyFocused)
        #expect(PDFFocusCompletionDecision.decide(target: ObjectIdentifier(target),
            captured: ObjectIdentifier(target), current: ObjectIdentifier(target),
            capturedGeneration: 2, currentGeneration: 2) == .alreadyFocused)
    }
    @Test func unrelatedFocusAndTransientLossDoNotTriggerRestorationLoop() {
        let target = NSObject(), other = NSObject()
        for current in [ObjectIdentifier(other), nil] {
            #expect(PDFFocusCompletionDecision.decide(target: ObjectIdentifier(target),
                captured: ObjectIdentifier(target), current: current,
                capturedGeneration: 2, currentGeneration: 3) == .superseded)
        }
        #expect(PDFFocusCompletionDecision.decide(target: ObjectIdentifier(target),
            captured: nil, current: nil, capturedGeneration: 2,
            currentGeneration: 2) == .send)
    }
}
