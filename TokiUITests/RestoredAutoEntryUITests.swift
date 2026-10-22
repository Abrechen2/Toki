import XCTest

/// After restoring a backup, automatic entries exist without the raw stays behind them.
/// Recomputing recent days at launch must not delete them.
final class RestoredAutoEntryUITests: XCTestCase {
    func testAutomaticEntryWithoutStaysSurvivesLaunch() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let yesterday = formatter.string(from: Date().addingTimeInterval(-86400))

        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launchEnvironment = ["TOKI_RESTORED_AUTO_DAY": yesterday, "TOKI_OFFICE": "48.0,11.0,150"]
        app.launch()

        XCTAssertTrue(app.staticTexts["08:00–16:30"].waitForExistence(timeout: 5),
                      "automatic entry from the backup was deleted at launch")
    }
}
