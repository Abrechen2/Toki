import XCTest

/// A correction of the vacation account needs a reason and shows up in the month list.
final class VacationCorrectionUITests: XCTestCase {
    func testCorrectionWithReason() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        app.buttons["day-\(formatter.string(from: Date()))"].tap()

        let stepper = app.steppers["vacationCorrection"]
        for _ in 0..<5 where !stepper.isHittable { app.swipeUp() }
        stepper.buttons.element(boundBy: 1).tap()
        stepper.buttons.element(boundBy: 1).tap()
        stepper.buttons.element(boundBy: 1).tap() // +1.5
        XCTAssertFalse(app.buttons["Sichern"].isEnabled, "a correction needs a reason")

        let note = app.textFields["vacationCorrectionNote"]
        note.tap()
        note.typeText("laut Urlaubskarte")
        XCTAssertTrue(app.buttons["Sichern"].isEnabled)
        app.buttons["Sichern"].tap()

        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Urlaubskonto +1,5'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }
}
