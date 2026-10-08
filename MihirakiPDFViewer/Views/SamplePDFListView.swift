//
// SamplePDFListView.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import SwiftUI

struct SamplePDFListView: View {
    let openDocumentURL: URL?

    @State private var store = SamplePDFStore()
    @State private var cellularDownload: SamplePDF?
    @State private var deletionCandidate: SamplePDF?
    @State private var isShowingError = false
    @State private var selectedLanguageCode: String?
    @State private var didInitializeLanguageFilter = false

    var body: some View {
        Group {
            if let catalog = store.catalog {
                List {
                    SamplePDFLanguageFilterPicker(
                        languageCodes: SamplePDFLanguageFilter.availableLanguageCodes(in: catalog.samples),
                        selectedLanguageCode: $selectedLanguageCode
                    )

                    Section {
                        ForEach(filteredSamples(in: catalog)) { sample in
                            SamplePDFRow(
                                sample: sample,
                                state: store.state(for: sample),
                                isOpen: isOpen(sample),
                                isDownloadEnabled: store.isNetworkPathKnown,
                                downloadAction: { requestDownload(sample) },
                                deleteAction: { deletionCandidate = sample }
                            )
                        }
                    } footer: {
                        Text(String(
                            localized: "sample_pdf_open_instructions",
                            defaultValue: "After downloading, close Settings, tap Open, and select a PDF from Documents/SamplePDFs."
                        ))
                    }

                    Section(String(localized: "sample_pdf_license_title", defaultValue: "License")) {
                        Link(destination: catalog.license.url) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(catalog.license.name)
                                Text(catalog.license.creator)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    String(localized: "sample_pdf_catalog_error", defaultValue: "The sample PDF list could not be loaded."),
                    systemImage: "doc.badge.ellipsis"
                )
            }
        }
        .navigationTitle(String(localized: "sample_pdf_title", defaultValue: "Sample PDFs"))
        .accessibilityIdentifier("samplePDFListScreen")
        .task {
            store.loadCatalog()
            initializeLanguageFilterIfNeeded()
        }
        .onChange(of: store.errorMessage) { _, newValue in
            isShowingError = newValue != nil
        }
        .alert(
            String(localized: "sample_pdf_cellular_title", defaultValue: "Download Using Mobile Data?"),
            isPresented: Binding(
                get: { cellularDownload != nil },
                set: { if !$0 { cellularDownload = nil } }
            ),
            presenting: cellularDownload
        ) { sample in
            Button(String(localized: "cancel"), role: .cancel) {
                cellularDownload = nil
            }
            Button(String(localized: "sample_pdf_download_button", defaultValue: "Download")) {
                cellularDownload = nil
                startDownload(sample, allowsCellular: true)
            }
        } message: { sample in
            Text(String(
                localized: "sample_pdf_cellular_message",
                defaultValue: "This PDF is \(sample.formattedFileSize). Downloading it will use mobile data."
            ))
        }
        .alert(
            String(localized: "sample_pdf_delete_title", defaultValue: "Delete Sample PDF?"),
            isPresented: Binding(
                get: { deletionCandidate != nil },
                set: { if !$0 { deletionCandidate = nil } }
            ),
            presenting: deletionCandidate
        ) { sample in
            Button(String(localized: "cancel"), role: .cancel) {
                deletionCandidate = nil
            }
            Button(String(localized: "sample_pdf_delete_button", defaultValue: "Delete"), role: .destructive) {
                deletionCandidate = nil
                store.delete(sample)
            }
        } message: { sample in
            Text(String(
                localized: "sample_pdf_delete_message",
                defaultValue: "Delete \(sample.title) from Documents?"
            ))
        }
        .alert(
            String(localized: "error_title"),
            isPresented: $isShowingError
        ) {
            Button(String(localized: "ok")) {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? String(localized: "error_occurred"))
        }
    }

    private func requestDownload(_ sample: SamplePDF) {
        if store.isUsingCellular {
            cellularDownload = sample
        } else {
            startDownload(sample, allowsCellular: false)
        }
    }

    private func initializeLanguageFilterIfNeeded() {
        guard !didInitializeLanguageFilter, let catalog = store.catalog else { return }
        let languageCodes = SamplePDFLanguageFilter.availableLanguageCodes(in: catalog.samples)
        selectedLanguageCode = SamplePDFLanguageFilter.initialLanguageCode(
            preferredLanguages: Locale.preferredLanguages,
            availableLanguageCodes: languageCodes
        )
        didInitializeLanguageFilter = true
    }

    private func filteredSamples(in catalog: SamplePDFCatalog) -> [SamplePDF] {
        guard let selectedLanguageCode else { return catalog.samples }
        return catalog.samples.filter { $0.languageCode == selectedLanguageCode }
    }

    private func startDownload(_ sample: SamplePDF, allowsCellular: Bool) {
        Task {
            await store.download(sample, allowsCellular: allowsCellular)
        }
    }

    private func isOpen(_ sample: SamplePDF) -> Bool {
        guard let openDocumentURL else { return false }
        return openDocumentURL.standardizedFileURL == store.localURL(for: sample).standardizedFileURL
    }
}

private struct SamplePDFLanguageFilterPicker: View {
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

private struct SamplePDFRow: View {
    let sample: SamplePDF
    let state: SamplePDFDownloadState
    let isOpen: Bool
    let isDownloadEnabled: Bool
    let downloadAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(sample.title)
                .font(.headline)

            Text(verbatim: "\(sample.languageDisplayName) · \(sample.formattedFileSize)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            action
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var action: some View {
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
            .accessibilityIdentifier("samplePDFDownload_\(sample.id)")
        case .downloading:
            HStack {
                ProgressView()
                Text(String(localized: "sample_pdf_downloading", defaultValue: "Downloading…"))
            }
            .accessibilityElement(children: .combine)
        case .downloaded:
            HStack {
                Label(
                    String(localized: "sample_pdf_downloaded", defaultValue: "Downloaded"),
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.green)

                Spacer()

                Button(
                    String(localized: "sample_pdf_delete_button", defaultValue: "Delete"),
                    role: .destructive,
                    action: deleteAction
                )
                .disabled(isOpen)
                .accessibilityHint(
                    isOpen
                        ? String(localized: "sample_pdf_close_before_delete", defaultValue: "Close this PDF before deleting it.")
                        : ""
                )
                .accessibilityIdentifier("samplePDFDelete_\(sample.id)")
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
