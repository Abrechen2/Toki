import XCTest

/// TestFlight report: far away from the office, yet "Gerade im Büro: ja" because an open stay from an
/// earlier office place was left over. On launch iOS reports "outside"; the stale stay must go.
/// Needs location access for Toki and a simulated location far from 48.07,11.68 (see README).
final class StaleStayUITests: XCTestCase {
    func testOpenStayFromEarlierPlaceIsDroppedWhenOutside() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launchEnvironment = ["TOKI_FAKE_VISITS": "\(today) 08:31", "TOKI_OFFICE": "48.07,11.68,150"]
        app.launch()

        let running = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'läuft seit'")).firstMatch
        let deadline = Date().addingTimeInterval(20)
        while running.exists && Date() < deadline { sleep(1) }
        XCTAssertFalse(running.exists, "stale open stay still listed")

        app.tabBars.buttons["Mehr"].tap()
        app.buttons["officeSettings"].tap()
        let atOffice = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Gerade im Büro'")).firstMatch
        // Swipe above the map; swiping on it would pan the map instead of the page.
        for _ in 0..<3 where !atOffice.isHittable {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
            start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)))
        }
        if !atOffice.exists, let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("stale-debug.png"))
            try? app.debugDescription.write(to: URL(fileURLWithPath: dir).appendingPathComponent("tree.txt"), atomically: true, encoding: .utf8)
        }
        XCTAssertTrue(atOffice.waitForExistence(timeout: 5))
        let yes = app.staticTexts.matching(NSPredicate(format: "label == 'ja'")).firstMatch
        XCTAssertFalse(yes.exists, "still claims to be at the office")
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("stale.png"))
        }
    }
}
