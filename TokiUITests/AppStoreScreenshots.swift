import XCTest

/// App Store screenshots with made-up demo data. Runs only with TEST_RUNNER_SCREENSHOT_DIR set;
/// use a 6.9" simulator (iPhone 17 Pro Max, 1320×2868) and a fixed status bar.
final class AppStoreScreenshots: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        let path = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"]
        try XCTSkipUnless(path != nil && ProcessInfo.processInfo.environment["STORE_SCREENSHOTS"] == "1")
        dir = URL(fileURLWithPath: path!)
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        sleep(1)
        try? app.screenshot().pngRepresentation.write(to: dir.appendingPathComponent(name + ".png"))
    }

    func testStoreScreenshots() {
        let app = XCUIApplication()
        let language = ProcessInfo.processInfo.environment["STORE_LANGUAGE"] ?? "de"
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(\(language))",
                               "-AppleLocale", language == "de" ? "de_DE" : "en_US"]
        app.launchEnvironment = ["TOKI_DEMO": "1"]
        app.launch()
        let tabs = app.tabBars.buttons
        let cancel = app.buttons[language == "de" ? "Abbrechen" : "Cancel"].firstMatch

        // The list starts centred on today, so tomorrow is visible: quick entry first.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let tomorrow = app.buttons["day-\(formatter.string(from: Date().addingTimeInterval(86400)))"]
        if tomorrow.waitForExistence(timeout: 3) {
            tomorrow.tap()
            XCTAssertTrue(app.buttons["quickWorkday"].waitForExistence(timeout: 5))
            shot(app, "2-quick-entry")
            cancel.tap()
        }

        app.swipeDown() // show more of the filled past days around today
        shot(app, "1-month")

        tabs.element(boundBy: 1).tap()
        shot(app, "3-vacation")

        app.buttons["quickVacation"].tap()
        XCTAssertTrue(app.buttons["bookVacation"].waitForExistence(timeout: 5))
        app.buttons[language == "de" ? "Anzahl Tage" : "Number of days"].tap()
        shot(app, "4-quick-vacation")
        cancel.tap()

        tabs.element(boundBy: 2).tap()
        shot(app, "5-overview")

        tabs.element(boundBy: 4).tap()
        app.buttons["officeSettings"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["officeMap"].waitForExistence(timeout: 10))
        sleep(3) // map tiles
        shot(app, "6-location")
    }
}
