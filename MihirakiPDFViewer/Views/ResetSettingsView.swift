//
// ResetSettingsView.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import SwiftUI

struct ResetSettingsView: View {
    @Bindable var viewModel: PDFViewerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingResetConfirmation = false
    @State private var isResetting = false

    private var backgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(String(localized: "reset_settings_and_icon_message", defaultValue: "This resets viewing settings, restores the default app icon, and closes the current document. Purchased supporter icons remain available."))
                .font(.body)
                .foregroundStyle(textColor)

            Spacer()

            HStack(spacing: 12) {
                Button(String(localized: "cancel")) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("cancelResetButton")

                Button(String(localized: "reset_title", defaultValue: "Reset"), role: .destructive) {
                    isShowingResetConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(isResetting)
                .accessibilityIdentifier("confirmResetButton")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(textColor)
        .background(backgroundColor)
        .accessibilityIdentifier("resetSettingsScreen")
        .navigationTitle(String(localized: "reset_title", defaultValue: "Reset"))
        .alert(
            String(localized: "reset_confirmation_title", defaultValue: "Reset Settings?"),
            isPresented: $isShowingResetConfirmation
        ) {
            Button(String(localized: "cancel"), role: .cancel) {}
            Button(String(localized: "reset_title", defaultValue: "Reset"), role: .destructive) {
                resetSettings()
            }
        } message: {
            Text(String(localized: "reset_settings_and_icon_message", defaultValue: "This resets viewing settings, restores the default app icon, and closes the current document. Purchased supporter icons remain available."))
        }
    }

    private func resetSettings() {
        isResetting = true
        Task {
            _ = await TipManager.shared.changeAppIcon(named: nil)
            viewModel.resetApplicationSettings()
            isResetting = false
            dismiss()
        }
    }
}
