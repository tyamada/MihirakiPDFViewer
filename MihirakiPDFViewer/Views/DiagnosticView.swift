//
// DiagnosticView.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import SwiftUI

struct DiagnosticView: View {
    var body: some View {
        List {
            Section("Privacy") {
                Label {
                    Text("Diagnostic results and logs remain on this device unless you explicitly share them.")
                } icon: {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.green)
                }
            }

            Section("Diagnostic Tools") {
                NavigationLink {
                    DeviceTestView()
                } label: {
                    Label("Device Tests", systemImage: "stethoscope")
                }
                NavigationLink {
                    AppLogView()
                } label: {
                    Label("App Logs", systemImage: "doc.text.magnifyingglass")
                }
                NavigationLink {
                    IssueReportingGuideView()
                } label: {
                    Label("Report a Problem", systemImage: "exclamationmark.bubble")
                }
            }
        }
        .navigationTitle("Diagnostics")
        .accessibilityIdentifier("diagnosticScreen")
    }
}
