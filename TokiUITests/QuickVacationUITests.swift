import XCTest

/// End-to-end: book five workdays of vacation from the vacation tab on an empty in-memory store.
final class QuickVacationUITests: XCTestCase {
    func testBookFiveWorkdays() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        app.tabBars.buttons["Urlaub"].tap()
        app.buttons["quickVacation"].tap()
        app.buttons["Anzahl Tage"].tap()

        let book = app.buttons["bookVacation"]
        XCTAssertTrue(book.waitForExistence(timeout: 5))
        XCTAssertEqual(book.label, "5 Tage eintragen")
        snapshot(app, "quick-vacation")
        book.tap()

        XCTAssertTrue(app.staticTexts["Geplant"].waitForExistence(timeout: 5)
                      || app.staticTexts["GEPLANT"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["−5 d"].exists)
        snapshot(app, "vacation-account")

        // The month list shows the booked days.
        app.tabBars.buttons["Monat"].tap()
        XCTAssertTrue(app.staticTexts["Urlaub"].firstMatch.waitForExistence(timeout: 5))
        snapshot(app, "month")
    }

    /// Writes a PNG when SCREENSHOT_DIR is set (pass TEST_RUNNER_SCREENSHOT_DIR to xcodebuild).
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name + ".png"))
    }
}
