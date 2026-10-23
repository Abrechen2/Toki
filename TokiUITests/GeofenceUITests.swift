import XCTest

/// Real CoreLocation geofence in the simulator. Runs only when the host moves the simulated
/// location (TOKI_GEOFENCE_TEST=1): outside -> inside -> outside the office at 48.0,11.0.
final class GeofenceUITests: XCTestCase {
    func testArrivalAndDepartureFromSimulatedLocation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TOKI_GEOFENCE_TEST"] == "1")
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launchEnvironment = ["TOKI_OFFICE": "48.0,11.0,150,1"]
        app.launch()

        let running = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'läuft seit'")).firstMatch
        XCTAssertTrue(running.waitForExistence(timeout: 90), "no arrival from the geofence")
        // iOS reports the arrival as "entered" and as "inside"; only one message may go out.
        sleep(5)
        XCTAssertEqual(app.descendants(matching: .any)["sentMessages"].value as? String, "1", "duplicate arrival message")
        // Departure follows after the host moves away; a visit under 1 h is ignored, so the entry disappears.
        let deadline = Date().addingTimeInterval(90)
        while running.exists && Date() < deadline { sleep(2) }
        XCTAssertFalse(running.exists, "no departure from the geofence")
        sleep(5)
        XCTAssertEqual(app.descendants(matching: .any)["sentMessages"].value as? String, "2", "duplicate departure message")
    }
}
