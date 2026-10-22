import XCTest

/// Separate time (e.g. work in Switzerland paid on its own): labelled, outside the overtime account,
/// exported per category with its total.
final class CategoryUITests: XCTestCase {
    func testSeparateCategoryEndToEnd() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] { app.launchEnvironment = ["TOKI_EXPORT_DIR": dir] }
        app.launch()

        // 1. Category "Schweiz", separate from normal work time (the default).
        app.tabBars.buttons["Mehr"].tap()
        app.buttons["categories"].tap()
        app.buttons["addCategory"].tap()
        let name = app.textFields["categoryName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Schweiz")
        XCTAssertEqual(app.switches["categoryCounts"].value as? String, "0")
        app.buttons["saveCategory"].tap()

        // 2. Today: quick workday 08:00–16:30 in "Schweiz".
        app.tabBars.buttons["Monat"].tap()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        app.buttons["day-\(formatter.string(from: Date()))"].tap()
        app.buttons["entryCategory"].tap()
        app.buttons["Schweiz"].tap()
        app.buttons["quickWorkday"].tap()

        // 3. Labelled, counted apart, overtime account untouched.
        XCTAssertTrue(app.staticTexts["Schweiz"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["8h 00m getrennt"].exists)
        let account = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '0h 00m'")).firstMatch
        XCTAssertTrue(account.exists, "overtime account must stay at 0h 00m")
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("category-month.png"))
        }

        // 4. Export of the category with its total.
        app.tabBars.buttons["Export"].tap()
        app.buttons["exportCategory"].tap()
        app.buttons["Schweiz"].tap()
        let total = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '8h 00m'")).firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        app.buttons["exportPDF"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["shareExport"].waitForExistence(timeout: 5))
    }
}
