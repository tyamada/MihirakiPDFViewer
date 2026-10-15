//
// LocalizationCompletenessTests.swift
// MihirakiPDFViewerTests
//
// Copyright 2026 Takuma Yamada.
//

import Foundation
import Testing

struct LocalizationCompletenessTests {
    private let supportedLocales = [
        "ja", "zh-Hans", "ko", "es", "fr", "de", "pt-BR", "zh-Hant", "vi", "fil"
    ]
    private let updatedHelpKeys = [
        "help_diagnostic_privacy_description",
        "help_diagnostic_report_problem_description",
        "help_diagnostics_description",
        "help_setting_app_info_description",
        "help_setting_app_logs_description",
        "help_setting_device_testing_description",
        "help_setting_diagnostics_description",
        "help_setting_high_quality_description",
        "help_setting_promotion_code_description",
        "help_setting_sharpness_description",
        "help_setting_single_page_in_portrait_description",
        "help_setting_supporter_icons_description",
        "help_settings_description"
    ]

    @Test
    func japaneseTranslationsAreComplete() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogNames = ["Localizable.xcstrings", "InfoPlist.xcstrings"]
        var incompleteEntries: [String] = []

        for catalogName in catalogNames {
            let catalogURL = repositoryURL.appendingPathComponent(catalogName)
            let data = try Data(contentsOf: catalogURL)
            let root = try #require(
                JSONSerialization.jsonObject(with: data) as? [String: Any]
            )
            let strings = try #require(root["strings"] as? [String: Any])

            for (key, rawEntry) in strings {
                guard let entry = rawEntry as? [String: Any],
                      entry["shouldTranslate"] as? Bool != false,
                      entry["extractionState"] as? String != "stale" else {
                    continue
                }

                guard let localizations = entry["localizations"] as? [String: Any],
                      let japanese = localizations["ja"] else {
                    incompleteEntries.append("\(catalogName): \(key) (missing)")
                    continue
                }

                let states = translationStates(in: japanese)
                let completedStates = Set(["translated", "machine_translated"])
                if states.isEmpty || states.contains(where: { !completedStates.contains($0) }) {
                    incompleteEntries.append("\(catalogName): \(key) (\(states.joined(separator: ", ")))")
                }
            }
        }

        #expect(
            incompleteEntries.isEmpty,
            "Incomplete Japanese translations:\n\(incompleteEntries.sorted().joined(separator: "\n"))"
        )
    }

    @Test
    func updatedHelpTranslationsAreCompleteForEverySupportedLocale() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = repositoryURL.appendingPathComponent("Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let strings = try #require(root["strings"] as? [String: Any])
        var incompleteEntries: [String] = []

        for key in updatedHelpKeys {
            let entry = try #require(strings[key] as? [String: Any])
            let localizations = try #require(entry["localizations"] as? [String: Any])

            for locale in supportedLocales {
                guard let localization = localizations[locale] else {
                    incompleteEntries.append("\(key) [\(locale)] (missing)")
                    continue
                }

                let states = translationStates(in: localization)
                let completedStates = Set(["translated", "machine_translated"])
                if states.isEmpty || states.contains(where: { !completedStates.contains($0) }) {
                    incompleteEntries.append("\(key) [\(locale)] (\(states.joined(separator: ", ")))")
                }
            }
        }

        #expect(
            incompleteEntries.isEmpty,
            "Incomplete help translations:\n\(incompleteEntries.sorted().joined(separator: "\n"))"
        )
    }

    private func translationStates(in value: Any) -> [String] {
        if let dictionary = value as? [String: Any] {
            let ownState = dictionary["state"] as? String
            return [ownState].compactMap { $0 }
                + dictionary.values.flatMap(translationStates)
        }
        if let array = value as? [Any] {
            return array.flatMap(translationStates)
        }
        return []
    }
}
