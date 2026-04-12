import ApplicationServices
import Foundation

protocol PermissionProviding {
    func currentStatus() -> PermissionStatus
    func primeForUserVisibleFlow()
}

final class PermissionService: PermissionProviding {
    private var hasPromptedAccessibility = false

    func currentStatus() -> PermissionStatus {
        let accessibilityOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let screenCaptureGranted = CGPreflightScreenCaptureAccess()
        let accessibilityGranted = AXIsProcessTrustedWithOptions(accessibilityOptions)

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

        hasPromptedAccessibility = true
        let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        TaboraLogger.log("permission", "Priming accessibility prompt")
        _ = AXIsProcessTrustedWithOptions(promptOptions)
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
