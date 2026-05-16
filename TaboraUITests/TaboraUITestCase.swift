import XCTest

@MainActor
class TaboraUITestCase: XCTestCase {
    let app = XCUIApplication()
    lazy var page = TaboraPage(app: app)

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        if app.state != .notRunning {
            app.terminate()
        }
    }

    func makeSeed(
        id: UInt32,
        pid: Int32,
        appName: String,
        title: String,
        thumbnailMode: String = "success"
    ) -> TaboraPage.Seed {
        TaboraPage.Seed(
            id: id,
            pid: pid,
            appName: appName,
            bundleIdentifier: "com.example.\(appName.lowercased())",
            title: title,
            x: 100,
            y: 100,
            width: 1440,
            height: 900,
            layer: 0,
            thumbnailMode: thumbnailMode
        )
    }
}
