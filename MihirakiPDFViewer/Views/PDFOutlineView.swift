//
// PDFOutlineView.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import SwiftUI

struct PDFOutlineView: View {
    let nodes: [PDFOutlineNode]
    let currentPageIndices: Set<Int>
    let onSelectPage: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Table of Contents")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
        .accessibilityIdentifier("tableOfContentsScreen")
    }

    @ViewBuilder
    private var content: some View {
        if nodes.isEmpty {
            ContentUnavailableView(
                "No Table of Contents",
                systemImage: "list.bullet.rectangle",
                description: Text("This PDF does not contain table of contents information.")
            )
            .accessibilityIdentifier("tableOfContentsEmptyState")
        } else {
            List {
                OutlineGroup(nodes, children: \.outlineChildren) { node in
                    PDFOutlineRow(
                        title: node.title,
                        pageLabel: node.pageLabel,
                        pageIndex: node.pageIndex,
                        isCurrent: node.pageIndex.map(currentPageIndices.contains) ?? false,
                        selectPage: selectPage
                    )
                }
            }
            .accessibilityIdentifier("tableOfContentsList")
        }
    }

    private func selectPage(_ pageIndex: Int) {
        onSelectPage(pageIndex)
        dismiss()
    }
}

private struct PDFOutlineRow: View {
    let title: String
    let pageLabel: String?
    let pageIndex: Int?
    let isCurrent: Bool
    let selectPage: (Int) -> Void

    var body: some View {
        if let pageIndex {
            Button {
                selectPage(pageIndex)
            } label: {
                PDFOutlineRowLabel(
                    title: title,
                    pageLabel: pageLabel,
                    isCurrent: isCurrent
                )
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isCurrent ? .isSelected : [])
        } else {
            PDFOutlineRowLabel(
                title: title,
                pageLabel: nil,
                isCurrent: false
            )
            .accessibilityAddTraits(.isHeader)
        }
    }
}

private struct PDFOutlineRowLabel: View {
    let title: String
    let pageLabel: String?
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            if let pageLabel {
                Text(pageLabel)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if isCurrent {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
