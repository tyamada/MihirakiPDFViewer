//
// MainPresentationViews.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//
// This software is released under the MIT License.
// For the full license text, please see the LICENSE file in the root directory.
//

import SwiftUI

struct MainContentView: View {
    @Bindable var viewModel: PDFViewerViewModel
    @Binding var isPDFChromeVisible: Bool
    let isScrollDirectionHintVisible: Bool
    let selectPDF: () -> Void
    let openDocument: (URL) -> Void
    let didDeleteDocument: (URL) -> Void
    let openReaderSettings: () -> Void
    let openEmptyStateSettings: () -> Void
    @State private var isShowingOutline = false

    var body: some View {
        if viewModel.document != nil {
            ZStack(alignment: .bottom) {
                PDFContainerView(
                    viewModel: viewModel,
                    isPDFChromeVisible: $isPDFChromeVisible,
                    isScrollDirectionHintVisible: isScrollDirectionHintVisible
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .top)
                .accessibilityIdentifier("pdfViewerScreen")

                if isPDFChromeVisible && viewModel.pageGroups.count > 1 {
                    PDFPageSliderView(
                        currentPageIndex: $viewModel.currentPageIndex,
                        pageCount: viewModel.pageGroups.count,
                        layoutDirection: viewModel.settings.layoutDirection
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                PDFReaderToolbar(
                    searchQuery: $viewModel.searchQuery,
                    openSettings: openReaderSettings,
                    openOutline: {
                        isShowingOutline = true
                    },
                    closeDocument: {
                        isPDFChromeVisible = false
                        viewModel.closeDocument()
                    }
                )
            }
            .toolbarVisibility(isPDFChromeVisible ? .visible : .hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingOutline) {
                PDFOutlineView(
                    nodes: viewModel.outline,
                    currentPageIndices: Set(viewModel.displayedPDFPageIndices),
                    onSelectPage: viewModel.jumpToPDFPage
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        } else {
            PDFEmptyStateView(
                selectPDF: selectPDF,
                openDocument: openDocument,
                didDeleteDocument: didDeleteDocument,
                openSettings: openEmptyStateSettings
            )
        }
    }
}

struct SettingsSheetView: View {
    let viewModel: PDFViewerViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            SettingsView(viewModel: viewModel)
                .navigationTitle(String(localized: "settings"))
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.primary)
                        }
                        .accessibilityLabel(String(localized: "close"))
                        .accessibilityIdentifier("settingsCloseButton")
                    }
                }
        }
    }
}
