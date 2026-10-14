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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
        viewModel.updateViewportSize(
            size,
            horizontalSizeClass: horizontalSizeClass
        )
    }

    @ViewBuilder
    private func containerView(size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            tabView(size: size)
                .id(viewModel.document?.id)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .scaleEffect(zoomScale)
                .offset(contentOffset)
                .simultaneousGesture(magnificationGesture)
                .simultaneousGesture(tapGesture)
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
        .onChange(of: viewModel.pageGroups.count) { _, newCount in
            if viewModel.currentPageIndex >= newCount && newCount > 0 {
                viewModel.currentPageIndex = 0
            }
        }
    }

    @ViewBuilder
    private func tabView(size: CGSize) -> some View {
        TabView(selection: $viewModel.currentPageIndex) {
            pageTabViewContent(size: size)
        }
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
            let group = item.group
            PageContentContainer(
                group: group,
                size: size,
                isSpreadViewEnabled: viewModel.isSpreadLayoutEnabled,
                searchMatches: viewModel.searchMatches.filter { group.pageIndices.contains($0.pageIndex) },
                layoutDirection: viewModel.settings.layoutDirection,
                isHighQualityRenderingEnabled: viewModel.settings.isHighQualityRenderingEnabled,
                isSharpnessEnabled: viewModel.settings.isSharpnessEnabled,
                isFirstGroup: item.index == 0,
                isLastGroup: item.index == item.groupCount - 1
            )
            .tag(item.index)
            .frame(width: size.width, height: size.height)
        }
    }

    private var orderedPageGroups: [IndexedPageGroup] {
        let groups = viewModel.pageGroups
        let indexedGroups = groups.enumerated().map { index, group in
            IndexedPageGroup(index: index, group: group, groupCount: groups.count)
        }
        return viewModel.settings.layoutDirection == .rightToLeft
            ? Array(indexedGroups.reversed())
            : indexedGroups
    }

    private struct IndexedPageGroup: Identifiable {
        let index: Int
        let group: PDFViewerViewModel.PageGroup
        let groupCount: Int

        var id: Int { group.id }
    }
}

struct PageContentContainer: View {
    let group: PDFViewerViewModel.PageGroup
    let size: CGSize
    let isSpreadViewEnabled: Bool
    let searchMatches: [PDFViewerViewModel.PDFSearchMatch]
    let layoutDirection: LayoutDirection
    let isHighQualityRenderingEnabled: Bool
    let isSharpnessEnabled: Bool
    let isFirstGroup: Bool
    let isLastGroup: Bool

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center) {
                Spacer()
                pageContent(geometry.size)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func pageContent(_ containerSize: CGSize) -> some View {
        if shouldUseSpreadLayout {
            SpreadLayoutView(
                group: group,
                size: containerSize,
                searchMatches: searchMatches,
                layoutDirection: layoutDirection,
                isHighQualityRenderingEnabled: isHighQualityRenderingEnabled,
                isSharpnessEnabled: isSharpnessEnabled,
                isFirstGroup: isFirstGroup,
                isLastGroup: isLastGroup
            )
        } else {
            SinglePageView(
                group: group,
                size: containerSize,
                searchMatches: searchMatches,
                isHighQualityRenderingEnabled: isHighQualityRenderingEnabled,
                isSharpnessEnabled: isSharpnessEnabled
            )
        }
    }

    private var shouldUseSpreadLayout: Bool {
        guard isSpreadViewEnabled else {
            return false
        }

        return group.pages.count > 1 || (group.pages.count == 1 && (isFirstGroup || isLastGroup))
    }
}

struct SpreadLayoutView: View {
    let group: PDFViewerViewModel.PageGroup
    let size: CGSize
    let searchMatches: [PDFViewerViewModel.PDFSearchMatch]
    let layoutDirection: LayoutDirection
    let isHighQualityRenderingEnabled: Bool
    let isSharpnessEnabled: Bool
    let isFirstGroup: Bool
    let isLastGroup: Bool

    static func singlePageSizeInSpread(pageSize: CGSize, containerSize: CGSize) -> CGSize {
        let virtualSpreadSize = CGSize(width: pageSize.width * 2, height: pageSize.height)
        let scale = min(containerSize.width / virtualSpreadSize.width, containerSize.height / virtualSpreadSize.height)
        return CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
    }

    static func pageComesBeforeBlankPage(layoutDirection: LayoutDirection) -> Bool {
        layoutDirection == .leftToRight
    }

    var body: some View {
        GeometryReader { geometry in
            let cw = geometry.size.width
            let ch = geometry.size.height

            let p1 = group.pages[0]
            let s1 = p1.bounds(for: .mediaBox).size

            if group.pages.count == 1 {
                let targetSize = Self.singlePageSizeInSpread(pageSize: s1, containerSize: geometry.size)

                if isLastGroup {
                    VStack(alignment: .center) {
                        Spacer()
                        HStack(spacing: 0) {
                            if Self.pageComesBeforeBlankPage(layoutDirection: layoutDirection) {
                                PageView(
                                    page: p1,
                                    pageNumber: group.pageIndices.first.map { $0 + 1 },
                                    size: targetSize,
                                    searchMatches: searchMatches,
                                    alignment: .center,
                                    isHighQualityRenderingEnabled: isHighQualityRenderingEnabled,
                                    isSharpnessEnabled: isSharpnessEnabled
                                )
                                blankPage(size: targetSize)
                            } else {
                                blankPage(size: targetSize)
                                PageView(
                                    page: p1,
                                    pageNumber: group.pageIndices.first.map { $0 + 1 },
                                    size: targetSize,
                                    searchMatches: searchMatches,
                                    alignment: .center,
                                    isHighQualityRenderingEnabled: isHighQualityRenderingEnabled,
                                    isSharpnessEnabled: isSharpnessEnabled
                                )
                            }
                        }
                        .environment(\.layoutDirection, .leftToRight)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .center) {
                        Spacer()
                        PageView(
                            page: p1,
                            pageNumber: group.pageIndices.first.map { $0 + 1 },
                            size: targetSize,
                            searchMatches: searchMatches,
                            alignment: .center,
                            isHighQualityRenderingEnabled: isHighQualityRenderingEnabled,
                            isSharpnessEnabled: isSharpnessEnabled
                        )
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                let p2 = group.pages[1]
                let s2 = p2.bounds(for: .mediaBox).size

                let w1 = s1.width * (ch / s1.height)
                let w2 = s2.width * (ch / s2.height)
                let totalWAtCh = w1 + w2

             if totalWAtCh <= cw {
                 VStack(alignment: .center) {
                     Spacer()
                     HStack(spacing: 0) {
                         PageView(
                             page: p1,
                             pageNumber: group.pageIndices[0] + 1,
                             size: CGSize(width: w1, height: ch),
                             searchMatches: searchMatches.filter { $0.pageIndex == group.pageIndices[0] },
                             alignment: .left,
                             isHighQualityRenderingEnabled: isHighQualityRenderingEnabled,
                             isSharpnessEnabled: isSharpnessEnabled
                         )
                         PageView(
                             page: p2,
                             pageNumber: group.pageIndices[1] + 1,
                             size: CGSize(width: w2, height: ch),
                             searchMatches: searchMatches.filter { $0.pageIndex == group.pageIndices[1] },
                             alignment: .right,
                             isHighQualityRenderingEnabled: isHighQualityRenderingEnabled,
                             isSharpnessEnabled: isSharpnessEnabled
                         )
                     }
                     .environment(\.layoutDirection, .leftToRight)
                     Spacer()
                 }
                 .frame(maxWidth: .infinity, maxHeight: .infinity)
             } else {
                 let scale = cw / totalWAtCh
                 let targetW1 = w1 * scale
                 let targetW2 = w2 * scale
                 let targetH1 = s1.height * (targetW1 / s1.width)
                 let targetH2 = s2.height * (targetW2 / s2.width)

                 VStack(alignment: .center) {
                     Spacer()
                     HStack(spacing: 0) {
                        PageView(
                            page: p1,
                            pageNumber: group.pageIndices[0] + 1,
                            size: CGSize(width: targetW1, height: targetH1),
                            searchMatches: searchMatches.filter { $0.pageIndex == group.pageIndices[0] },
                            alignment: .center,
                            isHighQualityRenderingEnabled: isHighQualityRenderingEnabled,
                            isSharpnessEnabled: isSharpnessEnabled
                        )
                        PageView(
                            page: p2,
                            pageNumber: group.pageIndices[1] + 1,
                            size: CGSize(width: targetW2, height: targetH2),
                            searchMatches: searchMatches.filter { $0.pageIndex == group.pageIndices[1] },
                            alignment: .center,
                            isHighQualityRenderingEnabled: isHighQualityRenderingEnabled,
                            isSharpnessEnabled: isSharpnessEnabled
                        )
                     }
                     .environment(\.layoutDirection, .leftToRight)
                     Spacer()
                 }
                 .frame(maxWidth: .infinity, maxHeight: .infinity)
             }
        }
    }
    }

    private func blankPage(size: CGSize) -> some View {
        Color.clear
            .frame(width: size.width, height: size.height)
            .accessibilityHidden(true)
    }
}

struct SinglePageView: View {
    let group: PDFViewerViewModel.PageGroup
    let size: CGSize
    let searchMatches: [PDFViewerViewModel.PDFSearchMatch]
    let isHighQualityRenderingEnabled: Bool
    let isSharpnessEnabled: Bool

    var body: some View {
        GeometryReader { geometry in
            let cw = geometry.size.width
            let ch = geometry.size.height

            if let firstPage = group.pages.first {
                let s = firstPage.bounds(for: .mediaBox).size
                let scale = min(cw / s.width, ch / s.height)
                let targetSize = CGSize(width: s.width * scale, height: s.height * scale)

                VStack(alignment: .center) {
                    Spacer()
                    PageView(
                        page: firstPage,
                        pageNumber: group.pageIndices.first.map { $0 + 1 },
                        size: targetSize,
                        searchMatches: searchMatches,
                        alignment: .center,
                        isHighQualityRenderingEnabled: isHighQualityRenderingEnabled,
                        isSharpnessEnabled: isSharpnessEnabled
                    )
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
