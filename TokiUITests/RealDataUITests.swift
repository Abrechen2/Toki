import XCTest

/// Walkthrough against a real backup file and the persistent store, like on a phone after a
/// restore. Runs only when TOKI_SNAPSHOT names a backup on the host; the file never enters the repo.
/// Screenshots go to SCREENSHOT_DIR when set.
final class RealDataUITests: XCTestCase {
    private var snapshotPath = ""

    override func setUpWithError() throws {
        snapshotPath = ProcessInfo.processInfo.environment["TOKI_SNAPSHOT"] ?? ""
        try XCTSkipIf(snapshotPath.isEmpty, "needs TOKI_SNAPSHOT")
        continueAfterFailure = false
    }

    func testQuickEntriesSurviveARelaunch() {
        let workday = nextWeekday()
        var app = launch(restoring: true)
        open(workday, in: app)
        shot(app, "1-quick-section")
        let quick = app.buttons["quickWorkday"]
        XCTAssertTrue(quick.waitForExistence(timeout: 5), "no quick section on an empty workday")
        quick.tap()
        XCTAssertTrue(app.buttons["day-\(iso(workday))"].waitForExistence(timeout: 5))
        shot(app, "2-month-after-quick")

        // The day shows the schedule target, not a target left over from the backup.
        app.buttons["day-\(iso(workday))"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        shot(app, "3-day-after-quick")
        XCTAssertFalse(app.buttons["quickWorkday"].exists, "quick entry was not stored")
        app.buttons["Abbrechen"].tap()

        // Quick vacation day on the following weekday.
        let vacationDay = nextWeekday(after: workday)
        open(vacationDay, in: app)
        app.buttons["quick-vacation"].tap()
        XCTAssertTrue(app.buttons["day-\(iso(vacationDay))"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["day-\(iso(vacationDay))"].label.contains("Urlaub"), "vacation day not booked")

        app.terminate()
        app = launch(restoring: false)
        open(workday, in: app)
        XCTAssertFalse(app.buttons["quickWorkday"].waitForExistence(timeout: 3), "quick entry lost after relaunch")
        shot(app, "4-day-after-relaunch")
        app.buttons["Abbrechen"].tap()
        XCTAssertTrue(app.buttons["day-\(iso(vacationDay))"].label.contains("Urlaub"), "vacation day lost after relaunch")

        // Every tab renders with the real data.
        for tab in ["Urlaub", "Übersicht", "Export", "Mehr"] {
            app.tabBars.buttons[tab].tap()
            sleep(1)
            shot(app, "5-tab-\(tab)")
        }
        app.buttons["editJob"].tap()
        app.buttons["defaultValues"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["weeklyTarget"].waitForExistence(timeout: 5))
        shot(app, "6-default-values")

        // Changed default values survive leaving without "Sichern" and a relaunch.
        app.steppers["target-2"].buttons.element(boundBy: 1).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.terminate()
        app = launch(restoring: false)
        app.tabBars.buttons["Mehr"].tap()
        app.buttons["editJob"].tap()
        app.buttons["defaultValues"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["weeklyTarget"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["weeklyTarget"].label.contains("39h 15m")
                      || shows(app, "39h 15m"), "default values lost without Sichern")
    }

    // MARK: Helpers

    private func launch(restoring: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        if restoring { app.launchEnvironment = ["TOKI_SNAPSHOT": snapshotPath] }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Monat"].waitForExistence(timeout: 10))
        return app
    }

    /// Scrolls the month list to the day and opens it.
    private func open(_ date: Date, in app: XCUIApplication) {
        app.tabBars.buttons["Monat"].tap()
        let row = app.buttons["day-\(iso(date))"]
        for _ in 0..<12 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.isHittable, "row \(iso(date)) not reachable")
        row.tap()
    }

    /// Next Monday–Thursday from tomorrow on, inside the current month when possible.
    private func nextWeekday(after date: Date = Date()) -> Date {
        var day = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        while !(2...5).contains(Calendar.current.component(.weekday, from: day)) {
            day = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        }
        return day
    }

    private func iso(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func shows(_ app: XCUIApplication, _ text: String) -> Bool {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
            .waitForExistence(timeout: 3)
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name + ".png"))
    }
}
