import XCTest

final class TaboraOverlayUITests: TaboraUITestCase {
    func testOverlayShowsSeededWindowMetadata() {
        page.launch(
            seeds: [
                makeSeed(id: 201, pid: 4001, appName: "Safari", title: "Roadmap"),
                makeSeed(id: 202, pid: 4002, appName: "Notes", title: "Switcher Spec"),
                makeSeed(id: 203, pid: 4003, appName: "Terminal", title: "Build Logs"),
            ]
        )

        page.waitForOverlay()
        let snapshots = page.waitForSnapshot()

        XCTAssertTrue(page.card(201).exists)
        XCTAssertTrue(page.card(202).exists)
        XCTAssertTrue(page.card(203).exists)
        XCTAssertEqual(snapshots?.first(where: { $0.id == 202 })?.title, "Switcher Spec")
        XCTAssertEqual(snapshots?.first(where: { $0.id == 202 })?.appName, "Notes")
    }

    func testMissingThumbnailShowsPlaceholderWithoutDroppingText() {
        page.launch(
            seeds: [
                makeSeed(id: 211, pid: 4011, appName: "Safari", title: "Thumbnail OK"),
                makeSeed(id: 212, pid: 4012, appName: "Notes", title: "Needs Placeholder", thumbnailMode: "missing"),
            ]
        )

        page.waitForOverlay()
        let snapshots = page.waitForSnapshot()

        XCTAssertEqual(snapshots?.first(where: { $0.id == 212 })?.title, "Needs Placeholder")
        XCTAssertEqual(snapshots?.first(where: { $0.id == 212 })?.appName, "Notes")
        XCTAssertEqual(snapshots?.first(where: { $0.id == 212 })?.hasThumbnail, false)
    }

    func testUntitledWindowStillShowsAppNameFallback() {
        page.launch(
            seeds: [
                makeSeed(id: 221, pid: 4021, appName: "Terminal", title: "", thumbnailMode: "missing"),
            ]
        )

        page.waitForOverlay()
        let snapshots = page.waitForSnapshot()

        XCTAssertEqual(snapshots?.first(where: { $0.id == 221 })?.title, "Terminal")
        XCTAssertEqual(snapshots?.first(where: { $0.id == 221 })?.appName, "Terminal")
    }

    func testPermissionBannerAppearsWhenPermissionsAreMissing() {
        page.launch(
            seeds: [
                makeSeed(id: 231, pid: 4031, appName: "Safari", title: "Permission Case"),
            ],
            screenPermission: "missing",
            accessibilityPermission: "missing"
        )

        page.waitForOverlay()

        XCTAssertTrue(
            page.waitForPermissionMessage(containing: "Screen Recording permission is missing")
        )
    }
}
