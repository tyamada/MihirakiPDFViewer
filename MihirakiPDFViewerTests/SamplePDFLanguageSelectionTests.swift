import Foundation
import Testing
@testable import MihirakiPDFViewer

struct SamplePDFLanguageSelectionTests {
    private let available = ["en", "ja", "ko", "zh-Hans", "zh-Hant", "zh-Hant-HK"]

    @Test(arguments: ["zh-Hant", "zh-Hant-TW", "zh-TW", "zh-MO", "zh_Hant_MO"])
    func traditionalDoesNotChooseSimplified(_ preferred: String) {
        #expect(SamplePDFLanguageFilter.initialLanguageCode(preferredLanguages: [preferred], availableLanguageCodes: available) == "zh-Hant")
    }
    @Test(arguments: ["zh-Hant-HK", "zh-HK", "zh_hant_hk"])
    func hongKongUsesRegionalEdition(_ preferred: String) {
        #expect(SamplePDFLanguageFilter.initialLanguageCode(preferredLanguages: [preferred], availableLanguageCodes: available) == "zh-Hant-HK")
    }
    @Test(arguments: ["zh-Hans", "zh-CN", "zh-SG", "zh", "zh-Hans-HK"])
    func simplifiedUsesSimplified(_ preferred: String) {
        #expect(SamplePDFLanguageFilter.initialLanguageCode(preferredLanguages: [preferred], availableLanguageCodes: available) == "zh-Hans")
    }
    @Test func selectionIsIndependentOfCatalogOrder() {
        #expect(SamplePDFLanguageFilter.initialLanguageCode(preferredLanguages: ["zh-Hant"], availableLanguageCodes: Array(available.reversed())) == "zh-Hant")
    }
    @Test func unavailableScriptFallsBackToEnglish() {
        #expect(SamplePDFLanguageFilter.initialLanguageCode(preferredLanguages: ["zh-Hant"], availableLanguageCodes: ["zh-Hans", "en"]) == "en")
        #expect(SamplePDFLanguageFilter.initialLanguageCode(preferredLanguages: ["zh-Hans"], availableLanguageCodes: ["zh-Hant", "en"]) == "en")
    }
    @Test func hongKongFallsBackToGenericTraditional() {
        #expect(SamplePDFLanguageFilter.initialLanguageCode(preferredLanguages: ["zh-HK"], availableLanguageCodes: ["zh-Hans", "zh-Hant", "en"]) == "zh-Hant")
    }
    @Test func existingFirstLanguageAndEnglishFallbackRemain() {
        #expect(SamplePDFLanguageFilter.initialLanguageCode(preferredLanguages: ["ko-KR"], availableLanguageCodes: available) == "ko")
        #expect(SamplePDFLanguageFilter.initialLanguageCode(preferredLanguages: ["ja-JP"], availableLanguageCodes: available) == "ja")
        #expect(SamplePDFLanguageFilter.initialLanguageCode(preferredLanguages: ["fr-FR", "ja-JP"], availableLanguageCodes: available) == "en")
        #expect(SamplePDFLanguageFilter.initialLanguageCode(preferredLanguages: [], availableLanguageCodes: ["ja"]) == nil)
    }
    @Test func chineseNamesAreDistinct() {
        let names = ["zh-Hans", "zh-Hant", "zh-Hant-HK"].map { SamplePDFLanguageFilter.displayName(for: $0) }
        #expect(Set(names).count == 3)
    }
}
