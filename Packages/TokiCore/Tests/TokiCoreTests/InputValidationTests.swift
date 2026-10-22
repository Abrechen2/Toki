import XCTest
@testable import TokiCore

/// Backup files come from outside; absurd or broken numbers must never crash the app.
final class InputValidationTests: XCTestCase {
    private func myTime(planned: String, start: String = "2030-01-07T06:00:00Z", end: String = "2030-01-07T15:00:00Z",
                        breakHours: String = "0.5") -> Data {
        let type = #"{"nameOnExport_value":"Arbeit","category_value":1,"hourMultiplicator_value":1}"#
        return Data("""
        {"exportDate":"2030-03-01T10:00:00Z",
         "jobsBackup":[{"job":{"name_value":"X","configuration_value":{"overtimeConfig_value":{"initialOvertimeHours_value":1e300}}},
                        "defaultDays":[{"weekday":2,"plannedHoursOfDay_value":1e308,"startTime_value":-5,"endTime_value":1e40,
                                        "breakEntries_value":[]}]}],
         "yearsBackup":[{"timeMonths":[{"days":[
           {"date":"2030-01-06T23:00:00Z","plannedHoursOfDay_value":\(planned),"entries":[
             {"entryType_value":\(type),"startDate_value":"\(start)","endDate_value":"\(end)",
              "breakEntries_value":[{"totalHours_value":\(breakHours)}],"note_value":""}]}]}]}]}
        """.utf8)
    }

    func testAbsurdNumbersInMyTimeBackupDoNotCrash() throws {
        let result = try MyTimeImporter.parse(myTime(planned: "1e308", breakHours: "-1e300"))
        let day = try XCTUnwrap(result.days.first)
        XCTAssertEqual(day.targetSeconds, 0)
        XCTAssertTrue(day.entries.isEmpty, "entry with an impossible break is skipped")
        XCTAssertEqual(result.settings.initialOvertimeSeconds, 0)
        // The absurd template is dropped; with no valid one left the existing schedule stays.
        XCTAssertEqual(result.settings.schedule, WeekSchedule.standard)
        XCTAssertFalse(result.summary.warnings.isEmpty)
    }

    func testEntryWithEndFarInTheFutureIsSkipped() throws {
        let result = try MyTimeImporter.parse(myTime(planned: "8", end: "9999-12-31T23:00:00Z"))
        XCTAssertEqual(result.days.first?.entries.count, 0)
        XCTAssertTrue(result.summary.warnings.contains { $0.contains("07.01.2030") })
    }

    func testSafeSecondsRejectsNonFiniteAndHugeValues() {
        XCTAssertNil(Safe.seconds(hours: .nan, limitHours: 48))
        XCTAssertNil(Safe.seconds(hours: .infinity, limitHours: 48))
        XCTAssertNil(Safe.seconds(hours: 49, limitHours: 48))
        XCTAssertNil(Safe.seconds(hours: -0.1, limitHours: 48))
        XCTAssertEqual(Safe.seconds(hours: 8.5, limitHours: 48), 30600)
        XCTAssertEqual(Safe.seconds(hours: -5, limitHours: 1000, allowNegative: true), -18000)
    }

    func testSnapshotWithAbsurdValuesIsRejected() throws {
        let good = Snapshot(settings: .default, days: [
            DayRecord(date: LocalDate(2030, 1, 7), targetSeconds: 28800,
                      entries: [TimeEntry(kind: .work, startSeconds: 28800, endSeconds: 57600)]),
        ])
        XCTAssertNoThrow(try Snapshot.decode(good.encoded()))

        var json = String(decoding: try good.encoded(), as: UTF8.self)
        json = json.replacingOccurrences(of: "\"endSeconds\" : 57600", with: "\"endSeconds\" : 9223372036854775807")
        XCTAssertThrowsError(try Snapshot.decode(Data(json.utf8))) { error in
            XCTAssertEqual(error as? SnapshotError, .invalidDay(LocalDate(2030, 1, 7)))
        }

        var settings = Settings.default
        settings.entitlementPerYear = .infinity
        XCTAssertThrowsError(try Snapshot.decode(Snapshot(settings: settings, days: []).encoded()))
    }
}
