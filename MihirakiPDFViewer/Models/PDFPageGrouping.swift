//
// PDFPageGrouping.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import SwiftUI

struct PDFViewportLayout: Equatable {
    let size: CGSize
    let horizontalSizeClass: UserInterfaceSizeClass?

    var isPortrait: Bool {
        size.height >= size.width
    }

    var prefersSinglePage: Bool {
        // The portrait option applies to iPad regular-width viewports as well.
        isPortrait
    }
}

/// Computes page groupings independently of PDFKit objects.
struct PDFPageGrouping {
    static func isSpreadEnabled(
        settings: PDFViewerSettings,
        viewportLayout: PDFViewportLayout
    ) -> Bool {
        settings.isSpreadViewEnabled
            && !(viewportLayout.prefersSinglePage && settings.isSinglePageInPortraitEnabled)
    }

    static func pageIndexGroups(
        totalPageCount: Int,
        settings: PDFViewerSettings,
        viewportLayout: PDFViewportLayout
    ) -> [[Int]] {
        guard totalPageCount > 0 else { return [] }

        var groups: [[Int]] = []
        var currentIndex = 0

        if settings.isCoverPageEnabled {
            groups.append([currentIndex])
            currentIndex += 1
        }

        if isSpreadEnabled(settings: settings, viewportLayout: viewportLayout) {
            while currentIndex < totalPageCount {
                var pageIndices = [currentIndex]
                if currentIndex + 1 < totalPageCount {
                    pageIndices.append(currentIndex + 1)
                }
                if settings.layoutDirection == .rightToLeft, pageIndices.count == 2 {
                    pageIndices.reverse()
                }
                groups.append(pageIndices)
                currentIndex += 2
            }
        } else {
            while currentIndex < totalPageCount {
                groups.append([currentIndex])
                currentIndex += 1
            }
        }

        return groups
    }

    static func groupIndex(containing pageIndex: Int, in groups: [[Int]]) -> Int? {
        groups.firstIndex { $0.contains(pageIndex) }
    }
}

/// Geometry shared by the stable accessibility page collection. Order is physical
/// left-to-right; a final unpaired page keeps the existing blank-page placement.
enum PDFPageFrames {
    static func frames(pageSizes: [CGSize], container: CGSize, spread: Bool,
                       isFirst: Bool, isLast: Bool, isRightToLeft: Bool) -> [CGRect] {
        guard let first = pageSizes.first, first.width > 0, first.height > 0 else { return [] }
        if pageSizes.count == 1 {
            let usesSpread = spread && (isFirst || isLast)
            let scale = min(container.width / (first.width * (usesSpread ? 2 : 1)),
                            container.height / first.height)
            let size = CGSize(width: first.width * scale, height: first.height * scale)
            var x = (container.width - size.width) / 2
            if usesSpread && isLast { x += (isRightToLeft ? 1 : -1) * size.width / 2 }
            return [CGRect(origin: CGPoint(x: x, y: (container.height - size.height) / 2), size: size)]
        }
        let ratios = pageSizes.map { $0.width / $0.height }
        let height = min(container.height, container.width / ratios.reduce(0, +))
        let widths = ratios.map { $0 * height }
        var x = (container.width - widths.reduce(0, +)) / 2
        return widths.map { width in
            defer { x += width }
            return CGRect(x: x, y: (container.height - height) / 2, width: width, height: height)
        }
    }
}

/// Observes the entire callback sequence for a request, without changing focus.
/// A later return to the target must not erase an intervening departure.
struct PDFFocusObservation {
    private(set) var target: Int?
    private(set) var pages: [Int] = []
    private(set) var departedAfterTarget = false
    private var acquiredTarget = false

    mutating func begin(target: Int?) {
        self.target = target
        pages = []
        departedAfterTarget = false
        acquiredTarget = false
    }

    mutating func acquired(_ page: Int) {
        if acquiredTarget, page != target {
            departedAfterTarget = true
        }
        acquiredTarget = acquiredTarget || page == target
        if pages.count == 64 { pages.removeFirst() }
        pages.append(page)
    }
}

/// Cancels obsolete layout callbacks and consumes each ready focus request once.
/// Readiness is about the actual mounted image, not merely a model page number.
struct PDFFocusDeliveryState<Request: Equatable> {
    private(set) var generation = 0
    private var request: Request?
    private var expectedSize = CGSize.zero
    private var isTarget = false
    private var viewportReady = false
    private var queued: Int?
    private var issued: Int?
    private var completedRequest: Request?

    mutating func update(request: Request, expectedSize: CGSize, isTarget: Bool, viewportReady: Bool) {
        if self.request != request || self.expectedSize != expectedSize ||
            self.isTarget != isTarget || self.viewportReady != viewportReady {
            invalidate()
        }
        self.request = request
        self.expectedSize = expectedSize
        self.isTarget = isTarget
        self.viewportReady = viewportReady
    }

    mutating func invalidate() {
        generation += 1
        request = nil
        queued = nil
        issued = nil
    }

    private func ready(current: Request, mounted: Bool, bounds: CGSize, scale: CGFloat) -> Bool {
        let tolerance = 1 / max(scale, 1)
        return request == current && isTarget && viewportReady && mounted &&
            bounds.width > 0 && bounds.height > 0 &&
            abs(bounds.width - expectedSize.width) <= tolerance &&
            abs(bounds.height - expectedSize.height) <= tolerance
    }

    mutating func enqueue(current: Request, mounted: Bool, bounds: CGSize, scale: CGFloat) -> Int? {
        guard completedRequest != current, queued != generation, issued != generation,
              ready(current: current, mounted: mounted, bounds: bounds, scale: scale) else { return nil }
        queued = generation
        return generation
    }

    mutating func consume(_ ticket: Int, current: Request, mounted: Bool, bounds: CGSize, scale: CGFloat) -> Bool {
        guard ticket == generation, queued == ticket else { return false }
        queued = nil
        guard issued != ticket,
              ready(current: current, mounted: mounted, bounds: bounds, scale: scale) else { return false }
        issued = ticket
        completedRequest = current
        return true
    }
}


/// Accessibility order is independent of the physical left/right page frames.
/// Keep the retained page first when a rotation inserts a neighboring page, so
/// automatic restoration and our explicit request agree on the same default.
enum PDFPageAccessibilityOrder {
    nonisolated static func indices(_ displayed: [Int], retaining page: Int?) -> [Int] {
        guard let page, displayed.contains(page) else { return displayed }
        return [page] + displayed.filter { $0 != page }
    }

    nonisolated static func priority(of page: Int, in ordered: [Int]) -> Double {
        guard let offset = ordered.firstIndex(of: page) else { return 0 }
        return Double(ordered.count - offset)
    }
}

/// Avoid a redundant layout notification when UIKit has already restored the
/// exact image. Never redirect an intervening focus on another element.
enum PDFFocusCompletionDecision: Equatable {
    case send, alreadyFocused, superseded
    static func decide(target: ObjectIdentifier, captured: ObjectIdentifier?,
                       current: ObjectIdentifier?, capturedGeneration: Int,
                       currentGeneration: Int) -> Self {
        if current == target { return .alreadyFocused }
        guard capturedGeneration == currentGeneration, captured == current else {
            return .superseded
        }
        return .send
    }
}
