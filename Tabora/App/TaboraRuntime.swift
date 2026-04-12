import AppKit
import SwiftUI

struct TaboraConfiguration {
    let isUITesting: Bool
    let autoPresentOnLaunch: Bool
    let screenCaptureOverride: PermissionAccessState?
    let accessibilityOverride: PermissionAccessState?
    let resultFilePath: String?
    let selectionFilePath: String?
    let snapshotFilePath: String?
    let permissionFilePath: String?
    let commandFilePath: String?
    let seededWindows: [UITestWindowSeed]
    let activationMode: UITestWindowActivationService.Mode

    init(processInfo: ProcessInfo = .processInfo) {
        let arguments = Set(processInfo.arguments)
        let environment = processInfo.environment

        isUITesting = arguments.contains("-uiTesting")
        autoPresentOnLaunch = environment["UITEST_AUTOPRESENT"] == "1"
        screenCaptureOverride = Self.parsePermission(environment["UITEST_SCREEN_PERMISSION"])
        accessibilityOverride = Self.parsePermission(environment["UITEST_ACCESSIBILITY_PERMISSION"])
        resultFilePath = environment["UITEST_RESULT_FILE"]
        selectionFilePath = environment["UITEST_SELECTION_FILE"]
        snapshotFilePath = environment["UITEST_SNAPSHOT_FILE"]
        permissionFilePath = environment["UITEST_PERMISSION_FILE"]
        commandFilePath = environment[UITestCommandBridge.commandFileEnvironmentKey]
        seededWindows = UITestWindowSeed.decodeEnvironmentJSON(environment["UITEST_WINDOWS_JSON"])
        activationMode =
            UITestWindowActivationService.Mode(rawValue: environment["UITEST_ACTIVATION_MODE"] ?? "")
                ?? .success
    }

    private static func parsePermission(_ rawValue: String?) -> PermissionAccessState? {
        guard let rawValue else {
            return nil
        }

        return PermissionAccessState(rawValue: rawValue)
    }
}

@MainActor
final class TaboraRuntime {
    private struct RuntimeServices {
        let permissionService: any PermissionProviding
        let windowCatalog: any WindowCataloging
        let thumbnailService: any ThumbnailProviding
        let activationService: any WindowActivating
        let activationRecorder: UITestActivationRecorder?
    }

    static let shared = TaboraRuntime()

    let configuration: TaboraConfiguration
    let state: SwitcherState

    private let overlayWindowController: OverlayWindowController
    private let hotkeyManager: HotkeyManager
    private var uiTestCommandTimer: Timer?

    private init(configuration: TaboraConfiguration = TaboraConfiguration()) {
        self.configuration = configuration

        let services = Self.makeServices(configuration: configuration)
        state = SwitcherState(
            windowCatalog: services.windowCatalog,
            thumbnailService: services.thumbnailService,
            activationService: services.activationService,
            permissionService: services.permissionService
        )
        let switcherState = state

        overlayWindowController = Self.makeOverlayWindowController(state: switcherState)
        hotkeyManager = Self.makeHotkeyManager(state: switcherState)
        bindStateCallbacks(
            activationRecorder: services.activationRecorder,
            configuration: configuration
        )
    }

    func setup() {
        hotkeyManager.start()
        installUITestCommandTimerIfNeeded()
        _ = refreshPermissionStatus(reason: "app launch")

        if configuration.autoPresentOnLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.presentSwitcher(initialAdvance: true)
            }
        }
    }

    func presentSwitcher(initialAdvance: Bool) {
        TaboraLogger.log("switcher", "Present requested initialAdvance=\(initialAdvance)")
        state.present(initialAdvance: initialAdvance)
    }

    @discardableResult
    func refreshPermissionStatus(reason: String) -> PermissionStatus {
        let status = state.refreshPermissionStatus()
        TaboraLogger.log("permission", "Refresh reason=\(reason) \(status.logSummary)")
        return status
    }

    private func installUITestCommandTimerIfNeeded() {
        guard
            configuration.isUITesting,
            uiTestCommandTimer == nil,
            let commandFilePath = configuration.commandFilePath
        else {
            return
        }

        let commandFileURL = URL(fileURLWithPath: commandFilePath)
        uiTestCommandTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard
                let self,
                let rawValue = try? String(contentsOf: commandFileURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
                let command = UITestCommand(rawValue: rawValue),
                !rawValue.isEmpty
            else {
                return
            }

            try? FileManager.default.removeItem(at: commandFileURL)
            Task { @MainActor [weak self] in
                self?.handleUITestCommand(command)
            }
        }
    }

    private func handleUITestCommand(_ command: UITestCommand) {
        switch command {
        case .cycleForward:
            state.moveSelection(forward: true)
        case .cycleBackward:
            state.moveSelection(forward: false)
        case .cancel:
            state.cancel()
        case .confirm:
            state.confirmSelection()
        }
    }

    private static func makeServices(configuration: TaboraConfiguration) -> RuntimeServices {
        if configuration.isUITesting {
            let recorder = UITestActivationRecorder(
                summaryFileURL: configuration.resultFilePath.map(URL.init(fileURLWithPath:))
            )
            return RuntimeServices(
                permissionService: UITestPermissionService(
                    screenCapture: configuration.screenCaptureOverride ?? .granted,
                    accessibility: configuration.accessibilityOverride ?? .granted
                ),
                windowCatalog: UITestWindowCatalogService(seeds: configuration.seededWindows),
                thumbnailService: UITestThumbnailService(seeds: configuration.seededWindows),
                activationService: UITestWindowActivationService(
                    mode: configuration.activationMode,
                    recorder: recorder
                ),
                activationRecorder: recorder
            )
        }

        let livePermissionService = PermissionService()
        return RuntimeServices(
            permissionService: livePermissionService,
            windowCatalog: WindowCatalogService(),
            thumbnailService: ThumbnailService(),
            activationService: WindowActivationService(permissionService: livePermissionService),
            activationRecorder: nil
        )
    }

    private static func makeOverlayWindowController(state: SwitcherState) -> OverlayWindowController {
        OverlayWindowController(
            state: state,
            onCycle: { forward in
                state.moveSelection(forward: forward)
            },
            onCancel: {
                state.cancel()
            },
            onConfirm: {
                state.confirmSelection()
            },
            onModifierFlagsChanged: { flags in
                guard flags.contains(.option) == false else {
                    return
                }
                state.confirmSelection()
            }
        )
    }

    private static func makeHotkeyManager(state: SwitcherState) -> HotkeyManager {
        HotkeyManager {
            if state.isVisible {
                state.moveSelection(forward: true)
            } else {
                state.present(initialAdvance: true)
            }
        }
    }

    private func bindStateCallbacks(
        activationRecorder: UITestActivationRecorder?,
        configuration: TaboraConfiguration
    ) {
        state.onVisibilityChanged = { [weak self] isVisible in
            self?.overlayWindowController.setVisible(isVisible)
        }

        state.onActivationSummaryChanged = { summary in
            activationRecorder?.record(summary: summary)
        }
        state.onPermissionStatusChanged = { status in
            guard let path = configuration.permissionFilePath else {
                return
            }
            let url = URL(fileURLWithPath: path)
            try? (status.overlayMessage ?? "").write(to: url, atomically: true, encoding: .utf8)
        }
        state.onSelectionChanged = { entry in
            guard let path = configuration.selectionFilePath else {
                return
            }
            let url = URL(fileURLWithPath: path)
            try? (entry?.displayTitle ?? "").write(to: url, atomically: true, encoding: .utf8)
        }
        state.onEntriesChanged = { entries in
            guard let path = configuration.snapshotFilePath else {
                return
            }
            let url = URL(fileURLWithPath: path)
            let snapshots = entries.map(UITestWindowSnapshot.init(entry:))
            guard let data = try? JSONEncoder().encode(snapshots) else {
                return
            }
            try? data.write(to: url, options: .atomic)
        }
    }
}
