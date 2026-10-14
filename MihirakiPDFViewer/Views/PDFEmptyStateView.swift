//
// PDFEmptyStateView.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import SwiftUI

struct PDFEmptyStateView: View {
    let selectPDF: () -> Void
    let openDocument: (URL) -> Void
    let didDeleteDocument: (URL) -> Void
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(String(localized: "select_pdf_title"))
                .font(.title2)
                .accessibilityIdentifier("emptyStateView")

            Button(action: selectPDF) {
                Text(String(localized: "select_pdf_button"))
                    .accessibilityIdentifier("selectPDFButtonLabel")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("selectPDFButton")

            NavigationLink {
                SamplePDFListView(
                    openDocumentURL: nil,
                    openDocument: openDocument,
                    didDeleteDocument: didDeleteDocument
                )
            } label: {
                Label(
                    String(localized: "sample_pdf_browse_button", defaultValue: "Browse Sample PDFs"),
                    systemImage: "doc.badge.arrow.up"
                )
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("samplePDFsButton")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(String(localized: "settings"))
                .accessibilityIdentifier("settingsButton")
            }
        }
    }
}
