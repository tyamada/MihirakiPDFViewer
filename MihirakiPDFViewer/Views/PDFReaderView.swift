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

struct ScrollDirectionHintView: View {
    let layoutDirection: LayoutDirection
    @State private var isAnimating = false

    private var symbolName: String {
        layoutDirection == .leftToRight ? "arrow.left" : "arrow.right"
    }

    private var startOffset: CGFloat {
        layoutDirection == .leftToRight ? 18 : -18
    }

    private var endOffset: CGFloat {
        layoutDirection == .leftToRight ? -18 : 18
    }

    var body: some View {
        ZStack {
            VStack {
                Text(String(localized: "tap_to_show_menu_hint", defaultValue: "Tap to show the menu"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(radius: 8)
                Spacer()
            }
            .padding(.top, 24)
            .padding(.horizontal, 16)

            Image(systemName: symbolName)
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 96, height: 96)
                .background(.black.opacity(0.62), in: Circle())
                .shadow(radius: 8)
                .offset(x: isAnimating ? endOffset : startOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

struct PDFPageSliderView: View {
    @Binding var currentPageIndex: Int
    let pageCount: Int
    let layoutDirection: LayoutDirection

    private var sliderValue: Binding<Double> {
        Binding(
            get: {
                let maximumIndex = Double(max(1, pageCount - 1))
                let currentRatio = Double(currentPageIndex) / maximumIndex
                return layoutDirection == .leftToRight ? currentRatio : (1 - currentRatio)
            },
            set: { newValue in
                let maximumIndex = Double(max(1, pageCount - 1))
                let targetRatio = layoutDirection == .leftToRight ? newValue : (1 - newValue)
                currentPageIndex = Int((targetRatio * maximumIndex).rounded())
            }
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            Slider(value: sliderValue, in: 0...1)
                .tint(.blue)
                .accessibilityIdentifier("pageSlider")
                .accessibilityLabel(String(localized: "page_slider_accessibility_label", defaultValue: "Page"))
                .accessibilityValue("\(currentPageIndex + 1) / \(pageCount)")

            Text("\(currentPageIndex + 1) / \(pageCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary)
                .accessibilityIdentifier("pageIndicator")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

struct PDFReaderToolbar: ToolbarContent {
    @Binding var searchQuery: String
    let openSettings: () -> Void
    let closeDocument: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: openSettings) {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel(String(localized: "settings"))
            .accessibilityIdentifier("settingsButton")
        }

        ToolbarItem(placement: .principal) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(String(localized: "search"), text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("searchField")
            }
            .frame(minWidth: 140, idealWidth: 280, maxWidth: 420)
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button(action: closeDocument) {
                Image(systemName: "xmark")
            }
            .accessibilityLabel(String(localized: "close"))
            .accessibilityIdentifier("closeDocumentButton")
        }
    }
}
