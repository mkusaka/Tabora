import AppKit
import CoreGraphics
@testable import Tabora
import Testing

@MainActor
struct WindowActivationServiceTests {
    @Test func windowActivationRequestsCooperativeActivationFromOverlayApp() async {
        let application = RecordingRunningApplication(processIdentifier: 6051)
        let service = WindowActivationService(
            permissionService: UITestPermissionService(screenCapture: .granted, accessibility: .missing),
            applicationResolver: StubRunningApplicationResolver(application: application)
        )

        let result = await service.activate(
            window: makeWindow(id: 451, pid: 6051, appName: "Safari", title: "Selected Window")
        )

        #expect(result == .appOnly(title: "Selected Window"))
        #expect(application.directActivationOptions.isEmpty)
        #expect(application.currentApplicationActivationOptions == [.activateAllWindows])
    }

    @Test func windowActivationOpensApplicationBundleBeforeRunningApplicationFallback() async {
        let bundleURL = URL(fileURLWithPath: "/Applications/Safari.app")
        let application = RecordingRunningApplication(
            processIdentifier: 6052,
            bundleURL: bundleURL
        )
        let opener = RecordingApplicationOpener(result: true)
        let service = WindowActivationService(
            permissionService: UITestPermissionService(screenCapture: .granted, accessibility: .missing),
            applicationResolver: StubRunningApplicationResolver(application: application),
            applicationOpener: opener
        )

        let result = await service.activate(
            window: makeWindow(id: 452, pid: 6052, appName: "Safari", title: "Selected Window")
        )

        #expect(result == .appOnly(title: "Selected Window"))
        #expect(await opener.openedBundleURLsSnapshot() == [bundleURL])
        #expect(application.directActivationOptions.isEmpty)
        #expect(application.currentApplicationActivationOptions.isEmpty)
    }

    @Test func windowActivationFallsBackToRunningApplicationWhenBundleOpenFails() async {
        let bundleURL = URL(fileURLWithPath: "/Applications/Safari.app")
        let application = RecordingRunningApplication(
            processIdentifier: 6053,
            bundleURL: bundleURL
        )
        let opener = RecordingApplicationOpener(result: false)
        let service = WindowActivationService(
            permissionService: UITestPermissionService(screenCapture: .granted, accessibility: .missing),
            applicationResolver: StubRunningApplicationResolver(application: application),
            applicationOpener: opener
        )

        let result = await service.activate(
            window: makeWindow(id: 453, pid: 6053, appName: "Safari", title: "Selected Window")
        )

        #expect(result == .appOnly(title: "Selected Window"))
        #expect(await opener.openedBundleURLsSnapshot() == [bundleURL])
        #expect(application.directActivationOptions.isEmpty)
        #expect(application.currentApplicationActivationOptions == [.activateAllWindows])
    }

    @Test func windowActivationFocusesWindowServerWindowBeforeAppActivationFallback() async {
        let application = RecordingRunningApplication(processIdentifier: 6054)
        let focuser = RecordingWindowServerFocuser(result: true)
        let service = WindowActivationService(
            permissionService: UITestPermissionService(screenCapture: .granted, accessibility: .granted),
            applicationResolver: StubRunningApplicationResolver(application: application),
            windowServerFocuser: focuser
        )

        let result = await service.activate(
            window: makeWindow(id: 454, pid: 6054, appName: "Safari", title: "Selected Window")
        )

        #expect(result == .success(title: "Selected Window"))
        #expect(focuser.requests == [WindowServerFocusRequest(processIdentifier: 6054, windowID: 454)])
        #expect(application.currentApplicationActivationOptions.isEmpty)
    }

    @Test func windowActivationFallsBackToAppActivationWhenExactFocusFails() async {
        let application = RecordingRunningApplication(processIdentifier: 6056)
        let focuser = RecordingWindowServerFocuser(results: [false, false])
        let service = WindowActivationService(
            permissionService: UITestPermissionService(screenCapture: .granted, accessibility: .granted),
            applicationResolver: StubRunningApplicationResolver(application: application),
            windowServerFocuser: focuser
        )

        let result = await service.activate(
            window: makeWindow(id: 456, pid: 6056, appName: "Safari", title: "Selected Window")
        )

        #expect(result == .appOnly(title: "Selected Window"))
        #expect(focuser.requests == [
            WindowServerFocusRequest(processIdentifier: 6056, windowID: 456),
            WindowServerFocusRequest(processIdentifier: 6056, windowID: 456),
        ])
        #expect(application.currentApplicationActivationOptions == [.activateAllWindows])
    }

    @Test func windowActivationRetriesExactFocusAfterAppActivationFallback() async {
        let application = RecordingRunningApplication(processIdentifier: 6057)
        let focuser = RecordingWindowServerFocuser(results: [false, true])
        let service = WindowActivationService(
            permissionService: UITestPermissionService(screenCapture: .granted, accessibility: .granted),
            applicationResolver: StubRunningApplicationResolver(application: application),
            windowServerFocuser: focuser
        )

        let result = await service.activate(
            window: makeWindow(id: 457, pid: 6057, appName: "Safari", title: "Selected Window")
        )

        #expect(result == .success(title: "Selected Window"))
        #expect(focuser.requests == [
            WindowServerFocusRequest(processIdentifier: 6057, windowID: 457),
            WindowServerFocusRequest(processIdentifier: 6057, windowID: 457),
        ])
        #expect(application.currentApplicationActivationOptions == [.activateAllWindows])
    }

    @Test func windowActivationSkipsWindowServerFocusForMinimizedWindows() async {
        let application = RecordingRunningApplication(processIdentifier: 6055)
        let focuser = RecordingWindowServerFocuser(result: true)
        let service = WindowActivationService(
            permissionService: UITestPermissionService(screenCapture: .granted, accessibility: .granted),
            applicationResolver: StubRunningApplicationResolver(application: application),
            windowServerFocuser: focuser
        )

        let result = await service.activate(
            window: makeWindow(
                id: 455,
                pid: 6055,
                appName: "Safari",
                title: "Selected Window",
                isMinimized: true
            )
        )

        #expect(result == .appOnly(title: "Selected Window"))
        #expect(focuser.requests.isEmpty)
    }

    private func makeWindow(
        id: UInt32,
        pid: Int32,
        appName: String,
        title: String,
        isMinimized: Bool = false
    ) -> WindowEntry {
        WindowEntry(
            id: CGWindowID(id),
            pid: pid,
            appName: appName,
            bundleIdentifier: nil,
            title: title,
            bounds: CGRect(x: 100, y: 100, width: 1200, height: 800),
            layer: 0,
            isMinimized: isMinimized,
            appIcon: nil,
            thumbnail: nil
        )
    }
}

@MainActor
private struct StubRunningApplicationResolver: RunningApplicationResolving {
    let application: (any RunningApplicationActivating)?

    func runningApplication(processIdentifier _: pid_t) -> (any RunningApplicationActivating)? {
        application
    }
}

@MainActor
private final class RecordingRunningApplication: RunningApplicationActivating {
    let processIdentifier: pid_t
    let bundleURL: URL?
    var directActivationOptions: [NSApplication.ActivationOptions] = []
    var currentApplicationActivationOptions: [NSApplication.ActivationOptions] = []
    var activationResult = true

    init(processIdentifier: pid_t, bundleURL: URL? = nil) {
        self.processIdentifier = processIdentifier
        self.bundleURL = bundleURL
    }

    func activate(options: NSApplication.ActivationOptions) -> Bool {
        directActivationOptions.append(options)
        return activationResult
    }

    func activateFromCurrentApplication(options: NSApplication.ActivationOptions) -> Bool {
        currentApplicationActivationOptions.append(options)
        return activationResult
    }
}

private actor RecordingApplicationOpener: ApplicationOpening {
    let result: Bool
    private(set) var openedBundleURLs: [URL] = []

    init(result: Bool) {
        self.result = result
    }

    func openApplication(at bundleURL: URL) async -> Bool {
        openedBundleURLs.append(bundleURL)
        return result
    }

    func openedBundleURLsSnapshot() -> [URL] {
        openedBundleURLs
    }
}

private struct WindowServerFocusRequest: Equatable {
    let processIdentifier: pid_t
    let windowID: CGWindowID
}

@MainActor
private final class RecordingWindowServerFocuser: WindowServerFocusing {
    private var results: [Bool]
    private(set) var requests: [WindowServerFocusRequest] = []

    init(result: Bool) {
        results = [result]
    }

    init(results: [Bool]) {
        self.results = results
    }

    func focusWindow(processIdentifier: pid_t, windowID: CGWindowID) -> Bool {
        requests.append(WindowServerFocusRequest(processIdentifier: processIdentifier, windowID: windowID))
        guard !results.isEmpty else {
            return false
        }

        return results.removeFirst()
    }
}
