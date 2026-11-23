//
// PDFOutlineNode.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import Foundation
import PDFKit

struct PDFOutlineNode: Identifiable, Equatable {
    let id: String
    let title: String
    let pageIndex: Int?
    let pageLabel: String?
    let children: [PDFOutlineNode]

    var outlineChildren: [PDFOutlineNode]? {
        children.isEmpty ? nil : children
    }
}

enum PDFOutlineTreeBuilder {
    private static let maximumDepth = 64

    static func nodes(from document: PDFDocument) -> [PDFOutlineNode] {
        guard let root = document.outlineRoot else { return [] }
        return children(of: root, in: document, path: [], depth: 0)
    }

    private static func children(
        of outline: PDFOutline,
        in document: PDFDocument,
        path: [Int],
        depth: Int
    ) -> [PDFOutlineNode] {
        guard depth < maximumDepth else { return [] }

        return (0..<outline.numberOfChildren).compactMap { childIndex in
            guard let child = outline.child(at: childIndex) else { return nil }
            let childPath = path + [childIndex]
            let nestedChildren = children(
                of: child,
                in: document,
                path: childPath,
                depth: depth + 1
            )
            let title = child.label?.trimmingCharacters(in: .whitespacesAndNewlines)
            let page = child.destination?.page
            let rawPageIndex = page.map { document.index(for: $0) }
            let pageIndex = rawPageIndex.flatMap { $0 == NSNotFound ? nil : $0 }

            guard !(title?.isEmpty ?? true) || !nestedChildren.isEmpty else {
                return nil
            }

            let displayTitle = title.flatMap { $0.isEmpty ? nil : $0 }
                ?? String(localized: "Untitled")
            return PDFOutlineNode(
                id: childPath.map(String.init).joined(separator: "."),
                title: displayTitle,
                pageIndex: pageIndex,
                pageLabel: page?.label,
                children: nestedChildren
            )
        }
    }
}
