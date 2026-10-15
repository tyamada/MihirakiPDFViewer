//
// HelpView.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import SwiftUI
import UIKit

struct HelpView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                HelpCategorySection(
                    title: "Getting Started",
                    items: HelpContent.gettingStarted
                )
                HelpCategorySection(
                    title: "Comfortable Reading",
                    items: HelpContent.comfortableReading
                )
                HelpCategorySection(
                    title: "Settings Guide",
                    items: HelpContent.settingsGuide
                )
                HelpCategorySection(
                    title: "Diagnostics",
                    items: HelpContent.diagnostics
                )
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .accessibilityIdentifier("helpScreen")
        .navigationTitle("Help")
    }
}

private struct HelpCategorySection: View {
    let title: LocalizedStringResource
    let items: [HelpItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            ForEach(items) { item in
                HelpAccordionCard(item: item)
            }
        }
    }
}

private struct HelpAccordionCard: View {
    let item: HelpItem
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                HelpRichText(resource: item.description)

                ForEach(item.details) { detail in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(detail.title)
                            .font(.subheadline.weight(.semibold))
                        HelpRichText(resource: detail.description)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Text(item.title)
                .font(.headline)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .accessibilityIdentifier("helpItem_\(item.id)")
    }
}

private struct HelpRichText: View {
    let resource: LocalizedStringResource

    var body: some View {
        Text(attributedText)
            .font(.body)
            .foregroundStyle(.secondary)
    }

    private var attributedText: AttributedString {
        let source = String(localized: resource)
        guard source.contains("<"),
              let data = source.data(using: .utf8),
              let richText = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            return AttributedString(source)
        }
        return AttributedString(richText)
    }
}
