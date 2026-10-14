//
// SamplePDFListView.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import SwiftUI

struct SamplePDFListView: View {
    let openDocumentURL: URL?
    let openDocument: (URL) -> Void
    let didDeleteDocument: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var store = SamplePDFStore()
    @State private var cellularDownload: SamplePDF?
    @State private var deletionCandidate: SamplePDF?
    @State private var isShowingError = false
    @State private var selectedLanguageCode: String?
    @State private var didInitializeLanguageFilter = false
    @State private var areRowActionsSuppressed = false

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
                                areActionsSuppressed: areRowActionsSuppressed,
                                isDownloadEnabled: store.isNetworkPathKnown,
                                downloadAction: { requestDownload(sample) },
                                openAction: { open(sample) },
                                deleteAction: { requestDeletion(sample) }
                            )
                        }
                    } footer: {
                        Text(String(
                            localized: "sample_pdf_open_instructions",
                            defaultValue: "Tap Open next to a downloaded sample PDF to view it."
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
                finishDeletionPrompt()
            }
            Button(String(localized: "sample_pdf_delete_button", defaultValue: "Delete"), role: .destructive) {
                let url = store.localURL(for: sample)
                if store.delete(sample) {
                    didDeleteDocument(url)
                }
                finishDeletionPrompt()
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

    private func requestDeletion(_ sample: SamplePDF) {
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            deletionCandidate = sample
        }
    }

    private func finishDeletionPrompt() {
        areRowActionsSuppressed = true
        deletionCandidate = nil
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            areRowActionsSuppressed = false
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

    private func open(_ sample: SamplePDF) {
        guard !areRowActionsSuppressed else { return }
        openDocument(store.localURL(for: sample))
        dismiss()
    }

    private func isOpen(_ sample: SamplePDF) -> Bool {
        guard let openDocumentURL else { return false }
        return openDocumentURL.standardizedFileURL == store.localURL(for: sample).standardizedFileURL
    }
}
