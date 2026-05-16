import AppKit
@testable import Tabora
import Testing

@MainActor
struct WorkspaceOpenerIntegrationTests {
    @Test func workspaceApplicationOpenerMakesAlreadyRunningApplicationFrontmost() async throws {
        let textEditBundleID = "com.apple.TextEdit"
        let finderBundleID = "com.apple.finder"
        let textEditURL = try #require(NSWorkspace.shared.urlForApplication(withBundleIdentifier: textEditBundleID))
        let finderURL = try #require(NSWorkspace.shared.urlForApplication(withBundleIdentifier: finderBundleID))
        let wasTextEditRunning = NSRunningApplication.runningApplications(withBundleIdentifier: textEditBundleID)
            .isEmpty == false
        let opener = WorkspaceApplicationOpener()

        defer {
            if !wasTextEditRunning {
                NSRunningApplication.runningApplications(withBundleIdentifier: textEditBundleID)
                    .forEach { $0.terminate() }
            }
        }

        #expect(await opener.openApplication(at: textEditURL))
        #expect(await waitForRunningApplication(bundleIdentifier: textEditBundleID) != nil)
        #expect(await opener.openApplication(at: finderURL))
        #expect(await waitForFrontmostApplication(bundleIdentifier: finderBundleID))

        #expect(await opener.openApplication(at: textEditURL))
        #expect(await waitForFrontmostApplication(bundleIdentifier: textEditBundleID))
    }

    private func waitForRunningApplication(bundleIdentifier: String) async -> NSRunningApplication? {
        for _ in 0 ..< 20 {
            let application = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
            if let application {
                return application
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        return nil
    }

    private func waitForFrontmostApplication(bundleIdentifier: String) async -> Bool {
        for _ in 0 ..< 20 {
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleIdentifier {
                return true
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        return false
    }
}
