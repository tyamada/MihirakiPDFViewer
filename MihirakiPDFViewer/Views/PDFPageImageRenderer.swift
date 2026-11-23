//
// PDFPageImageRenderer.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//
// This software is released under the MIT License.
// For the full license text, please see the LICENSE file in the root directory.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import PDFKit
import UIKit

final class PDFPageImageCache {
    static let shared = PDFPageImageCache()

    private let cache = NSCache<PDFPageRenderKey, UIImage>()

    init(countLimit: Int = 24, totalCostLimit: Int = 128 * 1_024 * 1_024) {
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }

    func image(
        for page: PDFPage,
        displaySize: CGSize,
        displayScale: CGFloat,
        isHighQualityRenderingEnabled: Bool,
        isSharpnessEnabled: Bool,
        sharpnessAmount: Double? = nil,
        render: () -> UIImage
    ) -> UIImage {
        let key = PDFPageRenderKey(
            page: page,
            displaySize: displaySize,
            displayScale: displayScale,
            isHighQualityRenderingEnabled: isHighQualityRenderingEnabled,
            sharpnessAmount: sharpnessAmount ?? (isSharpnessEnabled ? 0.45 : 0)
        )
        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }

        let image = render()
        let pixelWidth = Int((image.size.width * image.scale).rounded(.up))
        let pixelHeight = Int((image.size.height * image.scale).rounded(.up))
        let estimatedCost = pixelWidth * pixelHeight * 4
        cache.setObject(image, forKey: key, cost: estimatedCost)
        return image
    }

    func removeAllImages() {
        cache.removeAllObjects()
    }
}

private final class PDFPageRenderKey: NSObject {
    private let page: PDFPage
    private let width: CGFloat
    private let height: CGFloat
    private let displayScale: CGFloat
    private let isHighQualityRenderingEnabled: Bool
    private let sharpnessAmount: Double

    init(
        page: PDFPage,
        displaySize: CGSize,
        displayScale: CGFloat,
        isHighQualityRenderingEnabled: Bool,
        sharpnessAmount: Double
    ) {
        self.page = page
        self.width = displaySize.width
        self.height = displaySize.height
        self.displayScale = displayScale
        self.isHighQualityRenderingEnabled = isHighQualityRenderingEnabled
        self.sharpnessAmount = sharpnessAmount
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(ObjectIdentifier(page))
        hasher.combine(width)
        hasher.combine(height)
        hasher.combine(displayScale)
        hasher.combine(isHighQualityRenderingEnabled)
        hasher.combine(sharpnessAmount)
        return hasher.finalize()
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? PDFPageRenderKey else { return false }
        return page === other.page
            && width == other.width
            && height == other.height
            && displayScale == other.displayScale
            && isHighQualityRenderingEnabled == other.isHighQualityRenderingEnabled
            && sharpnessAmount == other.sharpnessAmount
    }
}

final class PDFPageImageRenderer {
    static let shared = PDFPageImageRenderer()

    private let cache: PDFPageImageCache
    private let imageContext = CIContext()

    init(cache: PDFPageImageCache = .shared) {
        self.cache = cache
    }

    func image(
        for page: PDFPage,
        displaySize: CGSize,
        displayScale: CGFloat,
        isHighQualityRenderingEnabled: Bool,
        isSharpnessEnabled: Bool,
        sharpnessAmount: Double? = nil
    ) -> UIImage {
        cache.image(
            for: page,
            displaySize: displaySize,
            displayScale: displayScale,
            isHighQualityRenderingEnabled: isHighQualityRenderingEnabled,
            isSharpnessEnabled: isSharpnessEnabled,
            sharpnessAmount: sharpnessAmount
        ) {
            render(
                page: page,
                displaySize: displaySize,
                displayScale: displayScale,
                isHighQualityRenderingEnabled: isHighQualityRenderingEnabled,
                sharpnessAmount: sharpnessAmount ?? (isSharpnessEnabled ? 0.45 : 0)
            )
        }
    }

    private func render(
        page: PDFPage,
        displaySize: CGSize,
        displayScale: CGFloat,
        isHighQualityRenderingEnabled: Bool,
        sharpnessAmount: Double
    ) -> UIImage {
        guard displaySize.width > 0, displaySize.height > 0 else {
            AppDiagnostics.record(.invalidRenderSize)
            return UIImage()
        }

        let startedAt = ProcessInfo.processInfo.systemUptime
        let screenScale = max(displayScale, 1)
        let qualityMultiplier: CGFloat = isHighQualityRenderingEnabled ? 2 : 1
        let targetScale = screenScale * qualityMultiplier
        let maxPixelLength: CGFloat = isHighQualityRenderingEnabled ? 4096 : 2048
        let longestPixelLength = max(displaySize.width, displaySize.height) * targetScale
        let scale = longestPixelLength > maxPixelLength
            ? maxPixelLength / max(displaySize.width, displaySize.height)
            : targetScale
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: displaySize, format: format)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: displaySize))

            let cgContext = context.cgContext
            let pageBounds = page.bounds(for: .mediaBox)
            let pageScale = min(
                displaySize.width / pageBounds.width,
                displaySize.height / pageBounds.height
            )
            let renderSize = CGSize(
                width: pageBounds.width * pageScale,
                height: pageBounds.height * pageScale
            )
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

        let finalImage: UIImage
        if sharpnessAmount > 0 {
            if let sharpenedImage = sharpenedImage(image, amount: sharpnessAmount) {
                finalImage = sharpenedImage
            } else {
                AppDiagnostics.record(.sharpeningFailed)
                finalImage = image
            }
        } else {
            finalImage = image
        }

        let duration = Int(
            ((ProcessInfo.processInfo.systemUptime - startedAt) * 1_000).rounded()
        )
        if duration >= 250 {
            AppDiagnostics.record(.pageRenderSlow, durationMilliseconds: duration)
        }
        return finalImage
    }

    private func sharpenedImage(_ image: UIImage, amount: Double) -> UIImage? {
        guard let inputImage = CIImage(image: image) else {
            return nil
        }

        let filter = CIFilter.sharpenLuminance()
        filter.inputImage = inputImage
        filter.sharpness = Float(min(max(amount, 0), 1))

        guard let outputImage = filter.outputImage,
              let cgImage = imageContext.createCGImage(outputImage, from: inputImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
