//
//  AppLogStore.swift
//  MihirakiPDFViewer
//
//  Copyright 2026 Takuma Yamada.
//

import Foundation
import OSLog

enum AppLogLevel: String, Codable, Sendable {
    case info
    case warning
    case error
    case fault
}

enum AppLogCategory: String, Codable, Sendable {
    case lifecycle
    case navigation
    case document
    case search
    case rendering
    case settings
}

enum AppLogNumericLabel: String, Codable, Sendable {
    case page
    case pages
    case matches
}

enum AppLogEvent: String, Codable, Sendable {
    case appLaunched = "App launched"
    case appBecameActive = "App became active"
    case appBecameInactive = "App became inactive"
    case previousSessionEndedUnexpectedly = "Previous active session ended unexpectedly"
    case settingsOpened = "Settings opened"
    case documentPickerOpened = "Document picker opened"
    case documentPickerCancelled = "Document picker cancelled"
    case documentSelectionFailed = "Document selection failed"
    case incomingDocumentReceived = "Incoming document received"
    case incomingDocumentRejected = "Incoming document rejected"
    case incomingDocumentCopyFailed = "Incoming document copy failed"
    case documentLoadStarted = "Document load started"
    case documentLoaded = "Document loaded"
    case documentPasswordRequired = "Document password required"
    case documentPasswordRejected = "Document password rejected"
    case documentLoadFailed = "Document load failed"
    case documentClosed = "Document closed"
    case pageChanged = "Page changed"
    case searchStarted = "Search started"
    case searchCompleted = "Search completed"
    case searchSlow = "Search was slow"
    case invalidRenderSize = "Invalid page render size"
    case pageRenderSlow = "Page rendering was slow"
    case sharpeningFailed = "Image sharpening failed"
    case displaySettingsChanged = "Display settings changed"
    case settingsReset = "Settings reset"

    nonisolated var category: AppLogCategory {
        switch self {
        case .appLaunched, .appBecameActive, .appBecameInactive, .previousSessionEndedUnexpectedly:
            .lifecycle
        case .settingsOpened, .documentPickerOpened, .documentPickerCancelled, .pageChanged:
            .navigation
        case .documentSelectionFailed, .incomingDocumentReceived, .incomingDocumentRejected,
             .incomingDocumentCopyFailed, .documentLoadStarted, .documentLoaded,
             .documentPasswordRequired, .documentPasswordRejected, .documentLoadFailed,
             .documentClosed:
            .document
        case .searchStarted, .searchCompleted, .searchSlow:
            .search
        case .invalidRenderSize, .pageRenderSlow, .sharpeningFailed:
            .rendering
        case .displaySettingsChanged, .settingsReset:
            .settings
        }
    }

    nonisolated var level: AppLogLevel {
        switch self {
        case .previousSessionEndedUnexpectedly:
            .fault
        case .documentSelectionFailed, .incomingDocumentRejected, .incomingDocumentCopyFailed,
             .documentPasswordRejected, .documentLoadFailed, .invalidRenderSize,
             .sharpeningFailed:
            .error
        case .searchSlow, .pageRenderSlow:
            .warning
        default:
            .info
        }
    }
}

struct AppLogEntry: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: AppLogLevel
    let category: AppLogCategory
    let event: AppLogEvent
    let durationMilliseconds: Int?
    let numericValue: Int?
    let numericLabel: AppLogNumericLabel?
}

actor AppLogStore {
    static let shared = AppLogStore()

    static let retentionInterval: TimeInterval = 24 * 60 * 60
    static let maximumEntryCount = 2_000

    private let fileURL: URL
    private let retentionInterval: TimeInterval
    private let maximumEntryCount: Int
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MihirakiPDFViewer",
        category: "Diagnostics"
    )
    private var cachedEntries: [AppLogEntry]?
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    init(
        fileURL: URL = URL.applicationSupportDirectory
            .appendingPathComponent("Diagnostics", isDirectory: true)
            .appendingPathComponent("AppLog.json"),
        retentionInterval: TimeInterval = AppLogStore.retentionInterval,
        maximumEntryCount: Int = AppLogStore.maximumEntryCount
    ) {
        self.fileURL = fileURL
        self.retentionInterval = retentionInterval
        self.maximumEntryCount = maximumEntryCount
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
    }

    func record(
        _ event: AppLogEvent,
        at timestamp: Date = .now,
        durationMilliseconds: Int? = nil,
        numericValue: Int? = nil,
        numericLabel: AppLogNumericLabel? = nil
    ) {
        var entries = loadEntries()
        entries.append(
            AppLogEntry(
                id: UUID(),
                timestamp: timestamp,
                level: event.level,
                category: event.category,
                event: event,
                durationMilliseconds: durationMilliseconds,
                numericValue: numericValue,
                numericLabel: numericLabel
            )
        )
        entries = retainedEntries(from: entries, now: timestamp)
        cachedEntries = entries
        persist(entries)

        switch event.level {
        case .info:
            logger.info("\(event.rawValue, privacy: .public)")
        case .warning:
            logger.warning("\(event.rawValue, privacy: .public)")
        case .error:
            logger.error("\(event.rawValue, privacy: .public)")
        case .fault:
            logger.fault("\(event.rawValue, privacy: .public)")
        }
    }

    func recentEntries(now: Date = .now) -> [AppLogEntry] {
        let loaded = loadEntries()
        let retained = retainedEntries(from: loaded, now: now)
        if retained != loaded {
            cachedEntries = retained
            persist(retained)
        }
        return retained.reversed()
    }

    private func loadEntries() -> [AppLogEntry] {
        if let cachedEntries {
            return cachedEntries
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cachedEntries = []
            return []
        }

        do {
            let entries = try decoder.decode([AppLogEntry].self, from: Data(contentsOf: fileURL))
            cachedEntries = entries
            return entries
        } catch {
            logger.error("The diagnostics log could not be decoded.")
            cachedEntries = []
            try? FileManager.default.removeItem(at: fileURL)
            return []
        }
    }

    private func retainedEntries(from entries: [AppLogEntry], now: Date) -> [AppLogEntry] {
        let cutoff = now.addingTimeInterval(-retentionInterval)
        return Array(entries.lazy.filter { $0.timestamp >= cutoff }.suffix(maximumEntryCount))
    }

    private func persist(_ entries: [AppLogEntry]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try encoder.encode(entries).write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            logger.error("The diagnostics log could not be saved.")
        }
    }
}

enum AppDiagnostics {
    private static let activeSessionKey = "AppDiagnostics.activeSession"

    static func record(
        _ event: AppLogEvent,
        durationMilliseconds: Int? = nil,
        numericValue: Int? = nil,
        numericLabel: AppLogNumericLabel? = nil
    ) {
        Task(priority: .utility) {
            await AppLogStore.shared.record(
                event,
                durationMilliseconds: durationMilliseconds,
                numericValue: numericValue,
                numericLabel: numericLabel
            )
        }
    }

    @MainActor
    static func startSession(preferences: UserDefaults = .standard) {
        let previousSessionWasActive = preferences.bool(forKey: activeSessionKey)
        preferences.set(true, forKey: activeSessionKey)
        record(.appLaunched)
        if previousSessionWasActive {
            record(.previousSessionEndedUnexpectedly)
        }
    }

    @MainActor
    static func becameActive(preferences: UserDefaults = .standard) {
        preferences.set(true, forKey: activeSessionKey)
        record(.appBecameActive)
    }

    @MainActor
    static func becameInactive(preferences: UserDefaults = .standard) {
        preferences.set(false, forKey: activeSessionKey)
        record(.appBecameInactive)
    }
}
