import XCTest

/// Target hours are set per weekday independently of the default times, like in myTime.
final class JobSettingsUITests: XCTestCase {
    func testChangeMondayTarget() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        app.tabBars.buttons["Mehr"].tap()
        app.buttons["editJob"].tap()
        app.buttons["defaultValues"].tap()

        let monday = app.steppers["target-2"]
        XCTAssertTrue(monday.waitForExistence(timeout: 5))
        monday.buttons.element(boundBy: 1).tap() // +15 min
        XCTAssertTrue(shows(app, "8h 15m"))
        XCTAssertTrue(app.staticTexts["Zeiten ergeben 8h 00m"].exists)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("default-values.png"))
        }

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["saveSettings"].tap()
        app.buttons["editJob"].tap()
        app.buttons["defaultValues"].tap()
        XCTAssertTrue(app.steppers["target-2"].waitForExistence(timeout: 5))
        XCTAssertTrue(shows(app, "8h 15m"))
    }

    private func shows(_ app: XCUIApplication, _ text: String) -> Bool {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text))
            .firstMatch.exists
    }
}
