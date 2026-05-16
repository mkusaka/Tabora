import AppKit
import ApplicationServices
import CoreGraphics

@_silgen_name("_AXUIElementGetWindow")
private func axUIElementGetWindowCompat(
    _ element: AXUIElement,
    _ windowID: UnsafeMutablePointer<CGWindowID>
) -> AXError

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

@MainActor
protocol WindowActivating {
    func activate(window: WindowEntry) async -> WindowActivationResult
}

@MainActor
protocol RunningApplicationActivating {
    var processIdentifier: pid_t { get }
    var bundleURL: URL? { get }

    func activate(options: NSApplication.ActivationOptions) -> Bool
    func activateFromCurrentApplication(options: NSApplication.ActivationOptions) -> Bool
}

extension NSRunningApplication: RunningApplicationActivating {
    func activateFromCurrentApplication(options: NSApplication.ActivationOptions) -> Bool {
        NSApp.yieldActivation(to: self)
        return activate(from: .current, options: options)
    }
}

@MainActor
protocol RunningApplicationResolving {
    func runningApplication(processIdentifier: pid_t) -> (any RunningApplicationActivating)?
}

protocol ApplicationOpening: Sendable {
    func openApplication(at bundleURL: URL) async -> Bool
}

struct WorkspaceRunningApplicationResolver: RunningApplicationResolving {
    func runningApplication(processIdentifier: pid_t) -> (any RunningApplicationActivating)? {
        NSRunningApplication(processIdentifier: processIdentifier)
    }
}

struct WorkspaceApplicationOpener: ApplicationOpening {
    func openApplication(at bundleURL: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true

            NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { application, error in
                if let error {
                    TaboraLogger.log(
                        "activation",
                        "NSWorkspace.openApplication failed for \(bundleURL.path): \(error.localizedDescription)"
                    )
                }

                continuation.resume(returning: application != nil && error == nil)
            }
        }
    }
}

struct WindowActivationService: WindowActivating {
    let permissionService: PermissionProviding
    private let applicationResolver: any RunningApplicationResolving
    private let applicationOpener: any ApplicationOpening
    private let windowServerFocuser: any WindowServerFocusing

    init(
        permissionService: any PermissionProviding,
        applicationResolver: any RunningApplicationResolving = WorkspaceRunningApplicationResolver(),
        applicationOpener: any ApplicationOpening = WorkspaceApplicationOpener(),
        windowServerFocuser: any WindowServerFocusing = SkyLightWindowServerFocuser()
    ) {
        self.permissionService = permissionService
        self.applicationResolver = applicationResolver
        self.applicationOpener = applicationOpener
        self.windowServerFocuser = windowServerFocuser
    }

    func activate(window: WindowEntry) async -> WindowActivationResult {
        guard let app = applicationResolver.runningApplication(processIdentifier: window.pid) else {
            TaboraLogger.log("activation", "No running app for pid=\(window.pid) title=\(window.displayTitle)")
            return .failure(title: window.displayTitle)
        }

        let hasAccessibility = permissionService.currentStatus().accessibility == .granted
        if hasAccessibility {
            let raised = raiseBestMatchingWindow(for: window)
            TaboraLogger.log(
                "activation",
                raised
                    ? "Raised exact window for \(window.displayTitle)"
                    : "Fell back to app activation for \(window.displayTitle)"
            )
            if raised {
                return .success(title: window.displayTitle)
            }
        } else {
            TaboraLogger.log("activation", "Accessibility missing, using app fallback for \(window.displayTitle)")
        }

        let appActivated = await activateApplication(app)
        guard appActivated else {
            TaboraLogger.log("activation", "App activation failed for pid=\(window.pid) title=\(window.displayTitle)")
            return .failure(title: window.displayTitle)
        }

        if hasAccessibility, raiseBestMatchingWindow(for: window) {
            TaboraLogger.log("activation", "Raised exact window after app activation for \(window.displayTitle)")
            return .success(title: window.displayTitle)
        }

        return .appOnly(title: window.displayTitle)
    }

    private func activateApplication(_ app: any RunningApplicationActivating) async -> Bool {
        if let bundleURL = app.bundleURL {
            let opened = await applicationOpener.openApplication(at: bundleURL)
            TaboraLogger.log(
                "activation",
                """
                NSWorkspace.openApplication result=\(opened) \
                bundleURL=\(bundleURL.path) targetPID=\(app.processIdentifier)
                """
            )

            if opened {
                return true
            }
        }

        let activated = app.activateFromCurrentApplication(options: [.activateAllWindows])
        TaboraLogger.log(
            "activation",
            "NSRunningApplication fallback result=\(activated) targetPID=\(app.processIdentifier)"
        )
        return activated
    }

    private func raiseBestMatchingWindow(for target: WindowEntry) -> Bool {
        let windowServerFocused = focusWindowThroughWindowServer(target)
        let applicationElement = AXUIElementCreateApplication(target.pid)
        guard let windows = copyWindows(from: applicationElement), !windows.isEmpty else {
            return windowServerFocused
        }

        guard
            let bestMatch = windows.max(by: { score($0, against: target) < score($1, against: target) })
        else {
            return windowServerFocused
        }

        if target.isMinimized || copyBoolAttribute(kAXMinimizedAttribute as CFString, from: bestMatch) {
            _ = AXUIElementSetAttributeValue(bestMatch, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }

        let raiseResult = AXUIElementPerformAction(bestMatch, kAXRaiseAction as CFString)
        _ = AXUIElementSetAttributeValue(applicationElement, kAXMainWindowAttribute as CFString, bestMatch)
        _ = AXUIElementSetAttributeValue(applicationElement, kAXFocusedWindowAttribute as CFString, bestMatch)
        return windowServerFocused || raiseResult == .success
    }

    private func focusWindowThroughWindowServer(_ target: WindowEntry) -> Bool {
        guard !target.isMinimized else {
            return false
        }

        return windowServerFocuser.focusWindow(
            processIdentifier: target.pid,
            windowID: target.id
        )
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

        if copyWindowID(from: windowElement) == target.id {
            total += 100
        }

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

        if copyBoolAttribute(kAXMinimizedAttribute as CFString, from: windowElement) == target.isMinimized {
            total += 3
        }

        return total
    }

    private func copyWindowID(from element: AXUIElement) -> CGWindowID? {
        var windowID = CGWindowID(0)
        guard axUIElementGetWindowCompat(element, &windowID) == .success, windowID != 0 else {
            return nil
        }

        return windowID
    }

    private func copyStringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }

        return value as? String
    }

    private func copyBoolAttribute(_ attribute: CFString, from element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return false
        }

        return (value as? NSNumber)?.boolValue ?? false
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
