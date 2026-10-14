//
//  AppLogStoreTests.swift
//  MihirakiPDFViewerTests
//
//  Copyright 2026 Takuma Yamada.
//

import Foundation
import Testing
@testable import MihirakiPDFViewer

struct AppLogStoreTests {
    @Test
    func removesEntriesOlderThanTwentyFourHours() async throws {
        let fileURL = temporaryLogURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let store = AppLogStore(fileURL: fileURL)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        await store.record(
            .appLaunched,
            at: now.addingTimeInterval(-(AppLogStore.retentionInterval + 1))
        )
        await store.record(.appBecameActive, at: now)

        let entries = await store.recentEntries(now: now)

        #expect(entries.count == 1)
        #expect(entries.first?.event == .appBecameActive)
    }

    @Test
    func keepsEntriesExactlyTwentyFourHoursOld() async throws {
        let fileURL = temporaryLogURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let store = AppLogStore(fileURL: fileURL)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        await store.record(
            .appLaunched,
            at: now.addingTimeInterval(-AppLogStore.retentionInterval)
        )

        let entries = await store.recentEntries(now: now)

        #expect(entries.count == 1)
    }

    @Test
    func limitsLogGrowthWithinRetentionWindow() async throws {
        let fileURL = temporaryLogURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let store = AppLogStore(
            fileURL: fileURL,
            retentionInterval: AppLogStore.retentionInterval,
            maximumEntryCount: 3
        )
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        for offset in 0..<5 {
            await store.record(.pageChanged, at: now.addingTimeInterval(Double(offset)))
        }

        let entries = await store.recentEntries(now: now.addingTimeInterval(4))

        #expect(entries.count == 3)
    }

    @MainActor
    @Test
    func exportIncludesInjectedMetadataAndOptionalMeasurements() {
        let entry = AppLogEntry(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            level: .warning,
            category: .rendering,
            event: .pageRenderSlow,
            durationMilliseconds: 250,
            numericValue: 12,
            numericLabel: .pages
        )

        let text = AppLogExportFormatter.text(
            for: [entry],
            appVersion: "1.2.3",
            build: "4",
            systemName: "TestOS",
            systemVersion: "9.0"
        )

        #expect(text.contains("1.2.3"))
        #expect(text.contains("4"))
        #expect(text.contains("TestOS 9.0"))
        #expect(text.contains("[WARNING] [rendering] Page rendering was slow"))
        #expect(text.contains("duration_ms=250"))
        #expect(text.contains("pages=12"))
    }

    @MainActor
    @Test
    func exportListsNewestEntryFirst() throws {
        let olderEntry = makeEntry(event: .appLaunched, timestamp: 100)
        let newerEntry = makeEntry(event: .appBecameActive, timestamp: 200)

        let text = AppLogExportFormatter.text(
            for: [olderEntry, newerEntry],
            appVersion: "1",
            build: "1",
            systemName: "TestOS",
            systemVersion: "1"
        )
        let newerRange = try #require(text.range(of: newerEntry.event.rawValue))
        let olderRange = try #require(text.range(of: olderEntry.event.rawValue))

        #expect(newerRange.lowerBound < olderRange.lowerBound)
    }

    private func temporaryLogURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("AppLog.json")
    }

    private func makeEntry(event: AppLogEvent, timestamp: TimeInterval) -> AppLogEntry {
        AppLogEntry(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: timestamp),
            level: event.level,
            category: event.category,
            event: event,
            durationMilliseconds: nil,
            numericValue: nil,
            numericLabel: nil
        )
    }
}
