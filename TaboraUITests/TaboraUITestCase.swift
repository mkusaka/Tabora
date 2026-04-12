import XCTest

class TaboraUITestCase: XCTestCase {
    var app: XCUIApplication!
    var page: TaboraPage!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        page = TaboraPage(app: app)
    }

    override func tearDown() {
        if let app, app.state != .notRunning {
            app.terminate()
        }
        app = nil
        page = nil
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
