import Foundation
import Testing
import UIKit
@testable import MihirakiPDFViewer

struct ReleaseIdentityTests {
    private let locales = ["de", "en", "es", "fil", "fr", "id", "ja", "ko", "ne", "pt-BR", "vi", "zh-Hans", "zh-Hant"]
    // Adopted Android naming policy; expectations are independent of the catalogs.
    private let displayNames = [
        "de": "Mihiraki: Doppelseitiger PDF-Reader",
        "en": "Mihiraki: Two-Page PDF Reader",
        "es": "Mihiraki: Lector PDF de Doble Página",
        "fr": "Mihiraki : Lecteur PDF Double Page",
        "ja": "見開きPDFビューア",
        "ko": "미히라키 PDF 뷰어",
        "zh-Hant": "MihirakiPDFViewer: 雙頁 PDF 閱讀器"
    ]

    @Test
    func builtIdentityResourcesAgreeAcrossLanguages() throws {
        #expect(Bundle.main.infoDictionary?["CFBundleName"] as? String == "MihirakiPDF")
        #expect(Bundle.main.bundleIdentifier == "com.takumayamada22.PDFViewer")
        #expect(Bundle.main.infoDictionary?["CFBundleExecutable"] as? String == "MihirakiPDFViewer")
        #expect(Bundle.main.developmentLocalization == "en")
        for locale in locales {
            let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"))
            let bundle = try #require(Bundle(path: path))
            let displayName = displayNames[locale] ?? "MihirakiPDFViewer"
            #expect(bundle.localizedString(forKey: "CFBundleDisplayName", value: nil, table: "InfoPlist") == displayName)
            #expect(bundle.localizedString(forKey: "CFBundleName", value: nil, table: "InfoPlist") == "MihirakiPDF")
            #expect(bundle.localizedString(forKey: "app_name", value: nil, table: nil) == displayName)
            let badge = bundle.localizedString(forKey: "koyomi_v2_badge_name", value: nil, table: nil)
            #expect(badge != "koyomi_v2_badge_name")
            #expect(!badge.contains("2.0"))
            if locale == "ja" { #expect(badge == "リリース記念こよみバッジ") }
            if locale == "en" { #expect(badge == "Release Commemorative Koyomi Badge") }
        }
    }

    @Test
    func languagePreferencesSelectFirstSupportedLanguage() {
        #expect(Bundle.preferredLocalizations(from: locales, forPreferences: ["it", "ja", "en"]).first == "ja")
        #expect(Bundle.preferredLocalizations(from: locales, forPreferences: ["de", "ja", "en"]).first == "de")
        #expect(Bundle.preferredLocalizations(from: locales, forPreferences: ["en-US"]).first == "en")
        #expect(Bundle.preferredLocalizations(from: locales, forPreferences: ["ja-JP"]).first == "ja")
        #expect(Bundle.preferredLocalizations(from: locales, forPreferences: ["ko-KR"]).first == "ko")
        #expect(Bundle.preferredLocalizations(from: locales, forPreferences: ["ar-SA", "ja-JP"]).first == "ja")
    }

    @MainActor @Test
    func badgeIdentityAndResourcesRemainAvailable() {
        #expect(SupporterTier.koyomi.rawValue == "supporter_badge_koyomi_v2")
        #expect(TipManager.productIDs.contains(SupporterTier.koyomi.rawValue))
        #expect(TipManager.appIconName(for: SupporterTier.koyomi.rawValue) == nil)
        #expect(UIImage(named: SupporterTier.koyomi.imageName) != nil)
        #expect(!FileManager.default.fileExists(atPath: Bundle.main.bundleURL.appendingPathComponent("Products.storekit").path))
    }
}
