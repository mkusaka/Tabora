import XCTest

final class TaboraKeyboardNavigationUITests: TaboraUITestCase {
    func testInitialPresentationSelectsTheNextCandidate() {
        page.launch(
            seeds: [
                makeSeed(id: 301, pid: 5001, appName: "Safari", title: "Frontmost"),
                makeSeed(id: 302, pid: 5002, appName: "Notes", title: "Expected Initial Selection"),
                makeSeed(id: 303, pid: 5003, appName: "Terminal", title: "Third"),
            ]
        )

        page.waitForOverlay()
        XCTAssertTrue(page.waitForSelectedWindow("Expected Initial Selection"))
    }

    func testTabCyclesForward() {
        page.launch(
            seeds: [
                makeSeed(id: 311, pid: 5011, appName: "Safari", title: "Frontmost"),
                makeSeed(id: 312, pid: 5012, appName: "Notes", title: "Second"),
                makeSeed(id: 313, pid: 5013, appName: "Terminal", title: "Third"),
            ]
        )

        page.waitForOverlay()
        page.pressTab()

        XCTAssertTrue(page.waitForSelectedWindow("Third"))
    }

    func testShiftTabCyclesBackward() {
        page.launch(
            seeds: [
                makeSeed(id: 321, pid: 5021, appName: "Safari", title: "Frontmost"),
                makeSeed(id: 322, pid: 5022, appName: "Notes", title: "Second"),
                makeSeed(id: 323, pid: 5023, appName: "Terminal", title: "Third"),
            ]
        )

        page.waitForOverlay()
        page.pressShiftTab()

        XCTAssertTrue(page.waitForSelectedWindow("Frontmost"))
    }

    func testEscapeCancelsOverlayWithoutActivation() {
        page.launch(
            seeds: [
                makeSeed(id: 331, pid: 5031, appName: "Safari", title: "Cancel Case"),
                makeSeed(id: 332, pid: 5032, appName: "Notes", title: "Second"),
            ]
        )

        page.waitForOverlay()
        page.pressEscape()
        page.waitForOverlayToDisappear()

        XCTAssertTrue(page.waitForActivationSummary(containing: "Cancelled"))
    }

    func testReturnConfirmsSelectionAndRecordsActivation() {
        page.launch(
            seeds: [
                makeSeed(id: 341, pid: 5041, appName: "Safari", title: "Frontmost"),
                makeSeed(id: 342, pid: 5042, appName: "Notes", title: "Selected On Launch"),
                makeSeed(id: 343, pid: 5043, appName: "Terminal", title: "Third"),
            ]
        )

        page.waitForOverlay()
        page.pressReturn()
        page.waitForOverlayToDisappear()

        XCTAssertTrue(page.waitForActivationSummary(containing: "Activated Selected On Launch"))
    }

    func testSelectedCardRemainsVisibleWhenThereAreManyWindows() {
        page.launch(
            seeds: [
                makeSeed(id: 351, pid: 5051, appName: "Safari", title: "Frontmost"),
                makeSeed(id: 352, pid: 5052, appName: "Notes", title: "Window 2"),
                makeSeed(id: 353, pid: 5053, appName: "Terminal", title: "Window 3"),
                makeSeed(id: 354, pid: 5054, appName: "Xcode", title: "Window 4"),
                makeSeed(id: 355, pid: 5055, appName: "Mail", title: "Window 5"),
                makeSeed(id: 356, pid: 5056, appName: "Preview", title: "Window 6"),
                makeSeed(id: 357, pid: 5057, appName: "Slack", title: "Window 7"),
                makeSeed(id: 358, pid: 5058, appName: "Music", title: "Window 8"),
            ]
        )

        page.waitForOverlay()
        page.pressTab()
        page.pressTab()
        page.pressTab()
        page.pressTab()
        page.pressTab()

        XCTAssertTrue(page.waitForSelectedWindow("Window 7"))
        XCTAssertTrue(page.waitForCardToBeHittable(357))
    }
}
