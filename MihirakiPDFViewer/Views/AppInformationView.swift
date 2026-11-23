//
// AppInformationView.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import SwiftUI
import UIKit

struct AppInformationView: View {
    @State private var tipManager = TipManager.shared

    var body: some View {
        List {
            AppIdentitySection(appName: appName, version: version, build: build)
            OwnedSupporterBadgesSection(ownedTiers: tipManager.displayedSupporterTiers)
            AppInformationLinksSection()
        }
        .navigationTitle("App Information")
        .accessibilityIdentifier("appInformationScreen")
        .task {
            await tipManager.refreshEntitlements()
        }
        .task {
            await tipManager.recheckKoyomiEligibility()
        }
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? String(localized: "app_name", defaultValue: "Mihiraki: Two-Page PDF Reader")
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
    let ownedTiers: [SupporterTier]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedTier: SupporterTier?

    var body: some View {
        Section("Supporter Badges") {
            if ownedTiers.isEmpty {
                ContentUnavailableView(
                    "No Badges Yet",
                    systemImage: "heart",
                    description: Text("Support the developer to unlock a supporter badge.")
                )
            } else {
                LazyVGrid(columns: badgeColumns, alignment: .center, spacing: 16) {
                    ForEach(ownedTiers) { tier in
                        Button { selectedTier = tier } label: {
                            badgeLabel(tier)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(tier.name))
                        .accessibilityHint(String(localized: "badge_view_details_hint", defaultValue: "View badge details"))
                        .accessibilityIdentifier(tier == .koyomi ? "koyomiBadgeDetailsButton" : "supporterBadgeDetailsButton_\(tier.rawValue)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .sheet(item: $selectedTier) { tier in
            SupporterBadgeDetailView(tier: tier)
        }
    }

    private var badgeColumns: [GridItem] {
        // Accessibility sizes use one column; normal text wraps into as many rows as needed.
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 100), spacing: 16)]
    }

    private func badgeLabel(_ tier: SupporterTier) -> some View {
        VStack(spacing: 8) {
            Image(tier.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            Text(tier.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AppInformationLinksSection: View {
    var body: some View {
        Section {
            PrivacyPolicyLink()
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


/// An unobtrusive, accessible notice. It never requests a new page focus.
struct KoyomiBadgeClaimToast: View {
    let dismiss: () -> Void
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverEnabled

    var body: some View {
        Button(action: dismiss) {
            HStack(spacing: 12) {
                Image("KoyomiV2Badge")
                    .resizable().scaledToFit().frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                Text(String(localized: "koyomi_badge_claimed", defaultValue: "Koyomi badge acquired"))
                    .font(.headline).multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "xmark.circle.fill").accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 5)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(String(localized: "close"))
        .accessibilityIdentifier("koyomiBadgeClaimToast")
        .onAppear {
            if UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .announcement,
                    argument: String(localized: "koyomi_badge_claimed", defaultValue: "Koyomi badge acquired"))
            }
        }
        .task(id: isVoiceOverEnabled) {
            // Keep it available until dismissed when VoiceOver is in use.
            guard !isVoiceOverEnabled else { return }
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }
}

/// Preserve the Support screen entry point while sharing all badge detail presentation.
struct KoyomiBadgeDetailView: View {
    var body: some View {
        SupporterBadgeDetailView(tier: .koyomi)
    }
}

struct SupporterBadgeDetailView: View {
    let tier: SupporterTier
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(tier.imageName)
                        .resizable().scaledToFit().frame(maxWidth: 240, maxHeight: 240)
                        .accessibilityLabel(Text(tier.name))
                        .accessibilityAddTraits(.isImage)
                        .accessibilityIdentifier("supporterBadgeDetailImage_\(tier.rawValue)")
                    Text(tier.name)
                        .font(.title2.bold()).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(badgeDescription)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity).padding(24)
            }
            // Preserve native VoiceOver scrolling while containing all scroll rendering.
            .scrollClipDisabled(false)
            .clipped()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier(tier == .koyomi ? "koyomiBadgeDetailsDone" : "supporterBadgeDetailsDone")
                }
            }
        }
        // Bound the full navigation presentation, including during accessibility scrolling.
        .clipped()
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier(tier == .koyomi ? "koyomiBadgeDetailView" : "supporterBadgeDetailView_\(tier.rawValue)")
    }

    private var badgeDescription: String {
        tier == .koyomi
            ? String(localized: "koyomi_badge_description",
                defaultValue: "A Koyomi badge commemorating this app’s release.")
            : String(localized: "supporter_badge_description",
                defaultValue: "A badge recognizing your support for this app’s development.")
    }
}
