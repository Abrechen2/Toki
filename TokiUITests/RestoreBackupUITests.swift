import XCTest

/// Restoring through the real document picker. The host puts `Toki-Test-Sicherung.json` into
/// "On My iPhone" of the simulator first (see README); runs only with TOKI_RESTORE_TEST=1.
final class RestoreBackupUITests: XCTestCase {
    func testRestoreFromDocumentPicker() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TOKI_RESTORE_TEST"] == "1")
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        app.tabBars.buttons["Mehr"].tap()
        let restore = app.buttons["restoreBackup"]
        for _ in 0..<4 where !restore.isHittable { app.swipeUp() }
        restore.tap()

        // Document picker: Browse → On My iPhone → the file.
        let browse = app.buttons.matching(NSPredicate(format: "label == 'Durchsuchen' OR label == 'Browse'")).firstMatch
        if browse.waitForExistence(timeout: 5) { browse.tap() }
        let onDevice = app.descendants(matching: .any).matching(NSPredicate(
            format: "label == 'Auf meinem iPhone' OR label == 'On My iPhone'")).firstMatch
        if onDevice.waitForExistence(timeout: 5) { onDevice.tap() }
        let file = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Toki-Test-Sicherung'")).firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 10), "test file not visible in the picker")
        file.tap()

        let replace = app.buttons["Ersetzen"]
        XCTAssertTrue(replace.waitForExistence(timeout: 5), "nothing happened after choosing the file")
        replace.tap()

        app.tabBars.buttons["Urlaub"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Testurlaub'")).firstMatch
            .waitForExistence(timeout: 5), "restored data not shown")
    }
}
