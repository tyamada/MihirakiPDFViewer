//
//  DeviceTestView.swift
//  MihirakiPDFViewer
//
//  Copyright 2026 Takuma Yamada.
//

import SwiftUI

struct DeviceTestView: View {
    @State private var report: DeviceTestReport?
    @State private var isRunning = false

    var body: some View {
        List {
            DeviceTestPrivacyNotice()

            if isRunning {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Running tests…")
                        Spacer()
                    }
                }
            } else if let report {
                DeviceTestMetadataSection(
                    testedAt: report.testedAt,
                    deviceName: report.deviceName,
                    deviceModel: report.deviceModel,
                    osVersion: report.osVersion,
                    appVersion: report.appVersion,
                    totalMemoryBytes: report.totalMemoryBytes,
                    availableMemoryBytes: report.availableMemoryBytes
                )
                DeviceTestChecksSection(checks: report.checks)
            }

            Section {
                Button {
                    runTests()
                } label: {
                    Label("Run tests again", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .disabled(isRunning)
                .accessibilityIdentifier("rerunDeviceTestsButton")
            }
        }
        .navigationTitle("Device Test Results")
        .accessibilityIdentifier("deviceTestResultsScreen")
        .toolbar {
            if let report {
                ShareLink(item: report.shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("shareDeviceTestResultsButton")
            }
        }
        .task {
            guard report == nil else { return }
            runTests()
        }
    }

    private func runTests() {
        isRunning = true
        report = DeviceTestRunner.run()
        isRunning = false
    }
}

private struct DeviceTestPrivacyNotice: View {
    var body: some View {
        Section("Privacy") {
            Label {
                Text("Test results are stored only on this device and are never sent externally automatically.")
            } icon: {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.green)
            }
        }
    }
}

private struct DeviceTestMetadataSection: View {
    let testedAt: Date
    let deviceName: String
    let deviceModel: String
    let osVersion: String
    let appVersion: String
    let totalMemoryBytes: UInt64
    let availableMemoryBytes: UInt64

    var body: some View {
        Section("Test information") {
            LabeledContent("Test date") {
                Text(testedAt, format: .dateTime.year().month().day().hour().minute().second())
            }
            LabeledContent("Device name", value: deviceName)
            LabeledContent("Model", value: deviceModel)
            LabeledContent("OS version", value: osVersion)
            LabeledContent("App version", value: appVersion)
            LabeledContent(
                "Total memory",
                value: ByteCountFormatter.string(fromByteCount: Int64(totalMemoryBytes), countStyle: .memory)
            )
            LabeledContent(
                "Available memory",
                value: ByteCountFormatter.string(fromByteCount: Int64(availableMemoryBytes), countStyle: .memory)
            )
        }
    }
}

private struct DeviceTestChecksSection: View {
    let checks: [DeviceTestReport.Check]

    var body: some View {
        Section("Results") {
            ForEach(checks) { check in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: check.status == .passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(check.status == .passed ? .green : .red)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(check.name)
                        if let detail = check.detail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Text(check.status == .passed ? "Passed" : "Failed")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
