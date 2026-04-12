import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let runtime: TaboraRuntime
    private let loginItemManager: any LoginItemManaging
    private let appUpdater: AppUpdaterController
    private(set) var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private let startAtLoginItem = NSMenuItem(title: "Start at Login", action: nil, keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(title: "Accessibility: Unknown", action: nil, keyEquivalent: "")
    private let screenCaptureItem = NSMenuItem(title: "Screen Recording: Unknown", action: nil, keyEquivalent: "")

    init(
        runtime: TaboraRuntime,
        loginItemManager: any LoginItemManaging,
        appUpdater: AppUpdaterController
    ) {
        self.runtime = runtime
        self.loginItemManager = loginItemManager
        self.appUpdater = appUpdater
        super.init()
        configureStatusItem()
        configureMenu()
        refreshMenuState(reason: "menu bar initialized")
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.title = ""
            button.image = menuBarIcon()
            button.imagePosition = .imageOnly
            button.toolTip = "Tabora"
        }
        self.statusItem = statusItem
    }

    private func menuBarIcon() -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = NSImage(
            systemSymbolName: "macwindow.on.rectangle",
            accessibilityDescription: "Tabora"
        )?.withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }

    private func configureMenu() {
        menu.delegate = self

        let aboutItem = NSMenuItem(
            title: "About Tabora",
            action: #selector(showAboutPanel),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let showSwitcherItem = NSMenuItem(
            title: "Show Switcher",
            action: #selector(showSwitcher),
            keyEquivalent: ""
        )
        showSwitcherItem.target = self
        menu.addItem(showSwitcherItem)

        let refreshPermissionsItem = NSMenuItem(
            title: "Refresh Permission Status",
            action: #selector(refreshPermissionStatus),
            keyEquivalent: ""
        )
        refreshPermissionsItem.target = self
        menu.addItem(refreshPermissionsItem)

        startAtLoginItem.action = #selector(toggleStartAtLogin)
        startAtLoginItem.target = self
        menu.addItem(startAtLoginItem)

        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(AppUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = appUpdater
        menu.addItem(checkForUpdatesItem)

        menu.addItem(.separator())

        accessibilityItem.isEnabled = false
        menu.addItem(accessibilityItem)

        screenCaptureItem.isEnabled = false
        menu.addItem(screenCaptureItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Tabora",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    func menuNeedsUpdate(_: NSMenu) {
        refreshMenuState(reason: "menu opened")
    }

    @objc
    private func showSwitcher() {
        TaboraLogger.log("menu", "Show Switcher selected")
        runtime.presentSwitcher(initialAdvance: false)
    }

    @objc
    private func refreshPermissionStatus() {
        refreshMenuState(reason: "manual refresh")
    }

    @objc
    private func toggleStartAtLogin() {
        let currentStatus = loginItemManager.currentStatus()
        let updatedStatus = loginItemManager.setEnabled(!currentStatus.isEnabled)
        TaboraLogger.log("menu", "Start at Login toggled to \(updatedStatus.menuDescription)")
        refreshMenuState(reason: "start at login toggled")
    }

    @objc
    private func quitApp() {
        TaboraLogger.log("menu", "Quit selected")
        NSApp.terminate(nil)
    }

    @objc
    private func showAboutPanel() {
        TaboraLogger.log("menu", "About selected")
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationVersion: "\(BuildInfo.version) (\(BuildInfo.gitCommitHash))",
            .version: "",
        ])
    }

    private func refreshMenuState(reason: String) {
        let status = runtime.refreshPermissionStatus(reason: reason)
        let loginItemStatus = loginItemManager.currentStatus()
        startAtLoginItem.state = loginItemStatus.menuState
        startAtLoginItem.isEnabled = loginItemStatus.canToggle
        startAtLoginItem.title = "Start at Login: \(loginItemStatus.menuDescription)"
        accessibilityItem.title = "Accessibility: \(status.accessibility.menuLabel)"
        screenCaptureItem.title = "Screen Recording: \(status.screenCapture.menuLabel)"
    }
}
