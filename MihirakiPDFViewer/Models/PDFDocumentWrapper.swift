//
// PDFDocuentWrapper.swift
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

import Foundation
import PDFKit
import SwiftUI

/// PDFのドキュメントと、それに関連するメタデータを保持するモデル
public struct PDFDocumentWrapper: Identifiable, Equatable {
    public let id = UUID()

    public static func == (lhs: PDFDocumentWrapper, rhs: PDFDocumentWrapper) -> Bool {
        lhs.id == rhs.id
    }
    public let url: URL
    public let pdfDocument: PDFDocument
    public let totalPageCount: Int
    public let layoutDirection: LayoutDirection
    public let isSpreadViewEnabled: Bool
    public let isCoverPageEnabled: Bool
    public let isSliderEnabled: Bool
    public let pageLayout: PDFPageLayout
    public let coverPageSetting: CoverPageSetting
    public let title: String?
    public let author: String?
    public let subtitle: String?
    public let keywords: String?
    public let pdfVersion: String?

    public init(url: URL) throws {
        guard let document = PDFDocument(url: url) else {
            throw NSError(domain: "PDFDocumentWrapper", code: 1, userInfo: [NSLocalizedDescriptionKey: "PDFの読み込みに失敗しました。"])
        }
        self.url = url
        self.pdfDocument = document
        self.totalPageCount = document.pageCount

        let attributes = document.documentAttributes
        self.title = Self.metadataString(attributes?[PDFDocumentAttribute.titleAttribute])
        self.author = Self.metadataString(attributes?[PDFDocumentAttribute.authorAttribute])
        self.subtitle = Self.metadataString(attributes?[PDFDocumentAttribute.subjectAttribute])
        self.keywords = Self.metadataString(attributes?[PDFDocumentAttribute.keywordsAttribute])
        self.pdfVersion = Self.pdfVersion(url: url)
        
        let detected = PDFDocumentWrapper.detectLayoutSettings(url: url)
        self.layoutDirection = detected.direction
        self.isSpreadViewEnabled = detected.isSpread
        self.isSliderEnabled = detected.isSlider
        self.pageLayout = detected.pageLayout
        self.isCoverPageEnabled = detected.isCover
        self.coverPageSetting = detected.coverPageSetting
    }

    private static func metadataString(_ value: Any?) -> String? {
        if let string = value as? String {
            return nonEmptyString(string)
        }

        if let strings = value as? [String] {
            return nonEmptyString(strings.joined(separator: ", "))
        }

        if let array = value as? [Any] {
            return nonEmptyString(array.map { String(describing: $0) }.joined(separator: ", "))
        }

        if let value {
            return nonEmptyString(String(describing: value))
        }

        return nil
    }

    private static func nonEmptyString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func pdfVersion(url: URL) -> String? {
        guard let pdfDocument = CGPDFDocument(url as CFURL) else {
            return nil
        }

        var majorVersion: Int32 = 0
        var minorVersion: Int32 = 0
        pdfDocument.getVersion(majorVersion: &majorVersion, minorVersion: &minorVersion)

        guard majorVersion > 0 else {
            return nil
        }

        return "\(majorVersion).\(minorVersion)"
    }

    private static func detectLayoutSettings(url: URL) -> DetectedSettings {
        guard let pdfDocument = CGPDFDocument(url as CFURL) else {
            print("Failed to inspect PDF metadata. Falling back to default layout settings: \(url.lastPathComponent)")
            return DetectedSettings(direction: .leftToRight, isSpread: false, isCover: false, isSlider: true, pageLayout: .singlePage, coverPageSetting: .typeA)
        }
        
        var direction: LayoutDirection = .leftToRight
        var isSpread = false
        var isCover = false
        var detectedLayout: PDFPageLayout = .singlePage
        let coverPageSetting: CoverPageSetting = .typeA
        
        if let catalog = pdfDocument.catalog {
            // 1. ViewerPreferences/Direction の取得
            var viewerPrefs: CGPDFDictionaryRef?
            if CGPDFDictionaryGetDictionary(catalog, "ViewerPreferences", &viewerPrefs),
               let vp = viewerPrefs {
                var dirName: UnsafePointer<CChar>?
                if CGPDFDictionaryGetName(vp, "Direction", &dirName),
                   let name = dirName {
                    if String(cString: name) == "R2L" {
                        direction = .rightToLeft
                    }
                }
            }
            
            // 2. PageLayout の取得
            var pageLayoutString: String? = nil
            var layoutName: UnsafePointer<CChar>?
            if CGPDFDictionaryGetName(catalog, "PageLayout", &layoutName),
               let name = layoutName {
                pageLayoutString = String(cString: name)
            }
            
            // 3. 判定ロジックの適用
            switch pageLayoutString {
            case "TwoPageLeft", "TwoPageRight", "TwoColumnLeft", "TwoColumnRight":
                isSpread = true
                
                if coverPageSetting == .typeA {
                    isCover = (pageLayoutString == "TwoPageRight" || pageLayoutString == "TwoColumnRight")
                } else if coverPageSetting == .typeB {
                    if direction == .leftToRight {
                        isCover = (pageLayoutString == "TwoPageRight" || pageLayoutString == "TwoColumnRight")
                    } else {
                        isCover = (pageLayoutString == "TwoPageLeft" || pageLayoutString == "TwoColumnLeft")
                    }
                } else {
                    isCover = (pageLayoutString == "TwoPageRight" || pageLayoutString == "TwoColumnRight")
                }

                if pageLayoutString == "TwoPageLeft" { detectedLayout = .twoPageLeft }
                else if pageLayoutString == "TwoPageRight" { detectedLayout = .twoPageRight }
                else if pageLayoutString == "TwoColumnLeft" { detectedLayout = .twoColumnLeft }
                else if pageLayoutString == "TwoColumnRight" { detectedLayout = .twoColumnRight }
                else { detectedLayout = .singlePage }
            case "SinglePage", "OneColumn":
                isSpread = false
                isCover = false
                detectedLayout = pageLayoutString == "OneColumn" ? .oneColumn : .singlePage
            default:
                isSpread = false
                isCover = false
                detectedLayout = .singlePage
            }
        }
        
        return DetectedSettings(direction: direction, isSpread: isSpread, isCover: isCover, isSlider: true, pageLayout: detectedLayout, coverPageSetting:  coverPageSetting)
    }
}

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
    public var isSliderEnabled: Bool
    public var isSearchbarEnabled: Bool
    public var layoutDirection: LayoutDirection
    public var coverPageSetting: CoverPageSetting

    public init(
        isSpreadViewEnabled: Bool = false,
        isCoverPageEnabled: Bool = false,
        isSliderEnabled: Bool = true,
        isSearchbarEnabled: Bool = true,
        layoutDirection: LayoutDirection = .leftToRight,
        coverPageSetting: CoverPageSetting = .typeA
    ) {
        self.isSpreadViewEnabled = isSpreadViewEnabled
        self.isCoverPageEnabled = isCoverPageEnabled
        self.isSliderEnabled = isSliderEnabled
        self.isSearchbarEnabled = isSearchbarEnabled
        self.layoutDirection = layoutDirection
        self.coverPageSetting = coverPageSetting
    }
}

public struct DetectedSettings {
    public let direction: LayoutDirection
    public let isSpread: Bool
    public let isCover: Bool
    public let isSlider: Bool
    public let pageLayout: PDFPageLayout
    public let coverPageSetting: CoverPageSetting

    public init(
        direction: LayoutDirection,
        isSpread: Bool,
        isCover: Bool,
        isSlider: Bool,
        pageLayout: PDFPageLayout,
        coverPageSetting: CoverPageSetting
    ) {
        self.direction = direction
        self.isSpread = isSpread
        self.isCover = isCover
        self.isSlider = isSlider
        self.pageLayout = pageLayout
        self.coverPageSetting = coverPageSetting
    }
}
