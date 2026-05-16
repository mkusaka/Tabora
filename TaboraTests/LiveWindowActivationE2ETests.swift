import AppKit
import CoreGraphics
@testable import Tabora
import Testing

private let liveWindowActivationE2EEnabled =
    ProcessInfo.processInfo.environment["TABORA_ENABLE_LIVE_E2E"] == "1"
        || FileManager.default.fileExists(atPath: "/tmp/tabora-enable-live-e2e")
        || FileManager.default.fileExists(
            atPath: URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("tabora-enable-live-e2e")
                .path
        )

@MainActor
struct LiveWindowActivationE2ETests {
    @Test(.enabled(if: liveWindowActivationE2EEnabled))
    func windowActivationFocusesTheSelectedRealTextEditWindow() async throws {
        let textEditBundleID = "com.apple.TextEdit"
        let finderBundleID = "com.apple.finder"
        let textEditURL = try #require(NSWorkspace.shared.urlForApplication(withBundleIdentifier: textEditBundleID))
        let finderURL = try #require(NSWorkspace.shared.urlForApplication(withBundleIdentifier: finderBundleID))
        let opener = WorkspaceApplicationOpener()
        let existingTextEdit = NSRunningApplication.runningApplications(withBundleIdentifier: textEditBundleID).first
        let wasTextEditRunning = existingTextEdit != nil
        let existingWindowIDs = existingTextEdit
            .map { Set(onScreenWindows(processIdentifier: $0.processIdentifier).map(\.id)) } ?? []

        let firstDocument = try makeTemporaryTextDocument(prefix: "TaboraLiveE2E-A")
        let secondDocument = try makeTemporaryTextDocument(prefix: "TaboraLiveE2E-B")
        defer {
            try? FileManager.default.removeItem(at: firstDocument)
            try? FileManager.default.removeItem(at: secondDocument)
            if !wasTextEditRunning {
                NSRunningApplication.runningApplications(withBundleIdentifier: textEditBundleID)
                    .forEach { $0.terminate() }
            }
        }

        #expect(await openDocuments([firstDocument, secondDocument], withApplicationAt: textEditURL))
        let textEdit = try #require(await waitForRunningApplication(bundleIdentifier: textEditBundleID))
        let windows = try #require(await waitForNewWindows(
            processIdentifier: textEdit.processIdentifier,
            excluding: existingWindowIDs,
            minimumCount: 2
        ))
        let currentTopWindowID = try #require(topWindowID(processIdentifier: textEdit.processIdentifier))
        let targetWindow = windows.first { $0.id != currentTopWindowID } ?? windows[0]

        #expect(await opener.openApplication(at: finderURL))
        #expect(await waitForFrontmostApplication(bundleIdentifier: finderBundleID))

        let service = WindowActivationService(
            permissionService: UITestPermissionService(screenCapture: .granted, accessibility: .granted)
        )
        let result = await service.activate(window: targetWindow)

        #expect(result == .success(title: targetWindow.displayTitle))
        #expect(await waitForFrontmostApplication(bundleIdentifier: textEditBundleID))
        #expect(await waitForTopWindow(processIdentifier: textEdit.processIdentifier, windowID: targetWindow.id))
    }

    private func makeTemporaryTextDocument(prefix: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
            .appendingPathExtension("txt")
        try "Tabora live window activation E2E\n".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private nonisolated func openDocuments(_ documentURLs: [URL], withApplicationAt applicationURL: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.open(
                documentURLs,
                withApplicationAt: applicationURL,
                configuration: configuration,
                completionHandler: { application, error in
                    continuation.resume(returning: application != nil && error == nil)
                }
            )
        }
    }

    private func waitForRunningApplication(bundleIdentifier: String) async -> NSRunningApplication? {
        for _ in 0 ..< 150 {
            let application = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
            if let application {
                return application
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        return nil
    }

    private func waitForNewWindows(
        processIdentifier: pid_t,
        excluding existingWindowIDs: Set<CGWindowID>,
        minimumCount: Int
    ) async -> [WindowEntry]? {
        for _ in 0 ..< 150 {
            let newWindows = onScreenWindows(processIdentifier: processIdentifier).filter {
                !existingWindowIDs.contains($0.id)
            }
            if newWindows.count >= minimumCount {
                return newWindows
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        return nil
    }

    private func waitForFrontmostApplication(bundleIdentifier: String) async -> Bool {
        for _ in 0 ..< 150 {
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleIdentifier {
                return true
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        return false
    }

    private func waitForTopWindow(processIdentifier: pid_t, windowID: CGWindowID) async -> Bool {
        for _ in 0 ..< 150 {
            if topWindowID(processIdentifier: processIdentifier) == windowID {
                return true
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        return false
    }

    private func topWindowID(processIdentifier: pid_t) -> CGWindowID? {
        onScreenWindows(processIdentifier: processIdentifier).first?.id
    }

    private func onScreenWindows(processIdentifier: pid_t) -> [WindowEntry] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: AnyObject]] else {
            return []
        }

        return windowInfo.compactMap { info in
            makeWindow(from: info, processIdentifier: processIdentifier)
        }
    }

    private func makeWindow(from info: [String: AnyObject], processIdentifier: pid_t) -> WindowEntry? {
        guard
            let ownerPID = info[kCGWindowOwnerPID as String] as? NSNumber,
            ownerPID.int32Value == processIdentifier,
            let layer = info[kCGWindowLayer as String] as? NSNumber,
            layer.intValue == 0,
            let windowNumber = info[kCGWindowNumber as String] as? NSNumber,
            let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsDictionary)
        else {
            return nil
        }

        return WindowEntry(
            id: CGWindowID(windowNumber.uint32Value),
            pid: processIdentifier,
            appName: (info[kCGWindowOwnerName as String] as? String) ?? "TextEdit",
            bundleIdentifier: "com.apple.TextEdit",
            title: (info[kCGWindowName as String] as? String) ?? "",
            bounds: bounds,
            layer: layer.intValue,
            isMinimized: false,
            appIcon: nil,
            thumbnail: nil
        )
    }
}
