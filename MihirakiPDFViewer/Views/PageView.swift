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

import SwiftUI
import PDFKit

public enum PageAlignment {
    case left
    case center
    case right
}

/// 個々のページを表示するためのSwiftUIビュー
public struct PageView: View {
    let page: PDFPage
    let size: CGSize
    let searchMatches: [PDFViewerViewModel.PDFSearchMatch]
    let alignment: PageAlignment

    public init(
        page: PDFPage,
        size: CGSize,
        searchMatches: [PDFViewerViewModel.PDFSearchMatch] = [],
        alignment: PageAlignment = .center
    ) {
        self.page = page
        self.size = size
        self.searchMatches = searchMatches
        self.alignment = alignment
    }

    public var body: some View {
        GeometryReader { geometry in
            let pageWidth = page.bounds(for: .mediaBox).size.width
            let pageHeight = page.bounds(for: .mediaBox).size.height
            
            // .aspectRatio(contentMode: .fit) によるスケーリングを考慮
            let scale = min(size.width / pageWidth, size.height / pageHeight)
            let renderedWidth = pageWidth * scale
            let renderedHeight = pageHeight * scale
            
            let offsetX = (geometry.size.width - renderedWidth) / 2
            let offsetY = (geometry.size.height - renderedHeight) / 2

            ZStack(alignment: .topLeading) {
                // PDFページの描画
                Image(uiImage: page.thumbnail(of: size, for: .mediaBox))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .position(x: alignmentPositionX(alignment: alignment, width: geometry.size.width, renderedWidth: renderedWidth), y: geometry.size.height / 2)

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

    private func alignmentPositionX(alignment: PageAlignment, width: CGFloat, renderedWidth: CGFloat) -> CGFloat {
        let positionX: CGFloat
        switch alignment {
        case .left:
            positionX = width / 2 + (width - renderedWidth) / 2
        case .center:
            positionX = width / 2
        case .right:
            positionX = width / 2 - (width - renderedWidth) / 2
        }
        return positionX
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
