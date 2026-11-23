//
// SecurityScopedResourceManager.swift
// MihirakiPDFViewer
//
// Copyright 2026 Takuma Yamada.
//

import Foundation

protocol SecurityScopedResourceAccessing {
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

private struct SystemSecurityScopedResourceAccessor: SecurityScopedResourceAccessing {
    func startAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

/// Owns at most one active security-scoped resource lease.
final class SecurityScopedResourceManager {
    private let accessor: any SecurityScopedResourceAccessing
    private var accessedURL: URL?

    init(accessor: any SecurityScopedResourceAccessing = SystemSecurityScopedResourceAccessor()) {
        self.accessor = accessor
    }

    func beginAccessing(_ url: URL) {
        stopAccessing()
        guard accessor.startAccessing(url) else { return }
        accessedURL = url
    }

    func stopAccessing() {
        guard let accessedURL else { return }
        accessor.stopAccessing(accessedURL)
        self.accessedURL = nil
    }

    deinit {
        stopAccessing()
    }
}
