//
// IssueReportingViews.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import SwiftUI

struct LicenseView: View {
    private static let licenseText = """
    MIT License

    Copyright (c) 2026 Takuma Yamada

    Permission is hereby granted, free of charge, to any person, including without limitation all persons who obtain a copy of this software or other materials provided under this license, to deal in the software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the software, and to permit persons to do so subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
    """

    var body: some View {
        ScrollView {
            Text(verbatim: Self.licenseText)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle("License")
        .accessibilityIdentifier("licenseScreen")
    }
}
struct IssueReportingGuideView: View {
    private let newIssueURL = URL(
        string: "https://github.com/tyamada/MihirakiPDFViewer/issues/new?template=bug_report.yml"
    )

    var body: some View {
        List {
            IssueReportingIntroductionSection()
            IssueReportingPreparationSection()

            Section("Diagnostic information") {
                NavigationLink {
                    AppLogView()
                } label: {
                    Label("View app logs", systemImage: "doc.text.magnifyingglass")
                }
                .accessibilityIdentifier("reportProblemAppLogsButton")

                NavigationLink {
                    DeviceTestView()
                } label: {
                    Label("Run tests on this device", systemImage: "checkmark.circle")
                }
                .accessibilityIdentifier("reportProblemDeviceTestsButton")
            }

            IssueReportingPrivacySection()

            if let newIssueURL {
                Section {
                    Link(destination: newIssueURL) {
                        Label("Open GitHub Issues", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("openGitHubIssuesButton")
                } footer: {
                    Text("A GitHub account is required. The information you submit may be publicly visible.")
                }
            }
        }
        .navigationTitle("Report a Problem")
        .accessibilityIdentifier("issueReportingGuideScreen")
    }
}

private struct IssueReportingIntroductionSection: View {
    var body: some View {
        Section {
            Text("If you encounter a problem, please collect the information below and submit a report on GitHub Issues.")
        } header: {
            Text("Before reporting")
        }
    }
}

private struct IssueReportingPreparationSection: View {
    var body: some View {
        Section("Include in your report") {
            Label("A short summary of the problem", systemImage: "1.circle")
            Label("Steps that reproduce the problem", systemImage: "2.circle")
            Label("What you expected and what actually happened", systemImage: "3.circle")
            Label("How often the problem occurs", systemImage: "4.circle")
            Label("Your app version, OS version, device, and relevant viewing settings", systemImage: "5.circle")
            Label("A screenshot, app logs, or device test results when helpful", systemImage: "6.circle")
        }
    }
}

private struct IssueReportingPrivacySection: View {
    var body: some View {
        Section("Protect your privacy") {
            Label {
                Text("Do not attach the PDF itself or include document contents, file names, names, or other personal information.")
            } icon: {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.orange)
            }

            Label {
                Text("Check screenshots and diagnostic information before posting. Nothing is sent automatically.")
            } icon: {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.green)
            }
        }
    }
}
