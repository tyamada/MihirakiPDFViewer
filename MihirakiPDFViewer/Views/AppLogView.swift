//
//  AppLogView.swift
//  MihirakiPDFViewer
//
//  Copyright 2026 Takuma Yamada.
//

import SwiftUI

struct AppLogView: View {
    @State private var entries: [AppLogEntry] = []
    @State private var isLoading = true

    var body: some View {
        List {
            AppLogPrivacySection()

            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading logs…")
                        Spacer()
                    }
                }
            } else if entries.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No logs",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("There are no logs from the last 24 hours.")
                    )
                }
            } else {
                Section("Last 24 hours") {
                    ForEach(entries) { entry in
                        AppLogEntryRow(entry: entry)
                    }
                }
            }
        }
        .navigationTitle("App Logs")
        .accessibilityIdentifier("appLogScreen")
        .toolbar {
            if !entries.isEmpty {
                ShareLink(item: AppLogExportFormatter.text(for: entries)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("shareAppLogsButton")
            }

            Button {
                Task {
                    await loadEntries()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .accessibilityIdentifier("refreshAppLogsButton")
        }
        .task {
            await loadEntries()
        }
    }

    private func loadEntries() async {
        isLoading = true
        entries = await AppLogStore.shared.recentEntries()
        isLoading = false
    }
}

private struct AppLogPrivacySection: View {
    var body: some View {
        Section("Privacy") {
            Label {
                Text("Logs never include personal information, file names, file paths, search terms, passwords, or document contents.")
            } icon: {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.green)
            }

            Label {
                Text("Logs are stored only on this device and are never sent externally automatically. Sharing occurs only when you tap Share.")
            } icon: {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.green)
            }
            .accessibilityIdentifier("appLogNoAutomaticSendingNotice")

            Text("Logs older than 24 hours are deleted automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AppLogEntryRow: View {
    let entry: AppLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .foregroundStyle(levelColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.event.rawValue)
                    .font(.body)
                Text(entry.timestamp, format: .dateTime.year().month().day().hour().minute().second())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                AppLogEntryDetails(
                    durationMilliseconds: entry.durationMilliseconds,
                    numericValue: entry.numericValue,
                    numericLabel: entry.numericLabel
                )
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var symbolName: String {
        switch entry.level {
        case .info:
            "info.circle.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .error:
            "xmark.circle.fill"
        case .fault:
            "bolt.trianglebadge.exclamationmark.fill"
        }
    }

    private var levelColor: Color {
        switch entry.level {
        case .info:
            .blue
        case .warning:
            .orange
        case .error, .fault:
            .red
        }
    }
}

private struct AppLogEntryDetails: View {
    let durationMilliseconds: Int?
    let numericValue: Int?
    let numericLabel: AppLogNumericLabel?

    var body: some View {
        if let durationMilliseconds {
            Text("Duration: \(durationMilliseconds) ms")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if let numericValue, let numericLabel {
            Text("\(numericLabel.localizedName): \(numericValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private extension AppLogNumericLabel {
    var localizedName: LocalizedStringResource {
        switch self {
        case .page:
            "Page"
        case .pages:
            "Pages"
        case .matches:
            "Matches"
        }
    }
}
