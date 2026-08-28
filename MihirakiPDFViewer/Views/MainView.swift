//
// MainView.swift
// MihirakiPDFViewer
//
// Created by Cline on 2026/07/02.
// Reviewed & Updated by Takuma Yamada.
//
// Copyright 2026 Takuma Yamada.
//
// This software is released under the MIT License.
// For the full license text, please see the LICENSE file in the root directory.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit
import PDFKit

/// アプリケーションのメインビュー
public struct MainView: View {
    @StateObject private var viewModel = PDFViewerViewModel()

    @StateObject private var tipManager = TipManager.shared
    @State private var isShowingFilePicker = false
    @State private var isShowingErrorAlert = false
    @State private var isShowingSettings = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var isShowingTipSuccessAlert = false
    @State private var isShowingTipErrorAlert = false
    @State private var lastTipProductID: String? = nil
    @State private var isPDFChromeVisible = false
    @State private var isScrollDirectionHintVisible = false
    @State private var scrollDirectionHintToken = UUID()
    @State private var isShowingPDFPasswordPrompt = false
    @State private var pendingPasswordPDFURL: URL?
    @State private var pdfPassword = ""
    @State private var pdfPasswordMessage: String?

    public init() {}

    private var tipSuccessMessage: String {
        String(localized: "tip_success_message", defaultValue: "Thank you for your support.")
    }

    public var body: some View {
        NavigationStack {
            mainContent
                .alert(String(localized: "error_title"), isPresented: $isShowingErrorAlert) {
                    Button(String(localized: "ok")) {
                        viewModel.errorMessage = nil
                    }
                } message: {
                    Text(viewModel.errorMessage ?? String(localized: "error_occurred"))
                }
                .onChange(of: viewModel.errorMessage) { _, newValue in
                    if newValue != nil {
                        isShowingErrorAlert = true
                    }
                }
                .alert(
                    String(localized: "pdf_password_dialog_title", defaultValue: "Password Required"),
                    isPresented: $isShowingPDFPasswordPrompt
                ) {
                    SecureField(String(localized: "pdf_password_placeholder", defaultValue: "Password"), text: $pdfPassword)
                    Button(String(localized: "cancel"), role: .cancel) {
                        cancelPDFPasswordPrompt()
                    }
                    Button(String(localized: "pdf_password_unlock_button", defaultValue: "Unlock")) {
                        unlockPendingPDF()
                    }
                    .disabled(pdfPassword.isEmpty)
                } message: {
                    Text(pdfPasswordMessage ?? String(localized: "pdf_password_dialog_message", defaultValue: "Enter the user password for this PDF."))
                }
                .sheet(isPresented: $isShowingSettings) {
                    settingsSheet
                }
                .alert(
                    String(localized: "tip_success_title", defaultValue: "Thank You for Your Support!"),
                    isPresented: $isShowingTipSuccessAlert
                ) {
                    if let iconName = tipManager.pendingAppIconName {
                        Button(String(localized: "change_app_icon", defaultValue: "Change Icon")) {
                            Task {
                                if await tipManager.changeAppIcon(named: iconName) {
                                    tipManager.resetSuccessFlag()
                                }
                            }
                        }
                    }

                    Button(String(localized: "ok")) {
                        tipManager.resetSuccessFlag()
                    }
                } message: {
                    Text(tipSuccessMessage)
                }
                .onChange(of: tipManager.isPurchaseSuccess) { _, newValue in
                    if newValue {
                        lastTipProductID = tipManager.lastPurchasedProductID
                        isShowingTipSuccessAlert = true
                    }
                }
                .alert(String(localized: "error_title"), isPresented: $isShowingTipErrorAlert) {
                    Button(String(localized: "ok")) {
                        tipManager.clearError()
                    }
                } message: {
                    Text(tipManager.errorMessage ?? String(localized: "error_occurred"))
                }
                .onChange(of: tipManager.errorMessage) { _, newValue in
                    if newValue != nil {
                        isShowingTipErrorAlert = true
                    }
                }
                .onAppear {
                    loadSamplePDFForUITestsIfNeeded()
                }
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result: result)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        makeDetailView()
    }

    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                viewModel.errorMessage = String(localized: "pdf_file_selection_failed", defaultValue: "Could not select the PDF file.")
                return
            }
            openPDF(at: url)
        case .failure(let error):
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
                return
            }
            viewModel.errorMessage = String(localized: "pdf_file_selection_failed", defaultValue: "Could not select the PDF file.")
        }
    }

    private func loadSamplePDFForUITestsIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-uiTestLoadSamplePDF"),
              viewModel.document == nil,
              let url = makeSamplePDFForUITests() else {
            return
        }

        openPDF(at: url)
    }

    private func openPDF(at url: URL, password: String? = nil) {
        switch viewModel.loadDocument(from: url, password: password) {
        case .loaded:
            finishPDFLoad()
        case .passwordRequired:
            presentPDFPasswordPrompt(for: url)
        case .invalidPassword:
            presentPDFPasswordPrompt(
                for: url,
                message: String(localized: "pdf_password_incorrect", defaultValue: "The password is incorrect.")
            )
        case .failed:
            break
        }
    }

    private func finishPDFLoad() {
        pendingPasswordPDFURL = nil
        pdfPassword = ""
        pdfPasswordMessage = nil
        isShowingPDFPasswordPrompt = false
        isPDFChromeVisible = false
        showScrollDirectionHint()
    }

    private func presentPDFPasswordPrompt(for url: URL, message: String? = nil) {
        pendingPasswordPDFURL = url
        pdfPassword = ""
        pdfPasswordMessage = message
        isShowingPDFPasswordPrompt = true
    }

    private func unlockPendingPDF() {
        guard let url = pendingPasswordPDFURL else {
            return
        }

        let password = pdfPassword
        Task { @MainActor in
            openPDF(at: url, password: password)
        }
    }

    private func cancelPDFPasswordPrompt() {
        pendingPasswordPDFURL = nil
        pdfPassword = ""
        pdfPasswordMessage = nil
        viewModel.cancelPendingDocumentLoad()
    }

    private func showScrollDirectionHint() {
        let token = UUID()
        scrollDirectionHintToken = token
        isScrollDirectionHintVisible = true

        Task {
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                if scrollDirectionHintToken == token {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isScrollDirectionHintVisible = false
                    }
                }
            }
        }
    }

    private func makeSamplePDFForUITests() -> URL? {
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

    @ViewBuilder
    private var settingsSheet: some View {
        NavigationStack {
            SettingsView(viewModel: viewModel)
                .navigationTitle(String(localized: "settings"))
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isShowingSettings = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.primary)
                        }
                        .accessibilityLabel(String(localized: "close"))
                        .accessibilityIdentifier("settingsCloseButton")
                    }
                }
        }
    }

    @ViewBuilder
    private func makeDetailView() -> some View {
        if viewModel.document != nil {
            VStack(spacing: 0) {
                PDFContainerView(
                    viewModel: viewModel,
                    isShowingFilePicker: $isShowingFilePicker,
                    isShowingSettings: $isShowingSettings,
                    isPDFChromeVisible: $isPDFChromeVisible,
                    isScrollDirectionHintVisible: isScrollDirectionHintVisible
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("pdfViewerScreen")

                if isPDFChromeVisible && viewModel.pageGroups.count > 1 {
                    VStack(spacing: 8) {
                        Slider(value: Binding(
                            get: {
                                let maxIdx = Double(max(1, viewModel.pageGroups.count - 1))
                                let currentRatio = Double(viewModel.currentPageIndex) / maxIdx
                                return viewModel.settings.layoutDirection == .leftToRight ? currentRatio : (1.0 - currentRatio)
                            },
                            set: { newValue in
                                let maxIdx = Double(max(1, viewModel.pageGroups.count - 1))
                                let targetRatio = viewModel.settings.layoutDirection == .leftToRight ? newValue : (1.0 - newValue)
                                viewModel.currentPageIndex = Int((targetRatio * maxIdx).rounded())
                            }
                        ), in: 0...1)
                        .accentColor(.blue)
                        .accessibilityIdentifier("pageSlider")
                        .accessibilityLabel(String(localized: "page_slider_accessibility_label", defaultValue: "Page"))
                        .accessibilityValue("\(viewModel.currentPageIndex + 1) / \(viewModel.pageGroups.count)")

                        Text("\(viewModel.currentPageIndex + 1) / \(viewModel.pageGroups.count)")
                            .font(.caption.monospacedDigit())
                            .accessibilityIdentifier("pageIndicator")
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(isPDFChromeVisible ? .visible : .hidden, for: .navigationBar)
        } else {
            makeEmptyStateView()
        }
    }

    @ViewBuilder
    private func makeEmptyStateView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text(String(localized: "select_pdf_title"))
                .font(.title2)
            Button {
                isShowingFilePicker = true
            } label: {
                Text(String(localized: "select_pdf_button"))
                    .accessibilityIdentifier("selectPDFButtonLabel")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("selectPDFButton")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("emptyStateView")
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !ProcessInfo.processInfo.arguments.contains("-uiTestDisableAutoFilePicker") {
                isShowingFilePicker = true
            }
        }
        .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(String(localized: "settings"))
                    .accessibilityIdentifier("settingsButton")
                }
            }
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

/// PDF表示のコンテナビュー
struct PDFContainerView: View {
    @ObservedObject var viewModel: PDFViewerViewModel
    @Binding var isShowingFilePicker: Bool
    @Binding var isShowingSettings: Bool
    @Binding var isPDFChromeVisible: Bool
    let isScrollDirectionHintVisible: Bool
    
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var contentOffset: CGSize = .zero
    @State private var lastContentOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            containerView(size: geometry.size)
        }
    }

    @ViewBuilder
    private func containerView(size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            tabView(size: size)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .environment(\.layoutDirection, viewModel.settings.layoutDirection == .leftToRight ? .leftToRight : .rightToLeft)
                .scaleEffect(zoomScale)
                .offset(contentOffset)
                .gesture(magnificationGesture)
                .simultaneousGesture(tapGesture)
                .simultaneousGesture(longPressDragGesture)

            if isScrollDirectionHintVisible {
                ScrollDirectionHintView(layoutDirection: viewModel.settings.layoutDirection)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .toolbar {
            toolbarContent
        }
        .onChange(of: viewModel.searchQuery) { _, query in
            viewModel.performSearch(query: query)
        }
        .onChange(of: viewModel.document?.id) { _, _ in
            resetZoom()
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


    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isPDFChromeVisible {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(String(localized: "settings"))
                .accessibilityIdentifier("settingsButton")
            }
            ToolbarItem(placement: .principal) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(String(localized: "search"), text: $viewModel.searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("searchField")
                }
                .padding(.horizontal, 4)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isPDFChromeVisible = false
                    viewModel.closeDocument()
                } label: {
                    Text(String(localized: "close"))
                }
                .accessibilityIdentifier("closeDocumentButton")
            }
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

    private func resetZoom() {
        viewModel.currentPageIndex = 0
        resetZoomScale()
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
        ForEach(0..<viewModel.pageGroups.count, id: \.self) { index in
            let group = viewModel.pageGroups[index]
            PageContentContainer(
                group: group,
                size: size,
                isSpreadViewEnabled: viewModel.settings.isSpreadViewEnabled,
                searchMatches: viewModel.searchMatches.filter { group.pageIndices.contains($0.pageIndex) },
                layoutDirection: viewModel.settings.layoutDirection,
                isHighQualityRenderingEnabled: viewModel.settings.isHighQualityRenderingEnabled,
                isSharpnessEnabled: viewModel.settings.isSharpnessEnabled,
                isFirstGroup: index == 0,
                isLastGroup: index == viewModel.pageGroups.count - 1
            )
            .tag(index)
            .frame(width: size.width, height: size.height)
        }
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
