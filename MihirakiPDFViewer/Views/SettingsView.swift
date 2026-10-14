//
// SettingView.swift
// MihirakiPDFViewer
//
// Created by Cline on 2026/07/02.
// Reviewed & Updated by Takuma Yamada.
//
// Copyright 2026 Takuma Yamada.
//
// This software is released under the MIT License.
// For the full license text, please see the LICENSE file in the root directory.
//

import SwiftUI

/// 設定変更を行うためのビュー
public struct SettingsView: View {
    @Bindable var viewModel: PDFViewerViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingPromotionCodeInstructions = false
    @State private var isShowingTipSelection = false
    
    public init(viewModel: PDFViewerViewModel) {
        self.viewModel = viewModel
    }

    private var settingsBackgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var settingsTextColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DisplaySettingsSection(
                    viewModel: viewModel,
                    backgroundColor: settingsBackgroundColor
                )
                DocumentInformationSection(
                    document: viewModel.document,
                    textColor: settingsTextColor,
                    backgroundColor: settingsBackgroundColor
                )
                SettingsOptionsSection(
                    viewModel: viewModel,
                    backgroundColor: settingsBackgroundColor
                )
                SettingsHelpSection(backgroundColor: settingsBackgroundColor)
                SettingsAppInformationSection(backgroundColor: settingsBackgroundColor)
                DeveloperSupportSettingsSection(
                    textColor: settingsTextColor,
                    backgroundColor: settingsBackgroundColor,
                    isShowingTipSelection: $isShowingTipSelection,
                    isShowingPromotionCodeInstructions: $isShowingPromotionCodeInstructions
                )
            }
            .padding()
            .background(settingsBackgroundColor)
        }
        .foregroundStyle(settingsTextColor)
        .background(settingsBackgroundColor)
        .accessibilityIdentifier("settingsScreen")
        .navigationTitle(String(localized: "settings"))
        .navigationDestination(isPresented: $isShowingTipSelection) {
            TipSelectionView(tipManager: TipManager.shared)
        }
        .alert(
            String(localized: "enter_promotion_code", defaultValue: "Enter Promotion Code"),
            isPresented: $isShowingPromotionCodeInstructions
        ) {
            Button(String(localized: "go_to_support_screen", defaultValue: "Go to Support Screen")) {
                isShowingTipSelection = true
            }
            Button(String(localized: "cancel", defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(
                localized: "promotion_code_instructions",
                defaultValue: "To use a promotion code, go to the Support screen and enter the code from the promotion code option."
            ))
        }
    }
}
