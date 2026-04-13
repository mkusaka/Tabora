//
//  TaboraTests.swift
//  TaboraTests
//
//  Created by Masatomo Kusaka on 2026/04/12.
//

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
        let frontmostWindowA = WindowEntry.makeMock(seed: makeSeed(id: 401, pid: 6001, appName: "iTerm2", title: "Window A"))
        let backgroundWindow = WindowEntry.makeMock(seed: makeSeed(id: 402, pid: 6002, appName: "Google Chrome", title: "Window A"))
        let frontmostWindowB = WindowEntry.makeMock(seed: makeSeed(id: 403, pid: 6001, appName: "iTerm2", title: "Window B"))

        let filtered = WindowCatalogService.filter(
            [frontmostWindowA, backgroundWindow, frontmostWindowB],
            frontmostApplicationPID: 6001
        )

        #expect(filtered.map(\.id) == [frontmostWindowA.id, frontmostWindowB.id])
    }

    @Test func windowCatalogFilterFallsBackToAllWindowsWhenFrontmostHasNoCatalogEntries() {
        let firstWindow = WindowEntry.makeMock(seed: makeSeed(id: 411, pid: 6011, appName: "iTerm2", title: "Window A"))
        let secondWindow = WindowEntry.makeMock(seed: makeSeed(id: 412, pid: 6012, appName: "Google Chrome", title: "Window A"))

        let filtered = WindowCatalogService.filter(
            [firstWindow, secondWindow],
            frontmostApplicationPID: 9999
        )

        #expect(filtered.map(\.id) == [firstWindow.id, secondWindow.id])
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
}
