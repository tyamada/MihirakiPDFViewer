//
// PDFReaderView.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import PDFKit
import SwiftUI

/// PDF表示のコンテナビュー
struct PDFContainerView: View {
    @Bindable var viewModel: PDFViewerViewModel
    @Binding var isPDFChromeVisible: Bool
    let isScrollDirectionHintVisible: Bool
    #if DEBUG
    // Host tests can render this branch without claiming VoiceOver is running.
    var accessibilitySurfaceOverride: Bool? = nil
    #endif
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverEnabled


    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var contentOffset: CGSize = .zero
    @State private var lastContentOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            containerView(size: geometry.size)
                .onAppear {
                    updateViewport(size: geometry.size)
                }
                .onChange(of: geometry.size) { _, newSize in
                    updateViewport(size: newSize)
                }
                .onChange(of: horizontalSizeClass) { _, _ in
                    updateViewport(size: geometry.size)
                }
        }
    }

    private func updateViewport(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let previousSize = viewModel.viewportLayout.size
        let wasSpread = viewModel.isSpreadLayoutEnabled
        viewModel.updateViewportSize(
            size,
            horizontalSizeClass: horizontalSizeClass
        )
        if wasSpread != viewModel.isSpreadLayoutEnabled {
            // A different page arrangement has no equivalent zoomed viewport.
            resetZoomScale()
        } else if previousSize != size {
            contentOffset = PDFViewportZoom.resizedOffset(
                contentOffset,
                from: previousSize,
                to: size,
                zoomScale: zoomScale
            )
            lastContentOffset = contentOffset
            lastZoomScale = zoomScale
        }
    }

    @ViewBuilder
    private func containerView(size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            readerSurface(size: size)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .scaleEffect(zoomScale)
                .offset(contentOffset)
                .simultaneousGesture(magnificationGesture)
                // VoiceOver activation is handled by the focused UIKit page.
                // Do not also deliver a synthetic touch to the ordinary tap toggle.
                .simultaneousGesture(tapGesture, including: usesAccessibilitySurface ? .none : .all)
                .simultaneousGesture(longPressDragGesture)

            if isScrollDirectionHintVisible {
                ScrollDirectionHintView(layoutDirection: viewModel.settings.layoutDirection)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: viewModel.searchQuery) { _, query in
            viewModel.performSearch(query: query)
        }
        .onChange(of: viewModel.document?.id) { _, _ in
            PDFPageImageCache.shared.removeAllImages()
            resetZoomScale()
        }
    }

    @ViewBuilder
    private func readerSurface(size: CGSize) -> some View {
        if usesAccessibilitySurface {
            accessibilitySurface(size: size)
        } else {
            tabView(size: size)
                .id(viewModel.pagerIdentity)
        }
    }

    private var usesAccessibilitySurface: Bool {
        #if DEBUG
        if let accessibilitySurfaceOverride { return accessibilitySurfaceOverride }
        #endif
        return isVoiceOverEnabled
    }

    // A single, unmirrored scroll owner. Offscreen TabView pages cannot retain
    // a stale scroll closure or perform an additional default accessibility turn.
    private func accessibilitySurface(size: CGSize) -> some View {
        let identity = viewModel.pagerIdentity
        let focusRequest = viewModel.accessibilityFocusRequest
        return ZStack {
            if let item = orderedPageGroups.first(where: { $0.index == viewModel.currentPageIndex }) {
                accessibilityPages(item, size: size)
                    .id(identity.documentID)
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("accessibilityReaderSurface")
        .environment(\.pdfChromeVisibility, $isPDFChromeVisible)
        .accessibilityScrollAction { edge in
            // Snapshot the current selection at delivery, not at view creation.
            viewModel.scrollAccessibilityPage(toward: edge, pager: identity)
        }
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.pdfPageFocusContext, PDFPageFocusContext(
            model: viewModel, request: focusRequest,
            isViewportReady: focusRequest.viewport.size == size
        ))
    }

    // One stable collection across single/spread and fit changes. PDF indices are
    // document page identities, not offsets in the currently displayed group.
    private func accessibilityPages(_ item: IndexedPageGroup, size: CGSize) -> some View {
        let accessibilityOrder = PDFPageAccessibilityOrder.indices(
            item.group.pageIndices, retaining: viewModel.accessibilityFocusPageNumber.map { $0 - 1 }
        )
        let frames = PDFPageFrames.frames(
            pageSizes: item.group.pages.map { $0.bounds(for: .mediaBox).size },
            container: size, spread: viewModel.isSpreadLayoutEnabled,
            isFirst: item.index == 0, isLast: item.index == item.groupCount - 1,
            isRightToLeft: viewModel.settings.layoutDirection == .rightToLeft
        )
        return ZStack(alignment: .topLeading) {
            ForEach(accessibilityOrder, id: \.self) { pageIndex in
                if let offset = item.group.pageIndices.firstIndex(of: pageIndex) {
                    let frame = frames[offset]
                    PageView(
                        page: item.group.pages[offset], pageNumber: pageIndex + 1,
                        size: frame.size,
                        searchMatches: viewModel.searchMatches.filter { $0.pageIndex == pageIndex },
                        isHighQualityRenderingEnabled: viewModel.settings.isHighQualityRenderingEnabled,
                        isSharpnessEnabled: viewModel.settings.isSharpnessEnabled,
                        sharpnessAmount: viewModel.settings.sharpnessAmount
                    )
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                    // SwiftUI otherwise sorts a right-bound spread by physical
                    // position, putting newly inserted PDF5 ahead of retained PDF4.
                    .accessibilitySortPriority(PDFPageAccessibilityOrder.priority(
                        of: pageIndex, in: accessibilityOrder
                    ))
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func tabView(size: CGSize) -> some View {
        let identity = viewModel.pagerIdentity
        TabView(selection: $viewModel[pager: identity]) {
            pageTabViewContent(size: size)
        }
        // Keep logical page zero first even when SwiftUI mounts/recreates the pager.
        // Mirror the paging axis only; each page is mirrored back below.
        .scaleEffect(x: pagingScale, y: 1)
        .environment(\.layoutDirection, .leftToRight)
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoomScale = lastZoomScale * value.magnification
            }
            .onEnded { _ in
                lastZoomScale = zoomScale
                if zoomScale <= 1.0 {
                    resetContentOffset()
                }
            }
    }

    private var tapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    resetZoomScale()
                }
            }
            .exclusively(before: TapGesture(count: 1).onEnded {
                withAnimation {
                    isPDFChromeVisible.toggle()
                }
            })
    }

    private var longPressDragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture())
            .onChanged { value in
                guard zoomScale > 1.0 else {
                    return
                }

                if case .second(true, let drag?) = value {
                    contentOffset = offset(from: lastContentOffset, translation: drag.translation)
                }
            }
            .onEnded { value in
                guard zoomScale > 1.0 else {
                    resetContentOffset()
                    return
                }

                if case .second(true, let drag?) = value {
                    contentOffset = offset(from: lastContentOffset, translation: drag.translation)
                    lastContentOffset = contentOffset
                }
            }
    }

    private func resetZoomScale() {
        zoomScale = 1.0
        lastZoomScale = 1.0
        resetContentOffset()
    }

    private func resetContentOffset() {
        contentOffset = .zero
        lastContentOffset = .zero
    }

    private func offset(from baseOffset: CGSize, translation: CGSize) -> CGSize {
        CGSize(
            width: baseOffset.width + translation.width,
            height: baseOffset.height + translation.height
        )
    }

    @ViewBuilder
    private func pageTabViewContent(size: CGSize) -> some View {
        ForEach(orderedPageGroups) { item in
            pageContent(item, size: size)
                .scaleEffect(x: pagingScale, y: 1)
                .tag(item.group.id)
                .frame(width: size.width, height: size.height)
        }
    }

    private func pageContent(_ item: IndexedPageGroup, size: CGSize) -> some View {
        PageContentContainer(
            group: item.group,
            size: size,
            isSpreadViewEnabled: viewModel.isSpreadLayoutEnabled,
            searchMatches: viewModel.searchMatches.filter { item.group.pageIndices.contains($0.pageIndex) },
            layoutDirection: viewModel.settings.layoutDirection,
            isHighQualityRenderingEnabled: viewModel.settings.isHighQualityRenderingEnabled,
            isSharpnessEnabled: viewModel.settings.isSharpnessEnabled,
            sharpnessAmount: viewModel.settings.sharpnessAmount,
            isFirstGroup: item.index == 0,
            isLastGroup: item.index == item.groupCount - 1
        )
    }

    private var orderedPageGroups: [IndexedPageGroup] {
        let groups = viewModel.pageGroups
        let indexedGroups = groups.enumerated().map { index, group in
            IndexedPageGroup(index: index, group: group, groupCount: groups.count)
        }
        return indexedGroups
    }

    private var pagingScale: CGFloat {
        viewModel.settings.layoutDirection == .rightToLeft ? -1 : 1
    }

    private struct IndexedPageGroup: Identifiable {
        let index: Int
        let group: PDFViewerViewModel.PageGroup
        let groupCount: Int

        var id: Int { group.id }
    }
}

/// Keeps the same relative viewport position while preventing offscreen panning after a resize.
enum PDFViewportZoom {
    static func resizedOffset(
        _ offset: CGSize,
        from oldSize: CGSize,
        to newSize: CGSize,
        zoomScale: CGFloat
    ) -> CGSize {
        guard oldSize.width > 0, oldSize.height > 0,
              newSize.width > 0, newSize.height > 0,
              zoomScale > 1 else { return .zero }
        let maximumX = newSize.width * (zoomScale - 1) / 2
        let maximumY = newSize.height * (zoomScale - 1) / 2
        return CGSize(
            width: min(max(offset.width * newSize.width / oldSize.width, -maximumX), maximumX),
            height: min(max(offset.height * newSize.height / oldSize.height, -maximumY), maximumY)
        )
    }
}
