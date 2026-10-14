//
// PDFViewerSettings.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//
// This software is released under the MIT License.
// For the full license text, please see the LICENSE file in the root directory.
//

import SwiftUI

/// PDFのページレイアウトを表す列挙型
public enum PDFPageLayout: String {
    case singlePage = "SinglePage"
    case oneColumn = "OneColumn"
    case twoPageLeft = "TwoPageLeft"
    case twoPageRight = "TwoPageRight"
    case twoColumnLeft = "TwoColumnLeft"
    case twoColumnRight = "TwoColumnRight"

    var displayName: String {
        switch self {
        case .singlePage: return "SinglePage"
        case .oneColumn: return "OneColumn"
        case .twoPageLeft: return "TwoPageLeft"
        case .twoPageRight: return "TwoPageRight"
        case .twoColumnLeft: return "TwoColumnLeft"
        case .twoColumnRight: return "TwoColumnRight"
        }
    }
}

/// PDFから抽出されたメタデータ
public struct PDFDocumentMetadata {
    public let pageLayout: PDFPageLayout
    public let layoutDirection: LayoutDirection
}

public enum CoverPageSetting: String {
    case typeA
    case typeB
}

public struct PDFViewerSettings {
    public var isSpreadViewEnabled: Bool
    public var isCoverPageEnabled: Bool
    public var layoutDirection: LayoutDirection
    public var coverPageSetting: CoverPageSetting
    public var isHighQualityRenderingEnabled: Bool
    public var isSharpnessEnabled: Bool
    public var isSinglePageInPortraitEnabled: Bool

    public init(
        isSpreadViewEnabled: Bool = false,
        isCoverPageEnabled: Bool = false,
        layoutDirection: LayoutDirection = .leftToRight,
        coverPageSetting: CoverPageSetting = .typeA,
        isHighQualityRenderingEnabled: Bool = false,
        isSharpnessEnabled: Bool = false,
        isSinglePageInPortraitEnabled: Bool = false
    ) {
        self.isSpreadViewEnabled = isSpreadViewEnabled
        self.isCoverPageEnabled = isCoverPageEnabled
        self.layoutDirection = layoutDirection
        self.coverPageSetting = coverPageSetting
        self.isHighQualityRenderingEnabled = isHighQualityRenderingEnabled
        self.isSharpnessEnabled = isSharpnessEnabled
        self.isSinglePageInPortraitEnabled = isSinglePageInPortraitEnabled
    }
}

public struct DetectedSettings {
    public let direction: LayoutDirection
    public let isSpread: Bool
    public let isCover: Bool
    public let pageLayout: PDFPageLayout
    public let coverPageSetting: CoverPageSetting

    public init(
        direction: LayoutDirection,
        isSpread: Bool,
        isCover: Bool,
        pageLayout: PDFPageLayout,
        coverPageSetting: CoverPageSetting
    ) {
        self.direction = direction
        self.isSpread = isSpread
        self.isCover = isCover
        self.pageLayout = pageLayout
        self.coverPageSetting = coverPageSetting
    }
}
