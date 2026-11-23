//
// SecurityScopedResourceManagerTests.swift
// MihirakiPDFViewerTests
//
// Copyright 2026 Takuma Yamada.
//

import Foundation
import Testing
@testable import MihirakiPDFViewer

struct SecurityScopedResourceManagerTests {
    @Test
    func replacingResourceStopsPreviousAccess() {
        let accessor = ResourceAccessorSpy()
        let manager = SecurityScopedResourceManager(accessor: accessor)
        let firstURL = URL(fileURLWithPath: "/first.pdf")
        let secondURL = URL(fileURLWithPath: "/second.pdf")

        manager.beginAccessing(firstURL)
        manager.beginAccessing(secondURL)

        #expect(accessor.startedURLs == [firstURL, secondURL])
        #expect(accessor.stoppedURLs == [firstURL])
    }

    @Test
    func stopIsIdempotent() {
        let accessor = ResourceAccessorSpy()
        let manager = SecurityScopedResourceManager(accessor: accessor)
        let url = URL(fileURLWithPath: "/document.pdf")

        manager.beginAccessing(url)
        manager.stopAccessing()
        manager.stopAccessing()

        #expect(accessor.stoppedURLs == [url])
    }

    @Test
    func failedAccessDoesNotRequireStopping() {
        let accessor = ResourceAccessorSpy(allowsAccess: false)
        let manager = SecurityScopedResourceManager(accessor: accessor)
        let url = URL(fileURLWithPath: "/local.pdf")

        manager.beginAccessing(url)
        manager.stopAccessing()

        #expect(accessor.startedURLs == [url])
        #expect(accessor.stoppedURLs.isEmpty)
    }

    private final class ResourceAccessorSpy: SecurityScopedResourceAccessing {
        let allowsAccess: Bool
        var startedURLs: [URL] = []
        var stoppedURLs: [URL] = []

        init(allowsAccess: Bool = true) {
            self.allowsAccess = allowsAccess
        }

        func startAccessing(_ url: URL) -> Bool {
            startedURLs.append(url)
            return allowsAccess
        }

        func stopAccessing(_ url: URL) {
            stoppedURLs.append(url)
        }
    }
}
