import XCTest
@testable import TokiCore

/// Findings from the independent review before the App Store submission (2026-10-22).
final class ReviewFindingsTests: XCTestCase {
    func testSnapshotWithIntMinIsRejectedInsteadOfCrashing() throws {
        var json = String(decoding: try Snapshot(settings: .default, days: []).encoded(), as: UTF8.self)
        json = json.replacingOccurrences(of: "\"initialOvertimeSeconds\" : 0", with: "\"initialOvertimeSeconds\" : -9223372036854775808")
        XCTAssertThrowsError(try Snapshot.decode(Data(json.utf8)))

        let day = DayRecord(date: LocalDate(2030, 1, 7), targetSeconds: 0, entries: [], adjustmentSeconds: 0)
        var dayJSON = String(decoding: try Snapshot(settings: .default, days: [day]).encoded(), as: UTF8.self)
        dayJSON = dayJSON.replacingOccurrences(of: "\"adjustmentSeconds\" : 0", with: "\"adjustmentSeconds\" : -9223372036854775808")
        XCTAssertThrowsError(try Snapshot.decode(Data(dayJSON.utf8)))
    }

    func testOvernightScheduleGivesTheRealShiftLength() {
        let night = DayTemplate(targetSeconds: 8 * 3600, startSeconds: 22 * 3600, endSeconds: 6 * 3600)
        let entry = WeekSchedule(days: [2: night]).workEntry(for: LocalDate(2030, 1, 7))
        XCTAssertEqual(entry.workedSeconds, 8 * 3600)
        XCTAssertEqual(entry.endSeconds, 30 * 3600)
    }

    func testTemplateWithExplicitNextDayEndKeepsItsLength() {
        let long = DayTemplate(targetSeconds: 8 * 3600, startSeconds: 8 * 3600, endSeconds: 32 * 3600)
        let entry = WeekSchedule(days: [2: long]).workEntry(for: LocalDate(2030, 1, 7))
        XCTAssertEqual(entry.endSeconds, 32 * 3600)
        XCTAssertEqual(entry.workedSeconds, 24 * 3600)
    }

    func testHugeDayCountsFormatWithoutCrashing() {
        XCTAssertFalse(HoursFormat.days(1e300).isEmpty)
        XCTAssertFalse(HoursFormat.days(.infinity).isEmpty)
    }

    func testMyTimeImportKeepsWallClockTimesOnDSTDays() throws {
        // 31 March 2030 is the spring-forward Sunday in Germany: 08:00–16:00 CEST = 06:00–14:00 UTC.
        let type = #"{"nameOnExport_value":"Arbeit","category_value":1,"hourMultiplicator_value":1}"#
        let json = """
        {"exportDate":"2030-04-02T10:00:00Z","jobsBackup":[{"job":{"name_value":"X"},"defaultDays":[]}],
         "yearsBackup":[{"timeMonths":[{"days":[
           {"date":"2030-03-30T23:00:00Z","plannedHoursOfDay_value":0,"entries":[
             {"entryType_value":\(type),"startDate_value":"2030-03-31T06:00:00Z","endDate_value":"2030-03-31T14:00:00Z",
              "breakEntries_value":[],"note_value":""}]},
           {"date":"2030-10-26T22:00:00Z","plannedHoursOfDay_value":0,"entries":[
             {"entryType_value":\(type),"startDate_value":"2030-10-27T07:00:00Z","endDate_value":"2030-10-27T15:00:00Z",
              "breakEntries_value":[],"note_value":""}]}]}]}]}
        """
        let days = try MyTimeImporter.parse(Data(json.utf8)).days
        let spring = try XCTUnwrap(days.first { $0.date == LocalDate(2030, 3, 31) }?.entries.first)
        XCTAssertEqual(spring.startSeconds, 8 * 3600)
        XCTAssertEqual(spring.endSeconds, 16 * 3600)
        // 27 October 2030 is the fall-back Sunday: 08:00–16:00 CET = 07:00–15:00 UTC.
        let autumn = try XCTUnwrap(days.first { $0.date == LocalDate(2030, 10, 27) }?.entries.first)
        XCTAssertEqual(autumn.startSeconds, 8 * 3600)
        XCTAssertEqual(autumn.endSeconds, 16 * 3600)
    }
}
