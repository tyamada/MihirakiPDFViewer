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
    @State private var lastTipProductID: String? = nil

    public init() {}

    private var tipSuccessMessage: String {
        String(localized: "tip_success_message", defaultValue: "応援ありがとうございました。")
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
                .sheet(isPresented: $isShowingSettings) {
                    settingsSheet
                }
                .alert(
                    String(localized: "tip_success_title", defaultValue: "応援ありがとうございます！"),
                    isPresented: $isShowingTipSuccessAlert
                ) {
                    if let iconName = tipManager.pendingAppIconName {
                        Button(String(localized: "change_app_icon", defaultValue: "アイコンを変更")) {
                            Task {
                                await tipManager.changeAppIcon(named: iconName)
                                tipManager.resetSuccessFlag()
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
        if case .success(let urls) = result, let url = urls.first {
            viewModel.loadDocument(from: url)
        }
    }

    @ViewBuilder
    private var settingsSheet: some View {
        NavigationStack {
            SettingsView(viewModel: viewModel)
                .navigationTitle(String(localized: "settings"))
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(String(localized: "close")) {
                            isShowingSettings = false
                        }
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
                    isShowingSettings: $isShowingSettings
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                 if viewModel.pageGroups.count > 1 && viewModel.settings.isSliderEnabled {
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
                         
                         Text("\(viewModel.currentPageIndex + 1) / \(viewModel.pageGroups.count)")
                             .font(.caption.monospacedDigit())
                             .foregroundColor(.secondary)
                     }
                     .padding(.horizontal)
                     .padding(.vertical, 8)
                     .background(Color(uiColor: .secondarySystemBackground))
                     .cornerRadius(12)
                     .padding(.horizontal, 16)
                 }
            }
            .navigationTitle("")
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
            Button(String(localized: "select_pdf_button")) {
                isShowingFilePicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
    }
}

/// PDF表示のコンテナビュー
struct PDFContainerView: View {
    @ObservedObject var viewModel: PDFViewerViewModel
    @Binding var isShowingFilePicker: Bool
    @Binding var isShowingSettings: Bool
    
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0

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
                .gesture(magnificationGesture)
                .gesture(tapGesture)
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
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
        }
        if viewModel.settings.isSearchbarEnabled {
            ToolbarItem(placement: .principal) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(String(localized: "search"), text: $viewModel.searchQuery)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 4)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                viewModel.closeDocument()
            } label: {
                Text(String(localized: "close"))
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
            }
    }

    private var tapGesture: some Gesture {
        TapGesture().onEnded {
            withAnimation {
                if zoomScale > 1.0 {
                    zoomScale = 1.0
                    lastZoomScale = 1.0
                }
            }
        }
    }

    private func resetZoom() {
        viewModel.currentPageIndex = 0
        zoomScale = 1.0
        lastZoomScale = 1.0
    }

    @ViewBuilder
    private func pageTabViewContent(size: CGSize) -> some View {
        ForEach(0..<viewModel.pageGroups.count, id: \.self) { index in
            let group = viewModel.pageGroups[index]
            PageContentContainer(
                group: group,
                size: size,
                isSpreadViewEnabled: viewModel.settings.isSpreadViewEnabled,
                searchMatches: viewModel.searchMatches.filter { $0.pageIndex == index }
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
        if isSpreadViewEnabled && group.pages.count > 1 {
            SpreadLayoutView(group: group, size: containerSize, searchMatches: searchMatches)
        } else {
            SinglePageView(group: group, size: containerSize, searchMatches: searchMatches)
        }
    }
}

struct SpreadLayoutView: View {
    let group: PDFViewerViewModel.PageGroup
    let size: CGSize
    let searchMatches: [PDFViewerViewModel.PDFSearchMatch]

    var body: some View {
        GeometryReader { geometry in
            let cw = geometry.size.width
            let ch = geometry.size.height
            
            let p1 = group.pages[0]
            let p2 = group.pages[1]
            let s1 = p1.bounds(for: .mediaBox).size
            let s2 = p2.bounds(for: .mediaBox).size

            let w1 = s1.width * (ch / s1.height)
            let w2 = s2.width * (ch / s2.height)
            let totalWAtCh = w1 + w2

             if totalWAtCh <= cw {
                 VStack(alignment: .center) {
                     Spacer()
                     HStack(spacing: 0) {
                         PageView(page: p1, size: CGSize(width: w1, height: ch), searchMatches: searchMatches.filter { $0.pageIndex == group.startIndex }, alignment: .left)
                         PageView(page: p2, size: CGSize(width: w2, height: ch), searchMatches: searchMatches.filter { $0.pageIndex == group.startIndex + 1 }, alignment: .right)
                     }
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
                        PageView(page: p1, size: CGSize(width: targetW1, height: targetH1), alignment: .center)
                        PageView(page: p2, size: CGSize(width: targetW2, height: targetH2), alignment: .center)
                     }
                     Spacer()
                 }
                 .frame(maxWidth: .infinity, maxHeight: .infinity)
             }
        }
    }
}

struct SinglePageView: View {
    let group: PDFViewerViewModel.PageGroup
    let size: CGSize
    let searchMatches: [PDFViewerViewModel.PDFSearchMatch]

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
                    PageView(page: firstPage, size: targetSize, searchMatches: searchMatches, alignment: .center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
