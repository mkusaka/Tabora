import SwiftUI

@main
@MainActor
struct TaboraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let runtime = TaboraRuntime.shared

    var body: some Scene {
        WindowGroup("Tabora") {
            RootHostView(
                configuration: runtime.configuration,
                state: runtime.state
            ) {
                runtime.presentSwitcher(initialAdvance: false)
            }
        }
        .defaultSize(width: 480, height: 240)
        .windowResizability(.contentSize)
    }
}
