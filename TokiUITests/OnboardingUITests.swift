import XCTest

/// First launch: the assistant sets the schedule; a quick workday then uses the new times.
final class OnboardingUITests: XCTestCase {
    func testAssistantSetsScheduleForNewUsers() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-onboarding", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Willkommen bei Toki"].waitForExistence(timeout: 5), "assistant not shown on first launch")
        let done = app.buttons["onboardingDone"]
        for _ in 0..<4 where !done.isHittable { app.swipeUp() }
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("onboarding.png"))
        }
        done.tap()
        XCTAssertFalse(done.waitForExistence(timeout: 2), "assistant did not close")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        app.buttons["day-\(formatter.string(from: Date()))"].tap()
        app.buttons["quickWorkday"].tap()
        XCTAssertTrue(app.staticTexts["08:00–16:30"].waitForExistence(timeout: 5),
                      "default 8 h from 08:00 with the legal 30 min break")
    }

    func testAssistantIsNotShownOnceThereIsData() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        XCTAssertFalse(app.buttons["onboardingDone"].waitForExistence(timeout: 3))
    }
}
