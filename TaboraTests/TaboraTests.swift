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
}
