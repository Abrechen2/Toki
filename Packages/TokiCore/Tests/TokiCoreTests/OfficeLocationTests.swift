import XCTest
@testable import TokiCore

final class OfficeLocationTests: XCTestCase {
    private let office = OfficeLocation(latitude: 48.07, longitude: 11.68, radius: 150, name: "Büro", notify: true,
                                        since: Date(timeIntervalSince1970: 2_000_000_000))

    func testOpenStayBeforeTheOfficeWasSetIsStale() {
        XCTAssertTrue(office.isStale(openArrival: Date(timeIntervalSince1970: 1_999_999_000)))
        XCTAssertFalse(office.isStale(openArrival: Date(timeIntervalSince1970: 2_000_000_100)))
    }

    func testOfficeWithoutDateTreatsEveryOpenStayAsStale() {
        var old = office
        old.since = nil
        XCTAssertTrue(old.isStale(openArrival: Date()))
    }

    func testRegionMatchesOnlyTheCurrentCenter() {
        XCTAssertTrue(office.matches(latitude: 48.07, longitude: 11.68))
        XCTAssertFalse(office.matches(latitude: 48.81, longitude: 11.85)) // old place far away
    }

    func testSamePlaceIgnoresNameAndNotifications() {
        var renamed = office
        renamed.name = "Firma"
        renamed.notify = false
        XCTAssertTrue(office.isSamePlace(as: renamed))
        var moved = office
        moved.radius = 200
        XCTAssertFalse(office.isSamePlace(as: moved))
        XCTAssertFalse(office.isSamePlace(as: nil))
    }
}
