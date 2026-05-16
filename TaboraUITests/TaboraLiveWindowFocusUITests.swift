import AppKit
import CoreGraphics
import XCTest

final class TaboraLiveWindowFocusUITests: TaboraUITestCase {
    private let textEditBundleIdentifier = "com.apple.TextEdit"

    func testReturnFocusesSelectedRealTextEditWindow() throws {
        guard ProcessInfo.processInfo.environment["TABORA_ENABLE_LIVE_FOCUS_UI_TEST"] == "1" else {
            throw XCTSkip("Enable with TABORA_ENABLE_LIVE_FOCUS_UI_TEST=1 on an Accessibility-trusted runner.")
        }

        let fixture = try makeTextEditFocusFixture()
        defer { cleanUp(fixture) }

        page.launch(
            seeds: fixture.seeds,
            activationMode: "live"
        )
        page.waitForOverlay()
        XCTAssertTrue(page.waitForSelectedWindow("Target TextEdit Window"))

        page.pressReturn()

        XCTAssertTrue(
            page.waitForActivationSummary(containing: "Activated"),
            "Expected live activation to complete before checking window focus"
        )
        let actualTopWindowID = topWindowID(processIdentifier: fixture.textEdit.processIdentifier)
        XCTAssertTrue(
            waitForTopWindow(processIdentifier: fixture.textEdit.processIdentifier, windowID: fixture.targetWindow.id),
            """
            Expected window \(fixture.targetWindow.id) to become TextEdit's front window. \
            originalTop=\(fixture.originalTopWindowID) actualTop=\(String(describing: actualTopWindowID)) \
            windows=\(fixture.windows.map(\.id))
            """
        )
    }

    private struct FocusFixture {
        let textEdit: NSRunningApplication
        let documents: TemporaryDocuments
        let wasTextEditRunning: Bool
        let originalTopWindowID: CGWindowID
        let targetWindow: WindowSnapshot
        let windows: [WindowSnapshot]
        let seeds: [TaboraPage.Seed]
    }

    private struct TemporaryDocuments {
        let directory: URL
        let urls: [URL]
    }

    private struct WindowSnapshot {
        let id: CGWindowID
        let processIdentifier: pid_t
        let appName: String
        let bounds: CGRect
    }

    private func makeTextEditFocusFixture() throws -> FocusFixture {
        let textEditURL = try XCTUnwrap(
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: textEditBundleIdentifier)
        )
        let existingTextEdit = NSRunningApplication.runningApplications(
            withBundleIdentifier: textEditBundleIdentifier
        ).first
        let existingWindowIDs = existingTextEdit
            .map { Set(onScreenWindows(processIdentifier: $0.processIdentifier).map(\.id)) } ?? []
        let documents = try makeTemporaryTextDocuments()

        try openDocuments(documents.urls, with: textEditURL)
        let textEdit = try XCTUnwrap(waitForRunningApplication(bundleIdentifier: textEditBundleIdentifier))
        let windows = try XCTUnwrap(
            waitForNewWindows(
                processIdentifier: textEdit.processIdentifier,
                excluding: existingWindowIDs,
                minimumCount: 2
            )
        )
        let originalTopWindowID = try XCTUnwrap(topWindowID(processIdentifier: textEdit.processIdentifier))
        let originalTopWindow = windows.first { $0.id == originalTopWindowID } ?? windows[0]
        let targetWindow = try XCTUnwrap(windows.first { $0.id != originalTopWindowID })

        return FocusFixture(
            textEdit: textEdit,
            documents: documents,
            wasTextEditRunning: existingTextEdit != nil,
            originalTopWindowID: originalTopWindowID,
            targetWindow: targetWindow,
            windows: windows,
            seeds: [
                makeSeed(from: originalTopWindow, title: "Current TextEdit Window"),
                makeSeed(from: targetWindow, title: "Target TextEdit Window"),
            ]
        )
    }

    private func cleanUp(_ fixture: FocusFixture) {
        try? FileManager.default.removeItem(at: fixture.documents.directory)
        if !fixture.wasTextEditRunning {
            terminateTextEdit()
        }
    }

    private func makeTemporaryTextDocuments() throws -> TemporaryDocuments {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tabora-live-focus-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let urls = try (1 ... 2).map { index in
            let url = directory
                .appendingPathComponent("TaboraLiveFocus-\(index)-\(UUID().uuidString)")
                .appendingPathExtension("txt")
            try "Tabora live focus UI test \(index)\n".write(to: url, atomically: true, encoding: .utf8)
            return url
        }

        return TemporaryDocuments(directory: directory, urls: urls)
    }

    private func openDocuments(_ urls: [URL], with applicationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", applicationURL.path] + urls.map(\.path)
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }

    private func waitForRunningApplication(
        bundleIdentifier: String,
        timeout: TimeInterval = 10
    ) -> NSRunningApplication? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let application = NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleIdentifier)
                .first
            {
                return application
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        return nil
    }

    private func waitForNewWindows(
        processIdentifier: pid_t,
        excluding existingWindowIDs: Set<CGWindowID>,
        minimumCount: Int,
        timeout: TimeInterval = 10
    ) -> [WindowSnapshot]? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let windows = onScreenWindows(processIdentifier: processIdentifier).filter {
                !existingWindowIDs.contains($0.id)
            }
            if windows.count >= minimumCount {
                return windows
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        return nil
    }

    private func waitForTopWindow(
        processIdentifier: pid_t,
        windowID: CGWindowID,
        timeout: TimeInterval = 10
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if topWindowID(processIdentifier: processIdentifier) == windowID {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        return false
    }

    private func topWindowID(processIdentifier: pid_t) -> CGWindowID? {
        onScreenWindows(processIdentifier: processIdentifier).first?.id
    }

    private func onScreenWindows(processIdentifier: pid_t) -> [WindowSnapshot] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: AnyObject]] else {
            return []
        }

        return windowInfo.compactMap { info in
            makeWindowSnapshot(from: info, processIdentifier: processIdentifier)
        }
    }

    private func makeWindowSnapshot(from info: [String: AnyObject], processIdentifier: pid_t) -> WindowSnapshot? {
        guard
            let ownerPID = info[kCGWindowOwnerPID as String] as? NSNumber,
            ownerPID.int32Value == processIdentifier,
            let layer = info[kCGWindowLayer as String] as? NSNumber,
            layer.intValue == 0,
            let windowNumber = info[kCGWindowNumber as String] as? NSNumber,
            let ownerName = info[kCGWindowOwnerName as String] as? String,
            let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsDictionary)
        else {
            return nil
        }

        return WindowSnapshot(
            id: CGWindowID(windowNumber.uint32Value),
            processIdentifier: processIdentifier,
            appName: ownerName,
            bounds: bounds
        )
    }

    private func makeSeed(from window: WindowSnapshot, title: String) -> TaboraPage.Seed {
        TaboraPage.Seed(
            id: UInt32(window.id),
            pid: window.processIdentifier,
            appName: window.appName,
            bundleIdentifier: textEditBundleIdentifier,
            title: title,
            x: window.bounds.origin.x,
            y: window.bounds.origin.y,
            width: window.bounds.size.width,
            height: window.bounds.size.height,
            layer: 0,
            thumbnailMode: "missing"
        )
    }

    private func terminateTextEdit() {
        NSRunningApplication.runningApplications(withBundleIdentifier: textEditBundleIdentifier)
            .forEach { $0.terminate() }
    }
}
