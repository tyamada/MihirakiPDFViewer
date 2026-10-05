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

    private func temporaryLogURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("AppLog.json")
    }
}
