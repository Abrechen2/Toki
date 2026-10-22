import XCTest
@testable import TokiCore

final class LocationDayTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()
    private let monday = LocalDate(2031, 3, 3)

    private func at(_ date: LocalDate, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day,
                                           hour: hour, minute: minute, second: second))!
    }

    private func entry(_ visits: [Visit], on date: LocalDate? = nil, now: Date? = nil,
                       schedule: WeekSchedule = .standard) -> TimeEntry? {
        let day = date ?? monday
        return LocationDay.entry(for: day, visits: visits, now: now ?? at(day.adding(days: 1), 9, 0),
                                 calendar: calendar, schedule: schedule, region: .bavaria)
    }

    func testSingleVisitRoundsToFiveMinutes() throws {
        let result = try XCTUnwrap(entry([Visit(arrival: at(monday, 8, 32, 40), departure: at(monday, 16, 43))]))
        XCTAssertEqual(result.kind, .work)
        XCTAssertEqual(result.startSeconds, 8 * 3600 + 35 * 60)
        XCTAssertEqual(result.endSeconds, 16 * 3600 + 45 * 60)
        XCTAssertEqual(result.origin, EntryOrigin(source: .location, uncertain: []))
    }

    func testFirstArrivalAndLastDepartureCount() throws {
        let result = try XCTUnwrap(entry([
            Visit(arrival: at(monday, 8, 30), departure: at(monday, 12, 0)),
            Visit(arrival: at(monday, 12, 40), departure: at(monday, 16, 30)),
        ]))
        XCTAssertEqual(result.startSeconds, 8 * 3600 + 1800)
        XCTAssertEqual(result.endSeconds, 16 * 3600 + 1800)
    }

    func testVisitsShorterThanOneHourAreIgnored() throws {
        let result = try XCTUnwrap(entry([
            Visit(arrival: at(monday, 7, 0), departure: at(monday, 7, 20)),
            Visit(arrival: at(monday, 8, 30), departure: at(monday, 16, 30)),
            Visit(arrival: at(monday, 19, 0), departure: at(monday, 19, 59)),
        ]))
        XCTAssertEqual(result.startSeconds, 8 * 3600 + 1800)
        XCTAssertEqual(result.endSeconds, 16 * 3600 + 1800)
        XCTAssertNil(entry([Visit(arrival: at(monday, 9, 0), departure: at(monday, 9, 45))]))
    }

    func testScheduleBreakIsApplied() throws {
        var schedule = WeekSchedule.standard
        schedule.days[2]?.breakSeconds = 1800
        let result = try XCTUnwrap(entry([Visit(arrival: at(monday, 8, 30), departure: at(monday, 16, 30))],
                                         schedule: schedule))
        XCTAssertEqual(result.breakSeconds, 1800)
    }

    func testRunningDayHasNoEndAndIsNotUncertain() throws {
        let result = try XCTUnwrap(entry([Visit(arrival: at(monday, 8, 30), departure: nil)], now: at(monday, 10, 0)))
        XCTAssertEqual(result.startSeconds, 8 * 3600 + 1800)
        XCTAssertNil(result.endSeconds)
        XCTAssertEqual(result.origin?.uncertain, [])
        XCTAssertTrue(result.isRunning)
    }

    func testOpenVisitOnPastDayIsMissingEnd() throws {
        let result = try XCTUnwrap(entry([Visit(arrival: at(monday, 8, 30), departure: nil)]))
        XCTAssertNil(result.endSeconds)
        XCTAssertEqual(result.origin?.uncertain, [.missingEnd])
    }

    func testOvernightLongAndUnusualAreFlagged() throws {
        let result = try XCTUnwrap(entry([Visit(arrival: at(monday, 8, 0), departure: at(monday.adding(days: 1), 1, 0))]))
        XCTAssertEqual(result.endSeconds, 25 * 3600)
        XCTAssertEqual(result.origin?.uncertain, [.overnight, .longDay, .unusualTime])
    }

    func testEarlyStartIsUnusual() throws {
        let result = try XCTUnwrap(entry([Visit(arrival: at(monday, 4, 30), departure: at(monday, 12, 0))]))
        XCTAssertEqual(result.origin?.uncertain, [.unusualTime])
    }

    func testWeekendAndHolidayAreFlagged() throws {
        let saturday = LocalDate(2031, 3, 8)
        let weekend = try XCTUnwrap(entry([Visit(arrival: at(saturday, 9, 0), departure: at(saturday, 12, 0))], on: saturday))
        XCTAssertEqual(weekend.origin?.uncertain, [.nonWorkday])
        let mayDay = LocalDate(2031, 5, 1) // Thursday, public holiday
        let holiday = try XCTUnwrap(entry([Visit(arrival: at(mayDay, 9, 0), departure: at(mayDay, 12, 0))], on: mayDay))
        XCTAssertEqual(holiday.origin?.uncertain, [.nonWorkday])
    }

    func testOnlyVisitsStartingOnTheDayCount() {
        let sunday = monday.adding(days: -1)
        XCTAssertNil(entry([Visit(arrival: at(sunday, 22, 0), departure: at(monday, 2, 0))]))
    }

    func testRunningOrIncompleteDayDoesNotCountAsOvertime() {
        let running = DayRecord(date: monday, targetSeconds: 8 * 3600,
                                entries: [TimeEntry(kind: .work, startSeconds: 8 * 3600, endSeconds: nil)])
        XCTAssertEqual(Calculator.overtime(running), 0)
    }

    func testEntryOriginSurvivesCodingAndOldDataDecodes() throws {
        let entry = TimeEntry(kind: .work, startSeconds: 0, endSeconds: 3600,
                              origin: EntryOrigin(source: .location, uncertain: [.longDay]))
        XCTAssertEqual(try JSONDecoder().decode(TimeEntry.self, from: JSONEncoder().encode(entry)), entry)
        let old = #"{"id":"6F8CF2DA-94C2-4471-B533-A7623D935A2F","kind":"work","breakSeconds":0,"note":""}"#
        XCTAssertNil(try JSONDecoder().decode(TimeEntry.self, from: Data(old.utf8)).origin)
    }

    func testSettingsWithoutOfficeStillDecode() throws {
        var settings = Settings.default
        settings.office = OfficeLocation(latitude: 48.1, longitude: 11.5, radius: 150, name: "Büro", notify: true)
        XCTAssertEqual(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings)), settings)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Settings.default)) as! [String: Any]
        json.removeValue(forKey: "office")
        XCTAssertNil(try JSONDecoder().decode(Settings.self, from: JSONSerialization.data(withJSONObject: json)).office)
    }
}
