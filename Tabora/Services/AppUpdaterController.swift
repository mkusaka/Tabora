import AppKit
import Sparkle

@MainActor
final class AppUpdaterController: NSObject {
    private(set) var updaterController: SPUStandardUpdaterController

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    func start() {
        guard updaterController.updater.canCheckForUpdates == false else {
            TaboraLogger.log("sparkle", "Updater already started")
            return
        }

        do {
            try updaterController.updater.start()
            TaboraLogger.log("sparkle", "Updater started")
        } catch {
            TaboraLogger.log("sparkle", "Failed to start updater: \(error.localizedDescription)")
        }
    }

    @objc
    func checkForUpdates(_ sender: Any?) {
        TaboraLogger.log("sparkle", "Manual update check requested")
        updaterController.checkForUpdates(sender)
    }
}
