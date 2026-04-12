import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let runtime = TaboraRuntime.shared

    func applicationDidFinishLaunching(_: Notification) {
        if !runtime.configuration.isUITesting {
            NSApp.setActivationPolicy(.accessory)
        }

        runtime.setup()
    }
}
