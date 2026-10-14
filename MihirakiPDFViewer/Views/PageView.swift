//
// PageView.swift
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

import PDFKit
import SwiftUI

public enum PageAlignment {
    case left
    case center
    case right
}

/// 個々のページを表示するためのSwiftUIビュー
public struct PageView: View {
    @Environment(\.displayScale) private var displayScale

    let page: PDFPage
    let pageNumber: Int?
    let size: CGSize
    let searchMatches: [PDFViewerViewModel.PDFSearchMatch]
    let alignment: PageAlignment
    let isHighQualityRenderingEnabled: Bool
    let isSharpnessEnabled: Bool

    public init(
        page: PDFPage,
        pageNumber: Int? = nil,
        size: CGSize,
        searchMatches: [PDFViewerViewModel.PDFSearchMatch] = [],
        alignment: PageAlignment = .center,
        isHighQualityRenderingEnabled: Bool = false,
        isSharpnessEnabled: Bool = false
    ) {
        self.page = page
        self.pageNumber = pageNumber
        self.size = size
        self.searchMatches = searchMatches
        self.alignment = alignment
        self.isHighQualityRenderingEnabled = isHighQualityRenderingEnabled
        self.isSharpnessEnabled = isSharpnessEnabled
    }

    public var body: some View {
        GeometryReader { geometry in
            let pageWidth = page.bounds(for: .mediaBox).size.width
            let pageHeight = page.bounds(for: .mediaBox).size.height
            
            // .aspectRatio(contentMode: .fit) によるスケーリングを考慮
            let scale = min(size.width / pageWidth, size.height / pageHeight)
            let renderedWidth = pageWidth * scale
            let renderedHeight = pageHeight * scale
            
            let offsetX = Self.alignedPageOriginX(
                alignment: alignment,
                containerWidth: geometry.size.width,
                renderedWidth: renderedWidth
            )
            let offsetY = (geometry.size.height - renderedHeight) / 2

            ZStack(alignment: .topLeading) {
                // PDFページの描画
                Image(uiImage: cachedPageImage(displaySize: size))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .position(x: offsetX + renderedWidth / 2, y: geometry.size.height / 2)
                    .accessibilityLabel(pageAccessibilityLabel)

                // ハイライトの描画
                ForEach(searchMatches) { match in
                    HighlightView(
                        match: match,
                        pageWidth: pageWidth,
                        pageHeight: pageHeight,
                        renderedSize: CGSize(width: renderedWidth, height: renderedHeight),
                        offset: CGSize(width: offsetX, height: offsetY)
                    )
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private func cachedPageImage(displaySize: CGSize) -> UIImage {
        PDFPageImageRenderer.shared.image(
            for: page,
            displaySize: displaySize,
            displayScale: displayScale,
            isHighQualityRenderingEnabled: isHighQualityRenderingEnabled,
            isSharpnessEnabled: isSharpnessEnabled
        )
    }

    static func alignedPageOriginX(
        alignment: PageAlignment,
        containerWidth: CGFloat,
        renderedWidth: CGFloat
    ) -> CGFloat {
        switch alignment {
        case .left:
            return containerWidth - renderedWidth
        case .center:
            return (containerWidth - renderedWidth) / 2
        case .right:
            return 0
        }
    }

    private var pageAccessibilityLabel: String {
        if let pageNumber {
            return String(localized: "pdf_page_accessibility_label", defaultValue: "Page \(pageNumber)")
        }

        return String(localized: "pdf_page_accessibility_label_unknown", defaultValue: "PDF page")
    }
}

struct HighlightView: View {
    let match: PDFViewerViewModel.PDFSearchMatch
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    let renderedSize: CGSize
    let offset: CGSize

    var body: some View {
        ForEach(Array(match.rects.enumerated()), id: \.offset) { index, rect in
            let transformedRect = transform(rect: rect)
            Rectangle()
                .fill(Color.yellow.opacity(0.3))
                .frame(width: transformedRect.width, height: transformedRect.height)
                .position(x: transformedRect.midX + offset.width, y: transformedRect.midY + offset.height)
        }
    }

    private func transform(rect: CGRect) -> CGRect {
        // PDFの座標系 (左下が原点) を SwiftUI の座標系 (左上が原点) に変換
        // また、PDFのポイントサイズを実際の描画サイズにスケーリングする
        let scaleX = renderedSize.width / pageWidth
        let scaleY = renderedSize.height / pageHeight
        
        let x = rect.origin.x * scaleX
        // PDFは下から上、SwiftUIは上から下
        let y = (pageHeight - rect.origin.y - rect.size.height) * scaleY
        let w = rect.size.width * scaleX
        let h = rect.size.height * scaleY
        
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
