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
    @Environment(\.pdfPageFocusContext) private var focusContext
    @Environment(\.pdfChromeVisibility) private var chromeVisibility

    let page: PDFPage
    let pageNumber: Int?
    let size: CGSize
    let searchMatches: [PDFViewerViewModel.PDFSearchMatch]
    let alignment: PageAlignment
    let isHighQualityRenderingEnabled: Bool
    let isSharpnessEnabled: Bool
    let sharpnessAmount: Double?

    public init(
        page: PDFPage,
        pageNumber: Int? = nil,
        size: CGSize,
        searchMatches: [PDFViewerViewModel.PDFSearchMatch] = [],
        alignment: PageAlignment = .center,
        isHighQualityRenderingEnabled: Bool = false,
        isSharpnessEnabled: Bool = false,
        sharpnessAmount: Double? = nil
    ) {
        self.page = page
        self.pageNumber = pageNumber
        self.size = size
        self.searchMatches = searchMatches
        self.alignment = alignment
        self.isHighQualityRenderingEnabled = isHighQualityRenderingEnabled
        self.isSharpnessEnabled = isSharpnessEnabled
        self.sharpnessAmount = sharpnessAmount
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
                Group {
                    if let focusContext, let pageNumber {
                        PDFPageAccessibilityImage(
                            image: cachedPageImage(displaySize: size),
                            pageNumber: pageNumber, label: pageAccessibilityLabel,
                            displaySize: size, focus: focusContext, chromeVisibility: chromeVisibility
                        )
                    } else {
                        Image(uiImage: cachedPageImage(displaySize: size))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .accessibilityLabel(pageAccessibilityLabel)
                    }
                }
                .frame(width: size.width, height: size.height)
                .position(x: offsetX + renderedWidth / 2, y: geometry.size.height / 2)

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
            isSharpnessEnabled: isSharpnessEnabled,
            sharpnessAmount: sharpnessAmount
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


// Data, rather than a closure, is propagated through the environment.
struct PDFPageFocusContext {
    let model: PDFViewerViewModel
    let request: PDFViewerViewModel.AccessibilityFocusRequest
    let isViewportReady: Bool
}

extension EnvironmentValues {
    @Entry var pdfPageFocusContext: PDFPageFocusContext? = nil
    @Entry var pdfChromeVisibility: Binding<Bool>? = nil
}

/// Uses the displayed image itself as the notification argument. No proxy element,
/// extra announcement, or independent per-page SwiftUI focus state competes with it.
struct PDFPageAccessibilityImage: UIViewRepresentable {
    let image: UIImage
    let pageNumber: Int
    let label: String
    let displaySize: CGSize
    let focus: PDFPageFocusContext
    let chromeVisibility: Binding<Bool>?

    func makeUIView(context: Context) -> PDFPageAccessibilityImageView {
        PDFPageAccessibilityImageView(frame: .zero)
    }

    func updateUIView(_ view: PDFPageAccessibilityImageView, context: Context) {
        view.image = image
        view.accessibilityLabel = label
        view.configure(pageNumber: pageNumber, displaySize: displaySize, focus: focus)
        view.chromeVisibility = chromeVisibility
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PDFPageAccessibilityImageView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? displaySize.width, height: proposal.height ?? displaySize.height)
    }

    static func dismantleUIView(_ view: PDFPageAccessibilityImageView, coordinator: ()) {
        view.invalidateFocusRequest()
    }
}

final class PDFPageAccessibilityImageView: UIImageView {
    private(set) var pageNumber = 0
    var chromeVisibility: Binding<Bool>?
    private var focus: PDFPageFocusContext?
    private var delivery = PDFFocusDeliveryState<PDFViewerViewModel.AccessibilityFocusRequest>()
    private var previousRequest: PDFViewerViewModel.AccessibilityFocusRequest?
    #if DEBUG
    private static var nextTraceID = 0
    private let traceID: Int
    #endif

    override init(frame: CGRect) {
        #if DEBUG
        Self.nextTraceID += 1
        traceID = Self.nextTraceID
        #endif
        super.init(frame: frame)
        contentMode = .scaleAspectFit
        isAccessibilityElement = true
        accessibilityTraits = .image
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { nil }

    func configure(pageNumber: Int, displaySize: CGSize, focus: PDFPageFocusContext) {
        delivery.update(request: focus.request, expectedSize: displaySize,
                        isTarget: focus.request.pageNumber == pageNumber,
                        viewportReady: focus.isViewportReady)
        self.pageNumber = pageNumber
        self.focus = focus
        accessibilityIdentifier = "pdfPageImage-\(pageNumber)"
        setNeedsLayout()
    }

    override func accessibilityActivate() -> Bool {
        guard let chromeVisibility else { return false }
        withAnimation {
            chromeVisibility.wrappedValue.toggle()
        }
        return true
    }

    func invalidateFocusRequest() {
        traceFocusLifecycle("focus.imageInvalidated")
        chromeVisibility = nil
        delivery.invalidate()
        focus = nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        traceFocusLifecycle(window == nil ? "focus.imageDetached" : "focus.imageAttached")
        if window != nil { setNeedsLayout() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let focus,
              let ticket = delivery.enqueue(current: focus.model.accessibilityFocusRequest,
                                            mounted: isMounted, bounds: bounds.size,
                                            scale: traitCollection.displayScale) else { return }
        let focusGeneration = focus.model.accessibilityFocusEventGeneration
        let focusedElement = currentVoiceOverElement
        // Schedule after this UIKit layout pass, not after an arbitrary delay.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.delivery.generation == ticket else { return }
            // A system rotation may still be animating after geometry has changed.
            // In that case wait for its actual completion, not a guessed duration.
            var responder: UIResponder? = self
            while let current = responder {
                if let controller = current as? UIViewController,
                   let transition = controller.transitionCoordinator, transition.isAnimated {
                    let registered = transition.animate(alongsideTransition: nil) { [weak self] _ in
                        self?.issueFocusRequest(generation: ticket, focusGeneration: focusGeneration, focusedElement: focusedElement)
                    }
                    if registered { return }
                }
                responder = current.next
            }
            self.issueFocusRequest(generation: ticket, focusGeneration: focusGeneration, focusedElement: focusedElement)
        }
    }

    private var isMounted: Bool { window != nil && !isHidden && alpha > 0 }

    private var currentVoiceOverElement: ObjectIdentifier? {
        guard let element = UIAccessibility.focusedElement(using: .notificationVoiceOver) else { return nil }
        return ObjectIdentifier(element as AnyObject)
    }

    private func issueFocusRequest(generation ticket: Int, focusGeneration: Int,
                                   focusedElement: ObjectIdentifier?) {
        guard let focus,
              delivery.consume(ticket, current: focus.model.accessibilityFocusRequest,
                               mounted: isMounted, bounds: bounds.size,
                               scale: traitCollection.displayScale) else { return }
        // Rotation may already have restored this exact UIKit image. Posting
        // layoutChanged again needlessly starts a second focus update.
        let decision = PDFFocusCompletionDecision.decide(
            target: ObjectIdentifier(self), captured: focusedElement,
            current: currentVoiceOverElement, capturedGeneration: focusGeneration,
            currentGeneration: focus.model.accessibilityFocusEventGeneration)
        switch decision {
        case .alreadyFocused:
            traceFocusLifecycle("focus.alreadyFocused")
            return
        case .superseded:
            traceFocusLifecycle("focus.requestSuperseded")
            return
        case .send:
            break
        }
        let reason = focus.request.reason(after: previousRequest)
        previousRequest = focus.request
        focus.model.recordAccessibilityFocusRequest(focus.request, reason: reason)
        let posted = UIAccessibility.isVoiceOverRunning
        traceFocusLifecycle("focus.elementRequest", posted: posted)
        if posted {
            UIAccessibility.post(notification: .layoutChanged, argument: self)
        }
    }

    private func traceFocusLifecycle(_ event: String, posted: Bool = false) {
        #if DEBUG
        let current = currentVoiceOverElement
        let detail = "imageID=\(traceID) mounted=\(isMounted) focusedIsSelf=\(current == ObjectIdentifier(self)) focusIsEmpty=\(current == nil)"
        #else
        let detail = ""
        #endif
        // Acquisition bookkeeping remains active in release builds; diagnostic
        // logging itself is DEBUG-only in the model.
        focus?.model.recordAccessibilityImageFocus(event: event, page: pageNumber,
                                                   posted: posted, detail: detail)
    }

    override func accessibilityElementDidLoseFocus() {
        super.accessibilityElementDidLoseFocus()
        // Loss can precede the next acquisition; log it without inferring a
        // destination, cancelling a pending request, or forcing focus back.
        traceFocusLifecycle("focus.elementLost")
    }

    override func accessibilityElementDidBecomeFocused() {
        super.accessibilityElementDidBecomeFocused()
        // This callback identifies an element focus event, not speech completion.
        guard let focus else { return }
        guard isMounted, focus.request == focus.model.accessibilityFocusRequest else {
            focus.model.recordAccessibilityImageFocus(event: "focus.staleElementFocused", page: pageNumber)
            return
        }
        traceFocusLifecycle("focus.elementFocused")
    }
}
