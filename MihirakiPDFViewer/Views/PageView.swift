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

import CoreImage
import CoreImage.CIFilterBuiltins
import PDFKit
import SwiftUI
import UIKit

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
            
            let offsetX = (geometry.size.width - renderedWidth) / 2
            let offsetY = (geometry.size.height - renderedHeight) / 2

            ZStack(alignment: .topLeading) {
                // PDFページの描画
                Image(uiImage: renderedPageImage(displaySize: size))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .position(x: alignmentPositionX(alignment: alignment, width: geometry.size.width, renderedWidth: renderedWidth), y: geometry.size.height / 2)
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

    private func renderedPageImage(displaySize: CGSize) -> UIImage {
        guard displaySize.width > 0, displaySize.height > 0 else {
            return UIImage()
        }

        let screenScale = max(displayScale, 1)
        let qualityMultiplier: CGFloat = isHighQualityRenderingEnabled ? 2 : 1
        let targetScale = screenScale * qualityMultiplier
        let maxPixelLength: CGFloat = isHighQualityRenderingEnabled ? 4096 : 2048
        let longestPixelLength = max(displaySize.width, displaySize.height) * targetScale
        let scale = longestPixelLength > maxPixelLength ? maxPixelLength / max(displaySize.width, displaySize.height) : targetScale
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: displaySize, format: format)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: displaySize))

            let cgContext = context.cgContext
            let pageBounds = page.bounds(for: .mediaBox)
            let pageScale = min(displaySize.width / pageBounds.width, displaySize.height / pageBounds.height)
            let renderSize = CGSize(width: pageBounds.width * pageScale, height: pageBounds.height * pageScale)
            let origin = CGPoint(
                x: (displaySize.width - renderSize.width) / 2,
                y: (displaySize.height - renderSize.height) / 2
            )

            cgContext.saveGState()
            cgContext.translateBy(x: origin.x, y: origin.y + renderSize.height)
            cgContext.scaleBy(x: pageScale, y: -pageScale)
            cgContext.translateBy(x: -pageBounds.minX, y: -pageBounds.minY)
            page.draw(with: .mediaBox, to: cgContext)
            cgContext.restoreGState()
        }

        guard isSharpnessEnabled else {
            return image
        }

        return sharpenedImage(image) ?? image
    }

    private func sharpenedImage(_ image: UIImage) -> UIImage? {
        guard let inputImage = CIImage(image: image) else {
            return nil
        }

        let filter = CIFilter.sharpenLuminance()
        filter.inputImage = inputImage
        filter.sharpness = 0.45

        guard let outputImage = filter.outputImage,
              let cgImage = CIContext().createCGImage(outputImage, from: inputImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
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
