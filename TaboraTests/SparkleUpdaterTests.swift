import Foundation
@testable import Tabora
import Testing

private struct MockLoginItemManager: LoginItemManaging {
    func currentStatus() -> LoginItemStatus {
        .disabled
    }

    func setEnabled(_: Bool) -> LoginItemStatus {
        .disabled
    }
}

struct SparkleUpdaterTests {
    private func appBundle() -> Bundle {
        if Bundle.main.bundleIdentifier == "com.mkusaka.Tabora" {
            return Bundle.main
        }

        return Bundle.allBundles.first(where: { $0.bundleIdentifier == "com.mkusaka.Tabora" }) ?? Bundle.main
    }

    @MainActor
    @Test func menuContainsCheckForUpdatesItem() {
        let controller = MenuBarController(
            runtime: .shared,
            loginItemManager: MockLoginItemManager(),
            appUpdater: AppUpdaterController()
        )

        let titles = controller.statusItem?.menu?.items.map(\.title) ?? []
        #expect(titles.contains("Check for Updates…"))
        #expect(titles.contains("About Tabora"))
    }

    @Test func infoPlistContainsFeedURL() {
        let feedURL = appBundle().object(forInfoDictionaryKey: "SUFeedURL") as? String
        #expect(feedURL == "https://mkusaka.github.io/Tabora/appcast.xml")
    }

    @Test func infoPlistContainsPublicEDKey() {
        let publicKey = appBundle().object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        #expect(publicKey != nil && !(publicKey?.isEmpty ?? true))
    }

    @Test func buildInfoContainsVersionAndCommitHash() {
        #expect(!BuildInfo.version.isEmpty)
        #expect(!BuildInfo.gitCommitHash.isEmpty)
        #expect(BuildInfo.gitCommitHash != "unknown")
        #expect(BuildInfo.gitCommitHashFull != "unknown")
        #expect(BuildInfo.gitCommitHashFull.count >= BuildInfo.gitCommitHash.count)
    }
}
