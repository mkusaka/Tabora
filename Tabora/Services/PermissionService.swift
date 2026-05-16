@preconcurrency import ApplicationServices
import Foundation

@MainActor
protocol PermissionProviding {
    func currentStatus() -> PermissionStatus
    func primeForUserVisibleFlow()
}

@MainActor
protocol SystemPermissionChecking {
    func isScreenCaptureGranted() -> Bool
    func isAccessibilityGranted(prompt: Bool) -> Bool
}

struct LiveSystemPermissionChecker: SystemPermissionChecking {
    func isScreenCaptureGranted() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    func isAccessibilityGranted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

final class PermissionService: PermissionProviding {
    private var hasPromptedAccessibility = false
    private let systemPermissionChecker: any SystemPermissionChecking

    init(systemPermissionChecker: any SystemPermissionChecking = LiveSystemPermissionChecker()) {
        self.systemPermissionChecker = systemPermissionChecker
    }

    func currentStatus() -> PermissionStatus {
        let screenCaptureGranted = systemPermissionChecker.isScreenCaptureGranted()
        let accessibilityGranted = systemPermissionChecker.isAccessibilityGranted(prompt: false)

        let status = PermissionStatus(
            screenCapture: screenCaptureGranted ? .granted : .missing,
            accessibility: accessibilityGranted ? .granted : .missing
        )
        TaboraLogger.log("permission", "Current status: \(status.logSummary)")
        return status
    }

    func primeForUserVisibleFlow() {
        guard !hasPromptedAccessibility else {
            TaboraLogger.log("permission", "Accessibility prompt already attempted in this process")
            return
        }

        guard !systemPermissionChecker.isAccessibilityGranted(prompt: false) else {
            TaboraLogger.log("permission", "Accessibility already granted, skipping prompt")
            return
        }

        hasPromptedAccessibility = true
        TaboraLogger.log("permission", "Priming accessibility prompt")
        _ = systemPermissionChecker.isAccessibilityGranted(prompt: true)
    }
}

struct UITestPermissionService: PermissionProviding {
    let screenCapture: PermissionAccessState
    let accessibility: PermissionAccessState

    func currentStatus() -> PermissionStatus {
        PermissionStatus(screenCapture: screenCapture, accessibility: accessibility)
    }

    func primeForUserVisibleFlow() {}
}
