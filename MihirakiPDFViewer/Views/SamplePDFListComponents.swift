//
// SamplePDFListComponents.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//
// This software is released under the MIT License.
// For the full license text, please see the LICENSE file in the root directory.
//

import SwiftUI

struct SamplePDFLanguageFilterPicker: View {
    let languageCodes: [String]
    @Binding var selectedLanguageCode: String?

    var body: some View {
        Section {
            Picker(
                String(localized: "sample_pdf_language_filter_label", defaultValue: "Language"),
                selection: $selectedLanguageCode
            ) {
                Text(String(localized: "sample_pdf_language_filter_all", defaultValue: "All"))
                    .tag(nil as String?)

                ForEach(languageCodes, id: \.self) { languageCode in
                    Text(Locale.current.localizedString(forLanguageCode: languageCode) ?? languageCode)
                        .tag(Optional(languageCode))
                }
            }
            .accessibilityIdentifier("samplePDFLanguageFilter")
        }
    }
}

struct SamplePDFRow: View {
    let sample: SamplePDF
    let state: SamplePDFDownloadState
    let isOpen: Bool
    let areActionsSuppressed: Bool
    let isDownloadEnabled: Bool
    let downloadAction: () -> Void
    let openAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(sample.title)
                .font(.headline)

            Text(verbatim: "\(sample.languageDisplayName) · \(sample.formattedFileSize)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SamplePDFRowAction(
                sampleID: sample.id,
                state: state,
                isOpen: isOpen,
                areActionsSuppressed: areActionsSuppressed,
                isDownloadEnabled: isDownloadEnabled,
                downloadAction: downloadAction,
                openAction: openAction,
                deleteAction: deleteAction
            )
        }
        .padding(.vertical, 4)
    }
}

private struct SamplePDFRowAction: View {
    let sampleID: String
    let state: SamplePDFDownloadState
    let isOpen: Bool
    let areActionsSuppressed: Bool
    let isDownloadEnabled: Bool
    let downloadAction: () -> Void
    let openAction: () -> Void
    let deleteAction: () -> Void

    @ViewBuilder
    var body: some View {
        switch state {
        case .notDownloaded:
            Button(action: downloadAction) {
                Label(
                    String(localized: "sample_pdf_download_button", defaultValue: "Download"),
                    systemImage: "arrow.down.circle"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isDownloadEnabled)
            .accessibilityIdentifier("samplePDFDownload_\(sampleID)")
        case .downloading:
            HStack {
                ProgressView()
                Text(String(localized: "sample_pdf_downloading", defaultValue: "Downloading…"))
            }
            .accessibilityElement(children: .combine)
        case .downloaded:
            HStack(spacing: 12) {
                Label(
                    String(localized: "sample_pdf_downloaded", defaultValue: "Downloaded"),
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.green)

                Spacer()

                Button(action: openAction) {
                    Text(String(localized: "sample_pdf_open_button", defaultValue: "Open"))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(isOpen || areActionsSuppressed)
                .accessibilityIdentifier("samplePDFOpen_\(sampleID)")

                Button(role: .destructive, action: deleteAction) {
                    Text(String(localized: "sample_pdf_delete_button", defaultValue: "Delete"))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(isOpen || areActionsSuppressed)
                .accessibilityHint(
                    isOpen
                        ? String(
                            localized: "sample_pdf_close_before_delete",
                            defaultValue: "Close this PDF before deleting it."
                        )
                        : ""
                )
                .accessibilityIdentifier("samplePDFDelete_\(sampleID)")
            }
        case .deleting:
            HStack {
                ProgressView()
                Text(String(localized: "sample_pdf_deleting", defaultValue: "Deleting…"))
            }
            .accessibilityElement(children: .combine)
        }
    }
}
