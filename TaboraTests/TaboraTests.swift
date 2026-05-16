//
//  TaboraTests.swift
//  TaboraTests
//
//  Created by Masatomo Kusaka on 2026/04/12.
//

import AppKit
import CoreGraphics
@testable import Tabora
import Testing

struct TaboraTests {
    @Test func permissionStateExposesMenuLabel() {
        #expect(PermissionAccessState.granted.menuLabel == "Granted")
        #expect(PermissionAccessState.missing.menuLabel == "Missing")
        #expect(PermissionAccessState.unknown.menuLabel == "Unknown")
    }

    @Test func permissionStatusBuildsOverlayMessageAndLogSummary() {
        let status = PermissionStatus(screenCapture: .missing, accessibility: .granted)
        #expect(status.overlayMessage?.contains("Screen Recording permission is missing") == true)
        #expect(status.logSummary == "screenCapture=missing accessibility=granted")
    }

    @MainActor
    @Test func permissionServiceDoesNotPromptWhenAccessibilityIsAlreadyGranted() {
        let checker = RecordingSystemPermissionChecker(
            screenCaptureGranted: true,
            accessibilityGranted: true
        )
        let service = PermissionService(systemPermissionChecker: checker)

        service.primeForUserVisibleFlow()

        #expect(checker.accessibilityPromptRequests == [false])
    }

    @MainActor
    @Test func permissionServicePromptsOnceWhenAccessibilityIsMissing() {
        let checker = RecordingSystemPermissionChecker(
            screenCaptureGranted: true,
            accessibilityGranted: false
        )
        let service = PermissionService(systemPermissionChecker: checker)

        service.primeForUserVisibleFlow()
        service.primeForUserVisibleFlow()

        #expect(checker.accessibilityPromptRequests == [false, true])
    }

    @Test func loginItemStatusExposesMenuMetadata() {
        #expect(LoginItemStatus.enabled.menuDescription == "Enabled")
        #expect(LoginItemStatus.enabled.menuState == .on)
        #expect(LoginItemStatus.enabled.canToggle)

        #expect(LoginItemStatus.disabled.menuDescription == "Disabled")
        #expect(LoginItemStatus.disabled.menuState == .off)
        #expect(LoginItemStatus.disabled.canToggle)

        #expect(LoginItemStatus.requiresApproval.menuDescription == "Needs Approval")
        #expect(LoginItemStatus.requiresApproval.menuState == .mixed)
        #expect(LoginItemStatus.requiresApproval.canToggle)

        #expect(LoginItemStatus.unavailable.menuDescription == "Unavailable")
        #expect(LoginItemStatus.unavailable.menuState == .off)
        #expect(LoginItemStatus.unavailable.canToggle == false)
    }

    @Test func windowCatalogFilterKeepsOnlyFrontmostApplicationWindows() {
        let frontmostWindowA = WindowEntry.makeMock(
            seed: makeSeed(id: 401, pid: 6001, appName: "iTerm2", title: "Window A")
        )
        let backgroundWindow = WindowEntry.makeMock(
            seed: makeSeed(id: 402, pid: 6002, appName: "Google Chrome", title: "Window A")
        )
        let frontmostWindowB = WindowEntry.makeMock(
            seed: makeSeed(id: 403, pid: 6001, appName: "iTerm2", title: "Window B")
        )

        let filtered = WindowCatalogService.filter(
            [frontmostWindowA, backgroundWindow, frontmostWindowB],
            frontmostApplicationPID: 6001
        )

        #expect(filtered.map(\.id) == [frontmostWindowA.id, frontmostWindowB.id])
    }

    @Test func windowCatalogFilterFallsBackToAllWindowsWhenFrontmostHasNoCatalogEntries() {
        let firstWindow = WindowEntry.makeMock(
            seed: makeSeed(id: 411, pid: 6011, appName: "iTerm2", title: "Window A")
        )
        let secondWindow = WindowEntry.makeMock(
            seed: makeSeed(id: 412, pid: 6012, appName: "Google Chrome", title: "Window A")
        )

        let filtered = WindowCatalogService.filter(
            [firstWindow, secondWindow],
            frontmostApplicationPID: 9999
        )

        #expect(filtered.map(\.id) == [firstWindow.id, secondWindow.id])
    }

    @Test func windowCatalogFilterKeepsMinimizedFrontmostApplicationWindows() {
        let frontmostVisibleWindow = makeWindow(id: 421, pid: 6021, appName: "iTerm2", title: "Window A")
        let frontmostMinimizedWindow = makeWindow(
            id: 422,
            pid: 6021,
            appName: "iTerm2",
            title: "Minimized Window",
            isMinimized: true
        )
        let backgroundMinimizedWindow = makeWindow(
            id: 423,
            pid: 6022,
            appName: "Notes",
            title: "Background Minimized",
            isMinimized: true
        )

        let filtered = WindowCatalogService.filter(
            [frontmostVisibleWindow, frontmostMinimizedWindow, backgroundMinimizedWindow],
            frontmostApplicationPID: 6021
        )

        #expect(filtered.map(\.id) == [frontmostVisibleWindow.id, frontmostMinimizedWindow.id])
        #expect(filtered.last?.isMinimized == true)
    }

    @Test func windowCatalogMergeAppendsMinimizedWindowsAfterOnScreenWindows() {
        let onScreenWindow = makeWindow(id: 431, pid: 6031, appName: "Safari", title: "Visible")
        let minimizedWindow = makeWindow(
            id: 432,
            pid: 6031,
            appName: "Safari",
            title: "Minimized",
            isMinimized: true
        )

        let merged = WindowCatalogService.merge(
            onScreenEntries: [onScreenWindow],
            minimizedEntries: [minimizedWindow]
        )

        #expect(merged.map(\.id) == [onScreenWindow.id, minimizedWindow.id])
        #expect(merged[1].isMinimized)
    }

    @Test func windowCatalogMergeKeepsOnScreenEntryWhenIDsOverlap() {
        let onScreenWindow = makeWindow(id: 441, pid: 6041, appName: "Safari", title: "Visible")
        let duplicateMinimizedWindow = makeWindow(
            id: 441,
            pid: 6041,
            appName: "Safari",
            title: "Visible",
            isMinimized: true
        )

        let merged = WindowCatalogService.merge(
            onScreenEntries: [onScreenWindow],
            minimizedEntries: [duplicateMinimizedWindow]
        )

        #expect(merged == [onScreenWindow])
        #expect(merged.first?.isMinimized == false)
    }

    private func makeSeed(id: UInt32, pid: Int32, appName: String, title: String) -> UITestWindowSeed {
        UITestWindowSeed(
            id: id,
            pid: pid,
            appName: appName,
            bundleIdentifier: nil,
            title: title,
            x: 100,
            y: 100,
            width: 1200,
            height: 800,
            layer: 0,
            thumbnailMode: .success
        )
    }

    private func makeWindow(
        id: UInt32,
        pid: Int32,
        appName: String,
        title: String,
        isMinimized: Bool = false
    ) -> WindowEntry {
        WindowEntry(
            id: CGWindowID(id),
            pid: pid,
            appName: appName,
            bundleIdentifier: nil,
            title: title,
            bounds: CGRect(x: 100, y: 100, width: 1200, height: 800),
            layer: 0,
            isMinimized: isMinimized,
            appIcon: nil,
            thumbnail: nil
        )
    }
}

@MainActor
private final class RecordingSystemPermissionChecker: SystemPermissionChecking {
    let screenCaptureGranted: Bool
    let accessibilityGranted: Bool
    private(set) var accessibilityPromptRequests: [Bool] = []

    init(
        screenCaptureGranted: Bool,
        accessibilityGranted: Bool
    ) {
        self.screenCaptureGranted = screenCaptureGranted
        self.accessibilityGranted = accessibilityGranted
    }

    func isScreenCaptureGranted() -> Bool {
        screenCaptureGranted
    }

    func isAccessibilityGranted(prompt: Bool) -> Bool {
        accessibilityPromptRequests.append(prompt)
        return accessibilityGranted
    }
}
