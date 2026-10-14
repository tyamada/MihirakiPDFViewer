//
// HelpView.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import SwiftUI

struct HelpView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(HelpContent.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(item.id). \(String(localized: item.title))")
                            .font(.headline)
                        Text(item.description)
                            .font(.body)

                        ForEach(item.details) { detail in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(detail.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(detail.description)
                                    .font(.body)
                            }
                            .padding(.leading, 16)
                        }
                    }
                    .foregroundStyle(textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .background(backgroundColor)
        }
        .foregroundStyle(textColor)
        .background(backgroundColor)
        .accessibilityIdentifier("helpScreen")
        .navigationTitle(String(localized: "help_title", defaultValue: "Help"))
    }
}
