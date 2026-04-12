import AppKit
import ApplicationServices
import CoreGraphics

enum WindowActivationResult: Equatable {
    case success(title: String)
    case appOnly(title: String)
    case failure(title: String)

    var userFacingDescription: String {
        switch self {
        case let .success(title):
            "Activated \(title)"
        case let .appOnly(title):
            "Activated app fallback for \(title)"
        case let .failure(title):
            "Failed to activate \(title)"
        }
    }
}

protocol WindowActivating {
    func activate(window: WindowEntry) async -> WindowActivationResult
}

struct WindowActivationService: WindowActivating {
    let permissionService: PermissionProviding

    func activate(window: WindowEntry) async -> WindowActivationResult {
        guard let app = NSRunningApplication(processIdentifier: window.pid) else {
            TaboraLogger.log("activation", "No running app for pid=\(window.pid) title=\(window.displayTitle)")
            return .failure(title: window.displayTitle)
        }

        let appActivated = app.activate(options: [.activateAllWindows])
        guard appActivated else {
            TaboraLogger.log("activation", "App activation failed for pid=\(window.pid) title=\(window.displayTitle)")
            return .failure(title: window.displayTitle)
        }

        guard permissionService.currentStatus().accessibility == .granted else {
            TaboraLogger.log("activation", "Accessibility missing, using app fallback for \(window.displayTitle)")
            return .appOnly(title: window.displayTitle)
        }

        let raised = raiseBestMatchingWindow(for: window)
        TaboraLogger.log(
            "activation",
            raised
                ? "Raised exact window for \(window.displayTitle)"
                : "Fell back to app activation for \(window.displayTitle)"
        )
        return raised ? .success(title: window.displayTitle) : .appOnly(title: window.displayTitle)
    }

    private func raiseBestMatchingWindow(for target: WindowEntry) -> Bool {
        let applicationElement = AXUIElementCreateApplication(target.pid)
        guard let windows = copyWindows(from: applicationElement), !windows.isEmpty else {
            return false
        }

        guard
            let bestMatch = windows.max(by: { score($0, against: target) < score($1, against: target) })
        else {
            return false
        }

        _ = AXUIElementPerformAction(bestMatch, kAXRaiseAction as CFString)
        _ = AXUIElementSetAttributeValue(applicationElement, kAXMainWindowAttribute as CFString, bestMatch)
        _ = AXUIElementSetAttributeValue(applicationElement, kAXFocusedWindowAttribute as CFString, bestMatch)
        return true
    }

    private func copyWindows(from applicationElement: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(applicationElement, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let array = value as? [AXUIElement] else {
            return nil
        }
        return array
    }

    private func score(_ windowElement: AXUIElement, against target: WindowEntry) -> Int {
        var total = 0

        if let title = copyStringAttribute(kAXTitleAttribute as CFString, from: windowElement) {
            if title == target.title {
                total += 5
            } else if !target.title.isEmpty, title.localizedCaseInsensitiveContains(target.title) {
                total += 2
            }
        }

        if let frame = copyFrame(from: windowElement), roughlyMatches(frame, target.bounds) {
            total += 4
        }

        return total
    }

    private func copyStringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }

        return value as? String
    }

    private func copyFrame(from element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        guard
            AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
            AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
            let positionValue,
            let sizeValue
        else {
            return nil
        }

        // AXUIElementCopyAttributeValue returns AXValue-backed CFTypeRefs for these attributes.
        // swiftlint:disable:next force_cast
        let positionAX = positionValue as! AXValue
        // swiftlint:disable:next force_cast
        let sizeAX = sizeValue as! AXValue

        var point = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetType(positionAX) == .cgPoint,
            AXValueGetType(sizeAX) == .cgSize,
            AXValueGetValue(positionAX, .cgPoint, &point),
            AXValueGetValue(sizeAX, .cgSize, &size)
        else {
            return nil
        }

        return CGRect(origin: point, size: size)
    }

    private func roughlyMatches(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) < 24
            && abs(lhs.origin.y - rhs.origin.y) < 24
            && abs(lhs.size.width - rhs.size.width) < 32
            && abs(lhs.size.height - rhs.size.height) < 32
    }
}

@MainActor
final class UITestActivationRecorder: ObservableObject {
    @Published private(set) var lastResultDescription = "Idle"
    private let summaryFileURL: URL?

    init(summaryFileURL: URL? = nil) {
        self.summaryFileURL = summaryFileURL
    }

    func record(_ result: WindowActivationResult) {
        record(summary: result.userFacingDescription)
    }

    func record(summary: String) {
        lastResultDescription = summary

        guard let summaryFileURL else {
            return
        }

        try? summary.write(to: summaryFileURL, atomically: true, encoding: .utf8)
    }
}

struct UITestWindowActivationService: WindowActivating {
    enum Mode: String {
        case success
        case appOnly
        case failure
    }

    let mode: Mode
    let recorder: UITestActivationRecorder

    func activate(window: WindowEntry) async -> WindowActivationResult {
        let result: WindowActivationResult = switch mode {
        case .success:
            .success(title: window.displayTitle)
        case .appOnly:
            .appOnly(title: window.displayTitle)
        case .failure:
            .failure(title: window.displayTitle)
        }

        await MainActor.run {
            recorder.record(result)
        }

        return result
    }
}
