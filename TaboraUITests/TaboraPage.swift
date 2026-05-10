import XCTest

struct UITestWindowSnapshot: Decodable, Equatable {
    let id: UInt32
    let title: String
    let appName: String
    let hasThumbnail: Bool
}

@MainActor
final class TaboraPage {
    private let backtabCharacter = "\u{19}"
    private let uiTestCommandNotification = Notification.Name("com.mkusaka.Tabora.uitest.command")
    private let uiTestCommandKey = "command"
    private let uiTestCommandFileEnvironmentKey = "UITEST_COMMAND_FILE"

    struct Seed: Encodable {
        let id: UInt32
        let pid: Int32
        let appName: String
        let bundleIdentifier: String?
        let title: String
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let layer: Int
        let thumbnailMode: String
    }

    let app: XCUIApplication
    private(set) var resultFileURL: URL?
    private(set) var selectionFileURL: URL?
    private(set) var snapshotFileURL: URL?
    private(set) var permissionFileURL: URL?
    private(set) var commandFileURL: URL?

    init(app: XCUIApplication) {
        self.app = app
    }

    func launch(
        seeds: [Seed],
        autoPresent: Bool = true,
        screenPermission: String = "granted",
        accessibilityPermission: String = "granted",
        activationMode: String = "success"
    ) {
        guard let data = try? JSONEncoder().encode(seeds) else {
            XCTFail("Failed to encode UI test seeds")
            return
        }
        let resultFileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tabora-uitest-\(UUID().uuidString).txt")
        let selectionFileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tabora-uitest-selection-\(UUID().uuidString).txt")
        let snapshotFileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tabora-uitest-snapshot-\(UUID().uuidString).json")
        let permissionFileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tabora-uitest-permission-\(UUID().uuidString).txt")
        let commandFileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tabora-uitest-command-\(UUID().uuidString).txt")
        try? FileManager.default.removeItem(at: resultFileURL)
        try? FileManager.default.removeItem(at: selectionFileURL)
        try? FileManager.default.removeItem(at: snapshotFileURL)
        try? FileManager.default.removeItem(at: permissionFileURL)
        try? FileManager.default.removeItem(at: commandFileURL)
        self.resultFileURL = resultFileURL
        self.selectionFileURL = selectionFileURL
        self.snapshotFileURL = snapshotFileURL
        self.permissionFileURL = permissionFileURL
        self.commandFileURL = commandFileURL
        app.launchArguments = ["-uiTesting"]
        app.launchEnvironment["UITEST_WINDOWS_JSON"] = String(data: data, encoding: .utf8)
        app.launchEnvironment["UITEST_SCREEN_PERMISSION"] = screenPermission
        app.launchEnvironment["UITEST_ACCESSIBILITY_PERMISSION"] = accessibilityPermission
        app.launchEnvironment["UITEST_ACTIVATION_MODE"] = activationMode
        app.launchEnvironment["UITEST_AUTOPRESENT"] = autoPresent ? "1" : "0"
        app.launchEnvironment["UITEST_RESULT_FILE"] = resultFileURL.path
        app.launchEnvironment["UITEST_SELECTION_FILE"] = selectionFileURL.path
        app.launchEnvironment["UITEST_SNAPSHOT_FILE"] = snapshotFileURL.path
        app.launchEnvironment["UITEST_PERMISSION_FILE"] = permissionFileURL.path
        app.launchEnvironment[uiTestCommandFileEnvironmentKey] = commandFileURL.path
        app.launch()
    }

    var presentSwitcherButton: XCUIElement {
        app.buttons["present-switcher-button"]
    }

    var overlayRoot: XCUIElement {
        let candidates = [
            app.windows["switcher-overlay-root"],
            app.windows["switcher-overlay-panel"],
            app.otherElements["switcher-overlay-root"],
            app.otherElements["switcher-overlay-panel"],
            app.groups["switcher-overlay-root"],
            app.groups["switcher-overlay-panel"],
        ]

        for candidate in candidates where candidate.exists {
            return candidate
        }

        return app.windows["switcher-overlay-panel"]
    }

    var permissionBanner: XCUIElement {
        app.staticTexts["permission-banner"]
    }

    var activationSummaryLabel: XCUIElement {
        let candidates = [
            app.staticTexts["activation-summary-label"],
            app.textFields["activation-summary-label"],
        ]

        for candidate in candidates where candidate.exists {
            return candidate
        }

        return app.staticTexts["activation-summary-label"]
    }

    var selectedWindowLabel: XCUIElement {
        app.staticTexts["selected-window-label"]
    }

    func card(_ id: UInt32) -> XCUIElement {
        let identifier = "window-card-\(id)"
        let candidates = [
            app.otherElements[identifier],
            app.groups[identifier],
            app.scrollViews.otherElements[identifier],
        ]

        for candidate in candidates where candidate.exists {
            return candidate
        }

        return app.otherElements[identifier]
    }

    func title(_ id: UInt32) -> XCUIElement {
        app.staticTexts["window-title-\(id)"]
    }

    func appName(_ id: UInt32) -> XCUIElement {
        app.staticTexts["window-app-\(id)"]
    }

    func thumbnailPlaceholder(_ id: UInt32) -> XCUIElement {
        let identifier = "thumbnail-placeholder-\(id)"
        let candidates = [
            app.otherElements[identifier],
            app.groups[identifier],
            app.staticTexts[identifier],
        ]

        for candidate in candidates where candidate.exists {
            return candidate
        }

        return app.otherElements[identifier]
    }

    func thumbnailImage(_ id: UInt32) -> XCUIElement {
        app.images["thumbnail-image-\(id)"]
    }

    func waitForOverlay(timeout: TimeInterval = 5) {
        XCTAssertTrue(overlayRoot.waitForExistence(timeout: timeout), "Overlay should appear")
    }

    func waitForOverlayToDisappear(timeout: TimeInterval = 5) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !overlayRoot.exists {
                return
            }
            usleep(100_000)
        }

        XCTAssertFalse(overlayRoot.exists, "Overlay should disappear")
    }

    func pressTab() {
        app.typeKey(XCUIKeyboardKey.tab.rawValue, modifierFlags: [])
    }

    func pressShiftTab() {
        guard let commandFileURL else {
            XCTFail("Command file should exist before sending UI test commands")
            return
        }
        try? "cycleBackward".write(to: commandFileURL, atomically: true, encoding: .utf8)
    }

    func pressEscape() {
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
    }

    func pressReturn() {
        app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
    }

    func cardSelectionValue(_ id: UInt32) -> String {
        app.staticTexts["window-card-state-\(id)"].label
    }

    func waitForCardToBeHittable(_ id: UInt32, timeout: TimeInterval = 3) -> Bool {
        let element = card(id)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.isHittable {
                return true
            }
            usleep(100_000)
        }

        return element.exists && element.isHittable
    }

    func waitForActivationSummary(containing text: String, timeout: TimeInterval = 8) -> Bool {
        if let resultFileURL {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if let summary = try? String(contentsOf: resultFileURL, encoding: .utf8), summary.contains(text) {
                    return true
                }
                usleep(100_000)
            }
            if let summary = try? String(contentsOf: resultFileURL, encoding: .utf8) {
                return summary.contains(text)
            }
        }

        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let label = app.staticTexts.matching(predicate).firstMatch
        return label.waitForExistence(timeout: timeout)
    }

    func waitForSelectedWindow(_ text: String, timeout: TimeInterval = 8) -> Bool {
        if let selectionFileURL {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if let selection = try? String(contentsOf: selectionFileURL, encoding: .utf8), selection == text {
                    return true
                }
                usleep(100_000)
            }
            if let selection = try? String(contentsOf: selectionFileURL, encoding: .utf8) {
                return selection == text
            }
        }

        return selectedWindowLabel.waitForExistence(timeout: timeout) && selectedWindowLabel.label == text
    }

    func waitForSnapshot(timeout: TimeInterval = 3) -> [UITestWindowSnapshot]? {
        guard let snapshotFileURL else {
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if
                let data = try? Data(contentsOf: snapshotFileURL),
                let snapshots = try? JSONDecoder().decode([UITestWindowSnapshot].self, from: data),
                !snapshots.isEmpty
            {
                return snapshots
            }
            usleep(100_000)
        }

        if
            let data = try? Data(contentsOf: snapshotFileURL),
            let snapshots = try? JSONDecoder().decode([UITestWindowSnapshot].self, from: data)
        {
            return snapshots
        }

        return nil
    }

    func waitForPermissionMessage(containing text: String, timeout: TimeInterval = 8) -> Bool {
        guard let permissionFileURL else {
            return false
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let message = try? String(contentsOf: permissionFileURL, encoding: .utf8), message.contains(text) {
                return true
            }
            usleep(100_000)
        }

        if let message = try? String(contentsOf: permissionFileURL, encoding: .utf8) {
            return message.contains(text)
        }

        return false
    }
}
