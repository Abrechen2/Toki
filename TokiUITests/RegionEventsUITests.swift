import XCTest

/// A phone reports one arrival as "entered" and as "inside" (and one departure twice as well);
/// each must give exactly one message.
final class RegionEventsUITests: XCTestCase {
    func testArrivalReportedTwiceSendsOneMessage() {
        let app = launch(events: "inside,enter")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'läuft seit'"))
            .firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(sentMessages(app), "1")
    }

    func testDepartureReportedTwiceSendsOneMessage() {
        let app = launch(events: "enter,outside,exit")
        sleep(2)
        XCTAssertEqual(sentMessages(app), "2")
    }

    private func launch(events: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launchEnvironment = ["TOKI_OFFICE": "48.0,11.0,150,1", "TOKI_REGION_EVENTS": events]
        app.launch()
        return app
    }

    private func sentMessages(_ app: XCUIApplication) -> String? {
        let element = app.descendants(matching: .any)["sentMessages"]
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        return element.value as? String
    }
}
