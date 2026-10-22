import XCTest

/// Tap a day, tap "Arbeitstag": the day shows the default times 08:30–16:30.
final class QuickWorkdayUITests: XCTestCase {
    func testOneTapWorkday() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = app.buttons["day-\(formatter.string(from: Date()))"]
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        today.tap()

        let quick = app.buttons["quickWorkday"]
        XCTAssertTrue(quick.waitForExistence(timeout: 5))
        quick.tap()

        XCTAssertTrue(app.staticTexts["08:30–16:30"].waitForExistence(timeout: 5))
        XCTAssertFalse(quick.exists)
    }

    func testAdjustBreakBeforeBooking() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        app.buttons["day-\(formatter.string(from: Date()))"].tap()

        app.buttons["quickBreak"].tap()
        app.buttons["0h 30m"].tap()
        let quick = app.buttons["quickWorkday"]
        XCTAssertTrue(quick.label.contains("7h 30m"), quick.label)
        snapshot(app, "quick-workday")
        quick.tap()

        XCTAssertTrue(app.staticTexts["Pause 0h 30m"].waitForExistence(timeout: 5))
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name + ".png"))
    }
}
