import XCTest

/// Office setup as reported from TestFlight: location access not yet granted, then address search.
/// The host sets the simulated location before running (see README).
final class OfficeSetupUITests: XCTestCase {
    private func openOfficeSettings(visits: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        if let visits { app.launchEnvironment = ["TOKI_FAKE_VISITS": visits] }
        app.launch()
        app.tabBars.buttons["Mehr"].tap()
        app.buttons["officeSettings"].tap()
        return app
    }

    /// Answers the system prompts for location and notifications (German or English simulator).
    private func allowLocationPrompt() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons.matching(NSPredicate(format:
            "label CONTAINS[c] 'Beim Verwenden' OR label CONTAINS[c] 'While Using' OR label ==[c] 'Erlauben' OR label ==[c] 'Allow'"))
            .firstMatch
        var deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if allow.exists {
                allow.tap()
                deadline = Date().addingTimeInterval(3) // a second prompt may follow
            }
            usleep(300_000)
        }
    }

    func testCurrentLocationAfterFirstPermissionPrompt() {
        let app = openOfficeSettings()
        app.switches["officeEnabled"].switches.firstMatch.tap()
        allowLocationPrompt()

        XCTAssertTrue(app.descendants(matching: .any)["officeMap"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["saveOffice"].isEnabled)
        let error = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'kCLErrorDomain' OR label CONTAINS 'Kein Zugriff'")).firstMatch
        XCTAssertFalse(error.exists)
    }

    func testAddressSearchShowsSuggestions() {
        let app = openOfficeSettings()
        app.switches["officeEnabled"].switches.firstMatch.tap()
        allowLocationPrompt()

        let field = app.textFields["addressSearch"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Marienplatz München")
        let suggestion = app.buttons["addressSuggestion"].firstMatch
        XCTAssertTrue(suggestion.waitForExistence(timeout: 15), "no suggestions while typing")
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("address-search.png"))
        }
        suggestion.tap()
        XCTAssertTrue(app.descendants(matching: .any)["officeMap"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["saveOffice"].isEnabled)
    }

    func testSavedOfficeIsStillThereAfterReopening() {
        let app = openOfficeSettings()
        app.switches["officeEnabled"].switches.firstMatch.tap()
        allowLocationPrompt()
        XCTAssertTrue(app.descendants(matching: .any)["officeMap"].waitForExistence(timeout: 15))
        app.buttons["saveOffice"].tap()
        let row = app.buttons["officeSettings"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertEqual(app.switches["officeEnabled"].value as? String, "1", "office not saved")
        XCTAssertTrue(app.descendants(matching: .any)["officeMap"].waitForExistence(timeout: 5))
    }

    /// Saving confirms visibly, closes the page, shows the office under "Mehr", and drops the
    /// still open stay that belonged to the previous place.
    func testSaveConfirmsAndDropsOpenStayAtOldPlace() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let app = openOfficeSettings(visits: "\(today) 08:31")

        app.switches["officeEnabled"].switches.firstMatch.tap()
        allowLocationPrompt()
        let map = app.descendants(matching: .any)["officeMap"].waitForExistence(timeout: 15)
        if !map, let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("no-map.png"))
        }
        XCTAssertTrue(map)
        app.buttons["saveOffice"].tap()

        let confirmation = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3), "no visual confirmation")
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("saved.png"))
        }
        let status = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'An · '")).firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 5), "page did not close or status missing")

        app.tabBars.buttons["Monat"].tap()
        let running = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'läuft seit 08:30'")).firstMatch
        XCTAssertFalse(running.waitForExistence(timeout: 3), "open stay at the old place is still listed")
    }
}
