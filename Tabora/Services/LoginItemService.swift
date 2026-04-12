import AppKit
import Foundation
import ServiceManagement

protocol LoginItemManaging {
    func currentStatus() -> LoginItemStatus
    @discardableResult
    func setEnabled(_ enabled: Bool) -> LoginItemStatus
}

enum LoginItemStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable

    var menuDescription: String {
        switch self {
        case .enabled:
            "Enabled"
        case .disabled:
            "Disabled"
        case .requiresApproval:
            "Needs Approval"
        case .unavailable:
            "Unavailable"
        }
    }

    var menuState: NSControl.StateValue {
        switch self {
        case .enabled:
            .on
        case .disabled, .unavailable:
            .off
        case .requiresApproval:
            .mixed
        }
    }

    var canToggle: Bool {
        self != .unavailable
    }

    var isEnabled: Bool {
        self == .enabled
    }
}

struct LoginItemService: LoginItemManaging {
    func currentStatus() -> LoginItemStatus {
        guard #available(macOS 13.0, *) else {
            return .unavailable
        }

        let status: LoginItemStatus = switch SMAppService.mainApp.status {
        case .enabled:
            .enabled
        case .notRegistered, .notFound:
            .disabled
        case .requiresApproval:
            .requiresApproval
        @unknown default:
            .unavailable
        }

        TaboraLogger.log("login-item", "Current status: \(status.menuDescription)")
        return status
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> LoginItemStatus {
        guard #available(macOS 13.0, *) else {
            TaboraLogger.log("login-item", "Toggle ignored because SMAppService is unavailable")
            return .unavailable
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
                TaboraLogger.log("login-item", "Registered main app for login item launch")
            } else {
                try SMAppService.mainApp.unregister()
                TaboraLogger.log("login-item", "Unregistered main app from login item launch")
            }
        } catch {
            TaboraLogger.log("login-item", "Failed to update login item state: \(error.localizedDescription)")
        }

        return currentStatus()
    }
}
