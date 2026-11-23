//
// SettingsSupportViews.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import SwiftUI

struct SettingsSectionHeader: View {
    let title: LocalizedStringResource

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .accessibilityAddTraits(.isHeader)
    }
}
struct AppInformationRow: View {
    let label: LocalizedStringResource
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
            Text(value)
                .font(.body)
        }
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
    }
}

struct HighContrastSettingsButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                backgroundColor.opacity(backgroundOpacity(isPressed: configuration.isPressed)),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var foregroundColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private func backgroundOpacity(isPressed: Bool) -> Double {
        guard isEnabled else {
            return 0.45
        }

        guard isPressed else {
            return 1
        }

        return colorSchemeContrast == .increased ? 0.9 : 0.78
    }
}

struct DeviceTestingSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                DeviceTestView()
            } label: {
                Label("Run tests on this device", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(HighContrastSettingsButtonStyle())
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("runDeviceTestsButton")
        }
        .padding(.vertical)
    }
}

struct AppLoggingSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                AppLogView()
            } label: {
                Label("View app logs", systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(HighContrastSettingsButtonStyle())
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("viewAppLogsButton")
        }
    }
}
