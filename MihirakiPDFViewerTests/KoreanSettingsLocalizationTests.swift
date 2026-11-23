import Foundation
import Testing

struct KoreanSettingsLocalizationTests {
    // Settings and its destinations: missing ko entries previously fell back to English.
    private let requiredKeys = [
        "%@: %lld",
        "A GitHub account is required. The information you submit may be publicly visible.",
        "A short summary of the problem",
        "All tests passed.",
        "App",
        "App Information",
        "App Logs",
        "App information",
        "App version",
        "App version: %@",
        "App version: %@ (%@)",
        "Available memory",
        "Available memory: %@",
        "Available storage",
        "Available storage could not be read.",
        "Before reporting",
        "Bronze Supporter",
        "Build",
        "Cache storage",
        "Comfortable Reading",
        "Copyright",
        "Device Test Results",
        "Device Tests",
        "Diagnostic Tools",
        "Diagnostic information",
        "Diagnostic results and logs remain on this device unless you explicitly share them.",
        "Diagnostics",
        "Duration: %lld ms",
        "Failed",
        "Getting Started",
        "Gold Supporter",
        "Help",
        "How often the problem occurs",
        "Include in your report",
        "Last 24 hours",
        "License",
        "Loading logs…",
        "Logs older than 24 hours are deleted automatically.",
        "Matches",
        "MihirakiPDFViewer App Logs",
        "Name",
        "No Badges Yet",
        "No logs",
        "Not available",
        "OS version",
        "OS version: %@",
        "OS version: %@ %@",
        "Open Source License",
        "PDF rendering",
        "Page",
        "Pages",
        "Passed",
        "Privacy",
        "Protect your privacy",
        "Refresh",
        "Result: %@",
        "Results",
        "Retention: 24 hours",
        "Run tests again",
        "Run tests on this device",
        "Running tests…",
        "Settings Guide",
        "Share",
        "Silver Supporter",
        "Some tests failed.",
        "Steps that reproduce the problem",
        "Support the Developer",
        "Support the developer to unlock a supporter badge.",
        "Supporter Badges",
        "Test date",
        "Test date: %@",
        "Test information",
        "The app version could not be read.",
        "The generated PDF could not be read.",
        "There are no logs from the last 24 hours.",
        "Total memory",
        "Total memory: %@",
        "Version",
        "View app logs",
        "What you expected and what actually happened",
        "Your app version, OS version, device, and relevant viewing settings",
        "app_logs",
        "enter_promotion_code",
        "go_to_support_screen",
        "single_page_in_portrait",
    ]

    @Test
    func compiledSettingsTranslationsDoNotFallBackToEnglish() throws {
        let path = try #require(Bundle.main.path(forResource: "ko", ofType: "lproj"))
        let korean = try #require(Bundle(path: path))
        for key in requiredKeys {
            let resolved = korean.localizedString(forKey: key, value: "__MISSING__", table: nil)
            #expect(resolved != "__MISSING__", "Missing Korean resource: \(key)")
            if key != "%@: %lld" {
                #expect(resolved.range(of: "[가-힣]", options: .regularExpression) != nil,
                        "Untranslated settings label: \(key)")
            }
        }
        #expect(korean.localizedString(forKey: "App Information", value: nil, table: nil) == "앱 정보")
        #expect(String(localized: "enter_promotion_code", defaultValue: "Enter Promotion Code", bundle: korean) == "프로모션 코드 입력")
        #expect(korean.localizedString(forKey: "app_name", value: nil, table: nil) == "미히라키 PDF 뷰어")
    }
}
