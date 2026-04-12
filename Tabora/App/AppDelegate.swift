import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let runtime = TaboraRuntime.shared
    private var menuBarController: MenuBarController?
    private let loginItemManager = LoginItemService()

    func applicationDidFinishLaunching(_: Notification) {
        if !runtime.configuration.isUITesting {
            NSApp.setActivationPolicy(.accessory)
        }

        runtime.setup()

        if !runtime.configuration.isUITesting {
            menuBarController = MenuBarController(runtime: runtime, loginItemManager: loginItemManager)
        }
    }
}
