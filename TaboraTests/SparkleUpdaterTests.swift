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

    private func expectedSparkleBuildVersion(for marketingVersion: String) -> String? {
        let components = marketingVersion.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count <= 3 else {
            return nil
        }

        let normalized = components + Array(repeating: Substring("0"), count: max(0, 3 - components.count))
        guard
            let major = Int(normalized[0]),
            let minor = Int(normalized[1]),
            let patch = Int(normalized[2])
        else {
            return nil
        }

        let buildVersion = major * 10_000 + minor * 100 + patch
        return String(buildVersion)
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

    @Test func bundleVersionMatchesSparkleBuildVersionScheme() {
        let bundle = appBundle()
        let marketingVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        #expect(marketingVersion != nil)
        #expect(buildVersion != nil)
        #expect(expectedSparkleBuildVersion(for: marketingVersion ?? "") == buildVersion)
    }

    @Test func buildInfoContainsVersionAndCommitHash() {
        #expect(!BuildInfo.version.isEmpty)
        #expect(!BuildInfo.gitCommitHash.isEmpty)
        #expect(BuildInfo.gitCommitHash != "unknown")
        #expect(BuildInfo.gitCommitHashFull != "unknown")
        #expect(BuildInfo.gitCommitHashFull.count >= BuildInfo.gitCommitHash.count)
    }
}
