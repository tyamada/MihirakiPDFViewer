//
// AppInformationView.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import SwiftUI

struct AppInformationView: View {
    @State private var tipManager = TipManager.shared

    var body: some View {
        List {
            AppIdentitySection(appName: appName, version: version, build: build)
            OwnedSupporterBadgesSection(ownedProductIDs: tipManager.ownedProductIDs)
            AppInformationLinksSection()
        }
        .navigationTitle("App Information")
        .accessibilityIdentifier("appInformationScreen")
        .task {
            await tipManager.refreshEntitlements()
        }
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Mihiraki PDF Viewer"
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? String(localized: "Not available")
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? String(localized: "Not available")
    }
}

private struct AppIdentitySection: View {
    let appName: String
    let version: String
    let build: String

    var body: some View {
        Section("App") {
            LabeledContent("Name", value: appName)
            LabeledContent("Version", value: version)
            LabeledContent("Build", value: build)
            LabeledContent("Copyright", value: String(localized: "copyright"))
        }
    }
}

private struct OwnedSupporterBadgesSection: View {
    let ownedProductIDs: Set<String>

    private var ownedTiers: [SupporterTier] {
        SupporterTier.allCases.filter { ownedProductIDs.contains($0.rawValue) }
    }

    var body: some View {
        Section("Supporter Badges") {
            if ownedTiers.isEmpty {
                ContentUnavailableView(
                    "No Badges Yet",
                    systemImage: "heart",
                    description: Text("Support the developer to unlock a supporter badge.")
                )
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 16) {
                        ForEach(ownedTiers) { tier in
                            VStack(spacing: 8) {
                                Image(tier.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 64, height: 64)
                                    .accessibilityHidden(true)
                                Text(tier.name)
                                    .font(.caption)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

private struct AppInformationLinksSection: View {
    var body: some View {
        Section {
            NavigationLink {
                LicenseView()
            } label: {
                Label("Open Source License", systemImage: "doc.plaintext")
            }
            NavigationLink {
                TipSelectionView(tipManager: TipManager.shared)
            } label: {
                Label("Support the Developer", systemImage: "heart.fill")
            }
        }
    }
}
