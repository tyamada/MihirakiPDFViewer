//
// PDFOutlineTests.swift
// MihirakiPDFViewerTests
//
// Copyright 2026 Takuma Yamada.
//

import PDFKit
import Testing
@testable import MihirakiPDFViewer

struct PDFOutlineTests {
    @Test
    func buildsNestedOutlineWithStableIdentityAndPageMetadata() throws {
        let document = PDFDocument()
        let firstPage = PDFPage()
        let secondPage = PDFPage()
        document.insert(firstPage, at: 0)
        document.insert(secondPage, at: 1)

        let root = PDFOutline()
        let chapter = PDFOutline()
        chapter.label = "Chapter"
        chapter.destination = PDFDestination(page: firstPage, at: .zero)
        let section = PDFOutline()
        section.label = "Section"
        section.destination = PDFDestination(page: secondPage, at: .zero)
        chapter.insertChild(section, at: 0)
        root.insertChild(chapter, at: 0)
        document.outlineRoot = root

        let firstResult = PDFOutlineTreeBuilder.nodes(from: document)
        let secondResult = PDFOutlineTreeBuilder.nodes(from: document)
        let chapterNode = try #require(firstResult.first)
        let sectionNode = try #require(chapterNode.children.first)

        #expect(firstResult == secondResult)
        #expect(chapterNode.id == "0")
        #expect(chapterNode.title == "Chapter")
        #expect(chapterNode.pageIndex == 0)
        #expect(sectionNode.id == "0.0")
        #expect(sectionNode.title == "Section")
        #expect(sectionNode.pageIndex == 1)
    }

    @Test
    func preservesContainerWithoutDestination() throws {
        let document = PDFDocument()
        let page = PDFPage()
        document.insert(page, at: 0)

        let root = PDFOutline()
        let container = PDFOutline()
        container.label = "Part"
        let child = PDFOutline()
        child.label = "Chapter"
        child.destination = PDFDestination(page: page, at: .zero)
        container.insertChild(child, at: 0)
        root.insertChild(container, at: 0)
        document.outlineRoot = root

        let node = try #require(PDFOutlineTreeBuilder.nodes(from: document).first)
        #expect(node.pageIndex == nil)
        #expect(node.children.count == 1)
    }

    @Test
    func returnsEmptyListWhenDocumentHasNoOutline() {
        #expect(PDFOutlineTreeBuilder.nodes(from: PDFDocument()).isEmpty)
    }
}
