//
// PDFReaderControls.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//
// This software is released under the MIT License.
// For the full license text, please see the LICENSE file in the root directory.
//

import SwiftUI

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
                Text(String(
                    localized: "tap_to_show_menu_hint",
                    defaultValue: "Tap to show the menu"
                ))
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    .black.opacity(0.62),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .shadow(radius: 8)
                Spacer()
            }
            .padding(.top, 24)
            .padding(.horizontal, 16)

            Image(systemName: symbolName)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
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
                let targetRatio = layoutDirection == .leftToRight
                    ? newValue
                    : (1 - newValue)
                currentPageIndex = Int((targetRatio * maximumIndex).rounded())
            }
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            Slider(value: sliderValue, in: 0...1)
                .tint(.blue)
                .accessibilityIdentifier("pageSlider")
                .accessibilityLabel(String(
                    localized: "page_slider_accessibility_label",
                    defaultValue: "Page"
                ))
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
    let openOutline: () -> Void
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

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: openOutline) {
                Image(systemName: "list.bullet.indent")
            }
            .accessibilityLabel("Table of Contents")
            .accessibilityIdentifier("tableOfContentsButton")

            Button(action: closeDocument) {
                Image(systemName: "xmark")
            }
            .accessibilityLabel(String(localized: "close"))
            .accessibilityIdentifier("closeDocumentButton")
        }
    }
}
