import XCTest

/// Automatic entries by location, with visits injected through the DEBUG hook TOKI_FAKE_VISITS.
final class LocationEntryUITests: XCTestCase {
    private let today: String = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }()

    private func launch(visits: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launchEnvironment = ["TOKI_FAKE_VISITS": visits]
        app.launch()
        return app
    }

    private func shows(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func testFirstArrivalLastDepartureRoundedAndShortVisitIgnored() {
        let app = launch(visits: "\(today) 08:31>\(today) 16:42|\(today) 18:00>\(today) 18:20")
        XCTAssertTrue(app.staticTexts["08:30–16:40"].waitForExistence(timeout: 5))
    }

    func testRunningDay() {
        let app = launch(visits: "\(today) 08:31")
        XCTAssertTrue(shows(app, "läuft seit 08:30").waitForExistence(timeout: 5))
    }

    func testUncertainDayCanBeConfirmed() {
        let app = launch(visits: "\(today) 04:10>\(today) 18:00")
        XCTAssertTrue(shows(app, "ungewöhnliche Uhrzeit").waitForExistence(timeout: 5))
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("uncertain.png"))
        }

        app.buttons["day-\(today)"].tap()
        app.buttons["confirmEntry"].tap()
        app.buttons["Sichern"].tap()
        XCTAssertTrue(app.staticTexts["04:10–18:00"].waitForExistence(timeout: 5))
        XCTAssertFalse(shows(app, "Unsicher").exists)
    }
}
