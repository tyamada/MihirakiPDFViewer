//
// MainView.swift
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
import UniformTypeIdentifiers
import UIKit

private struct PDFPasswordPromptState {
    var isPresented = false
    var pendingURL: URL?
    var password = ""
    var message: String?

    mutating func present(for url: URL, message: String? = nil) {
        pendingURL = url
        password = ""
        self.message = message
        isPresented = true
    }

    mutating func reset() {
        self = PDFPasswordPromptState()
    }
}

/// アプリケーションのメインビュー
public struct MainView: View {
    @State private var viewModel = PDFViewerViewModel(
        sessionURL: PDFViewerViewModel.defaultSessionURL, preferences: .standard
    )
    @Environment(\.scenePhase) private var scenePhase
    @State private var didInitializeDocument = false

    @State private var tipManager = TipManager.shared
    @State private var isShowingFilePicker = false
    @State private var isShowingErrorAlert = false
    @State private var isShowingSettings = false
    @State private var isShowingTipSuccessAlert = false
    @State private var isShowingTipErrorAlert = false
    @State private var lastTipProductID: String? = nil
    @State private var isPDFChromeVisible = false
    @State private var isScrollDirectionHintVisible = false
    @State private var scrollDirectionHintToken = UUID()
    @State private var pdfPasswordPrompt = PDFPasswordPromptState()
    private let incomingPDFImporter = IncomingPDFImporter()

    public init() {}

    private var tipSuccessMessage: String {
        String(localized: "tip_success_message", defaultValue: "Thank you for your support.")
    }

    public var body: some View {
        NavigationStack {
            mainContent
                .alert(String(localized: "error_title"), isPresented: $isShowingErrorAlert) {
                    Button(String(localized: "ok")) {
                        viewModel.errorMessage = nil
                    }
                } message: {
                    Text(viewModel.errorMessage ?? String(localized: "error_occurred"))
                }
                .onChange(of: viewModel.errorMessage) { _, newValue in
                    if newValue != nil {
                        isShowingErrorAlert = true
                    }
                }
                .alert(
                    String(localized: "pdf_password_dialog_title", defaultValue: "Password Required"),
                    isPresented: $pdfPasswordPrompt.isPresented
                ) {
                    SecureField(
                        String(localized: "pdf_password_placeholder", defaultValue: "Password"),
                        text: $pdfPasswordPrompt.password
                    )
                        .accessibilityIdentifier("pdfPasswordField")
                    Button(String(localized: "cancel"), role: .cancel) {
                        cancelPDFPasswordPrompt()
                    }
                    Button(String(localized: "pdf_password_unlock_button", defaultValue: "Unlock")) {
                        unlockPendingPDF()
                    }
                    .disabled(pdfPasswordPrompt.password.isEmpty)
                    .accessibilityIdentifier("pdfPasswordUnlockButton")
                } message: {
                    Text(
                        pdfPasswordPrompt.message
                            ?? String(localized: "pdf_password_dialog_message", defaultValue: "Enter the user password for this PDF.")
                    )
                        .accessibilityIdentifier("pdfPasswordMessage")
                }
                .sheet(isPresented: $isShowingSettings) {
                    settingsSheet
                }
                .alert(
                    String(localized: "tip_success_title", defaultValue: "Thank You for Your Support!"),
                    isPresented: $isShowingTipSuccessAlert
                ) {
                    if let iconName = tipManager.pendingAppIconName {
                        Button(String(localized: "change_app_icon", defaultValue: "Change Icon")) {
                            Task {
                                if await tipManager.changeAppIcon(named: iconName) {
                                    tipManager.resetSuccessFlag()
                                }
                            }
                        }
                    }

                    Button(String(localized: "ok")) {
                        tipManager.resetSuccessFlag()
                    }
                } message: {
                    Text(tipSuccessMessage)
                }
                .onChange(of: tipManager.isPurchaseSuccess) { _, newValue in
                    if newValue {
                        lastTipProductID = tipManager.lastPurchasedProductID
                        isShowingTipSuccessAlert = true
                    }
                }
                .alert(String(localized: "error_title"), isPresented: $isShowingTipErrorAlert) {
                    Button(String(localized: "ok")) {
                        tipManager.clearError()
                    }
                } message: {
                    Text(tipManager.errorMessage ?? String(localized: "error_occurred"))
                }
                .onChange(of: tipManager.errorMessage) { _, newValue in
                    if newValue != nil {
                        isShowingTipErrorAlert = true
                    }
                }
                .onAppear {
                    initializeDocumentIfNeeded()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                AppDiagnostics.becameActive()
            } else {
                AppDiagnostics.becameInactive()
                viewModel.saveReadingSession()
            }
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result: result)
        }
        .onOpenURL { url in
            handleIncomingPDFURL(url)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        makeDetailView()
    }

    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                AppDiagnostics.record(.documentSelectionFailed)
                viewModel.errorMessage = String(localized: "pdf_file_selection_failed", defaultValue: "Could not select the PDF file.")
                return
            }
            openPDF(at: url)
        case .failure(let error):
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
                AppDiagnostics.record(.documentPickerCancelled)
                return
            }
            AppDiagnostics.record(.documentSelectionFailed)
            viewModel.errorMessage = String(localized: "pdf_file_selection_failed", defaultValue: "Could not select the PDF file.")
        }
    }

    private func handleIncomingPDFURL(_ url: URL) {
        AppDiagnostics.record(.incomingDocumentReceived)
        guard url.pathExtension.localizedCaseInsensitiveCompare("pdf") == .orderedSame else {
            AppDiagnostics.record(.incomingDocumentRejected)
            viewModel.errorMessage = String(localized: "pdf_load_failed", defaultValue: "Could not load the PDF file.")
            return
        }

        do {
            let copiedURL = try incomingPDFImporter.copyImportedPDF(from: url)
            openPDF(at: copiedURL)
        } catch {
            AppDiagnostics.record(.incomingDocumentCopyFailed)
            viewModel.errorMessage = String(localized: "pdf_file_selection_failed", defaultValue: "Could not select the PDF file.")
        }
    }

    private func initializeDocumentIfNeeded() {
        guard !didInitializeDocument else { return }
        didInitializeDocument = true
        if ProcessInfo.processInfo.arguments.contains("-uiTestResetRenderingPreferences") {
            viewModel.resetApplicationSettings()
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTestResetReadingSession") {
            viewModel.clearReadingSession()
        }
        guard viewModel.document == nil, pdfPasswordPrompt.pendingURL == nil else { return }

        if let url = uiTestIncomingPDFURLFromLaunchArguments() {
            handleIncomingPDFURL(url)
        } else if let url = uiTestPDFURLFromLaunchArguments() {
            openPDF(at: url)
        } else if ProcessInfo.processInfo.arguments.contains("-uiTestLoadSamplePDF"),
                  let url = makeSamplePDFForUITests() {
            openPDF(at: url)
        } else if let url = viewModel.documentURLForRestoration() {
            openPDF(at: url)
        }
    }

    private func uiTestPDFURLFromLaunchArguments() -> URL? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let pathArgumentIndex = arguments.firstIndex(of: "-uiTestPDFPath"),
              arguments.indices.contains(pathArgumentIndex + 1) else {
            return nil
        }

        return URL(fileURLWithPath: arguments[pathArgumentIndex + 1])
    }

    private func uiTestIncomingPDFURLFromLaunchArguments() -> URL? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let pathArgumentIndex = arguments.firstIndex(of: "-uiTestIncomingPDFPath"),
              arguments.indices.contains(pathArgumentIndex + 1) else {
            return nil
        }

        return URL(fileURLWithPath: arguments[pathArgumentIndex + 1])
    }

    private func openPDF(at url: URL, password: String? = nil) {
        switch viewModel.loadDocument(from: url, password: password) {
        case .loaded:
            finishPDFLoad()
        case .passwordRequired:
            presentPDFPasswordPrompt(for: url)
        case .invalidPassword:
            presentPDFPasswordPrompt(
                for: url,
                message: String(localized: "pdf_password_incorrect", defaultValue: "The password is incorrect.")
            )
        case .failed:
            break
        }
    }

    private func finishPDFLoad() {
        pdfPasswordPrompt.reset()
        isPDFChromeVisible = false
        showScrollDirectionHint()
    }

    private func presentPDFPasswordPrompt(for url: URL, message: String? = nil) {
        pdfPasswordPrompt.present(for: url, message: message)
    }

    private func unlockPendingPDF() {
        guard let url = pdfPasswordPrompt.pendingURL else {
            return
        }

        let password = pdfPasswordPrompt.password
        Task { @MainActor in
            switch viewModel.loadDocument(from: url, password: password) {
            case .loaded:
                finishPDFLoad()
            case .invalidPassword:
                pdfPasswordPrompt.isPresented = false
                pdfPasswordPrompt.password = ""
                pdfPasswordPrompt.message = String(
                    localized: "pdf_password_incorrect",
                    defaultValue: "The password is incorrect."
                )
                try? await Task.sleep(for: .milliseconds(200))
                pdfPasswordPrompt.isPresented = true
            case .passwordRequired:
                pdfPasswordPrompt.isPresented = false
                pdfPasswordPrompt.password = ""
                try? await Task.sleep(for: .milliseconds(200))
                pdfPasswordPrompt.isPresented = true
            case .failed:
                break
            }
        }
    }

    private func cancelPDFPasswordPrompt() {
        pdfPasswordPrompt.reset()
        viewModel.cancelPendingDocumentLoad()
    }

    private func showScrollDirectionHint() {
        let token = UUID()
        scrollDirectionHintToken = token
        isScrollDirectionHintVisible = true

        Task {
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                if scrollDirectionHintToken == token {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isScrollDirectionHintVisible = false
                    }
                }
            }
        }
    }

    private func makeSamplePDFForUITests() -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MihirakiPDFViewerUITest")
            .appendingPathExtension("pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 320, height: 420))

        do {
            try renderer.writePDF(to: url) { context in
                for pageNumber in 1...3 {
                    context.beginPage()
                    let text = "UI Test Page \(pageNumber)"
                    text.draw(
                        at: CGPoint(x: 32, y: 32),
                        withAttributes: [.font: UIFont.systemFont(ofSize: 24)]
                    )
                }
            }
            return url
        } catch {
            return nil
        }
    }

    @ViewBuilder
    private var settingsSheet: some View {
        NavigationStack {
            SettingsView(viewModel: viewModel)
                .navigationTitle(String(localized: "settings"))
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isShowingSettings = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.primary)
                        }
                        .accessibilityLabel(String(localized: "close"))
                        .accessibilityIdentifier("settingsCloseButton")
                    }
                }
        }
    }

    @ViewBuilder
    private func makeDetailView() -> some View {
        if viewModel.document != nil {
            ZStack(alignment: .bottom) {
                PDFContainerView(
                    viewModel: viewModel,
                    isPDFChromeVisible: $isPDFChromeVisible,
                    isScrollDirectionHintVisible: isScrollDirectionHintVisible
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .top)
                .accessibilityIdentifier("pdfViewerScreen")

                if isPDFChromeVisible && viewModel.pageGroups.count > 1 {
                    PDFPageSliderView(
                        currentPageIndex: $viewModel.currentPageIndex,
                        pageCount: viewModel.pageGroups.count,
                        layoutDirection: viewModel.settings.layoutDirection
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                pdfToolbar
            }
            .toolbarVisibility(isPDFChromeVisible ? .visible : .hidden, for: .navigationBar)
        } else {
            makeEmptyStateView()
        }
    }

    @ToolbarContentBuilder
    private var pdfToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                AppDiagnostics.record(.settingsOpened)
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel(String(localized: "settings"))
            .accessibilityIdentifier("settingsButton")
        }

        ToolbarItem(placement: .principal) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(String(localized: "search"), text: $viewModel.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("searchField")
            }
            .frame(minWidth: 140, idealWidth: 280, maxWidth: 420)
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isPDFChromeVisible = false
                viewModel.closeDocument()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel(String(localized: "close"))
            .accessibilityIdentifier("closeDocumentButton")
        }
    }

    @ViewBuilder
    private func makeEmptyStateView() -> some View {
        PDFEmptyStateView(
            selectPDF: {
                AppDiagnostics.record(.documentPickerOpened)
                isShowingFilePicker = true
            },
            openDocument: { url in
                openPDF(at: url)
            },
            didDeleteDocument: { url in
                viewModel.clearReadingSession(ifMatching: url)
            },
            openSettings: {
                isShowingSettings = true
            }
        )
    }
}
