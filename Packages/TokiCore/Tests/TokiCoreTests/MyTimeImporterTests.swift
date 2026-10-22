import XCTest
@testable import TokiCore

/// Hand-made backup in the myTime structure (docs/mytime-backup-format.md); no real data.
final class MyTimeImporterTests: XCTestCase {
    private func type(_ id: String, _ export: String, category: Int, multiplier: Int) -> String {
        """
        {"name_value":"\(export) X","nameOnExport_value":"\(export)","category_value":\(category),
         "hourMultiplicator_value":\(multiplier),"dtoReferences":{"entryTypeDTOId":"\(id)"}}
        """
    }

    private var fixture: Data {
        let work = type("10001111-0001-0000-0000-000011110000", "Arbeit (mit Pausen)", category: 1, multiplier: 1)
        let vacation = type("10001111-1001-0000-0000-000011110000", "Urlaub", category: 2, multiplier: 0)
        let holiday = type("10001111-4001-0000-0000-000011110000", "Feiertag", category: 2, multiplier: 0)
        let reduction = type("10001111-6000-0000-0000-000011110000", "Überstundenabbau", category: 2, multiplier: 1)
        let sick = type("10001111-2001-0000-0000-000011110000", "Krankheit", category: 2, multiplier: 0)
        let json = """
        {"appVersion":"26.3.2","exportDate":"2030-03-01T10:00:00Z",
         "jobsBackup":[{"job":{"name_value":"Firma","configuration_value":{
            "overtimeConfig_value":{"isOvertimeCalculationOn_value":true,"initialOvertimeHours_value":10},
            "vacationConfig_value":{"isVacationDaysCalculationOn_value":true,"vacationDaysPerYear_value":28,
              "initialVacationDays_value":5,"vacationDaysRenewalDate_value":"2029-12-31T23:00:00Z"}}},
           "defaultDays":[
             {"weekday":2,"startTime_value":7.5,"endTime_value":16,"plannedHoursOfDay_value":8,
              "breakEntries_value":[{"totalHours_value":0.5}],"entryType_value":\(work)},
             {"weekday":6,"startTime_value":8,"endTime_value":12,"plannedHoursOfDay_value":4,
              "breakEntries_value":[],"entryType_value":\(work)},
             {"weekday":1,"plannedHoursOfDay_value":0,"breakEntries_value":[],"entryType_value":\(work)}],
           "timeJob":{"totalHours":0,"totalOvertimeHours":0}}],
         "yearsBackup":[{"timeYear":{"yearNumber":2030},"timeMonths":[
           {"date":"2029-12-31T23:00:00Z","days":[
             {"date":"2030-01-06T23:00:00Z","plannedHoursOfDay_value":8,"entries":[
               {"entryType_value":\(work),"startDate_value":"2030-01-07T06:00:00Z","endDate_value":"2030-01-07T15:30:00Z",
                "breakEntries_value":[{"totalHours_value":0.5}],"overtimeHours_value":0,"note_value":"Messe"}]},
             {"date":"2030-01-07T23:00:00Z","plannedHoursOfDay_value":0,"entries":[
               {"entryType_value":\(vacation),"breakEntries_value":[],"overtimeHours_value":0,"note_value":""}]},
             {"date":"2030-01-08T23:00:00Z","plannedHoursOfDay_value":7.5,"entries":[
               {"entryType_value":\(reduction),"breakEntries_value":[],"overtimeHours_value":-7.5,"note_value":""}]},
             {"date":"2030-01-12T23:00:00Z","plannedHoursOfDay_value":0,"entries":[
               {"entryType_value":\(work),"startDate_value":"2030-01-13T09:00:00Z","endDate_value":"2030-01-13T11:00:00Z",
                "breakEntries_value":[],"overtimeHours_value":0,"note_value":"+1 Urlaubstag"}]},
             {"date":"2030-01-13T23:00:00Z","plannedHoursOfDay_value":8,"entries":[]}]},
           {"date":"2030-05-31T22:00:00Z","days":[
             {"date":"2030-06-09T22:00:00Z","plannedHoursOfDay_value":0,"entries":[
               {"entryType_value":\(holiday),"breakEntries_value":[],"overtimeHours_value":0,"note_value":""}]},
             {"date":"2030-06-10T22:00:00Z","plannedHoursOfDay_value":0,"entries":[
               {"entryType_value":\(sick),"breakEntries_value":[],"overtimeHours_value":0,"note_value":""}]}]}
         ]}]}
        """
        return Data(json.utf8)
    }

    func testBerlinMidnightInWinterAndSummer() throws {
        let result = try MyTimeImporter.parse(fixture)
        let dates = result.days.map(\.date)
        XCTAssertEqual(dates.first, LocalDate(2030, 1, 7))
        XCTAssertTrue(dates.contains(LocalDate(2030, 6, 10)))
        XCTAssertEqual(result.summary.firstDate, LocalDate(2030, 1, 7))
        XCTAssertEqual(result.summary.lastDate, LocalDate(2030, 6, 11))
    }

    func testEntriesAreMappedWithLocalTimes() throws {
        let days = try MyTimeImporter.parse(fixture).days
        let monday = try XCTUnwrap(days.first { $0.date == LocalDate(2030, 1, 7) })
        XCTAssertEqual(monday.targetSeconds, 8 * 3600)
        XCTAssertEqual(monday.entries.first?.kind, .work)
        XCTAssertEqual(monday.entries.first?.startSeconds, 7 * 3600)
        XCTAssertEqual(monday.entries.first?.endSeconds, 16 * 3600 + 1800)
        XCTAssertEqual(monday.entries.first?.breakSeconds, 1800)
        XCTAssertEqual(monday.entries.first?.note, "Messe")
        XCTAssertEqual(Calculator.overtime(monday), 1 * 3600)

        let kinds = days.flatMap(\.entries).map(\.kind)
        XCTAssertEqual(kinds, [.work, .vacation, .overtimeReduction, .work, .publicHoliday, .sick])
        XCTAssertTrue(days.contains { $0.date == LocalDate(2030, 1, 14) && $0.entries.isEmpty })
    }

    func testSettingsAndSchedule() throws {
        let settings = try MyTimeImporter.parse(fixture).settings
        XCTAssertEqual(settings.jobName, "Firma")
        XCTAssertEqual(settings.initialOvertimeSeconds, 10 * 3600)
        XCTAssertEqual(settings.entitlementPerYear, 28)
        // myTime grants the year of the renewal date's predecessor too (see format doc).
        XCTAssertEqual(settings.anchor.value, 5)
        XCTAssertEqual(settings.anchor.date, LocalDate(2028, 12, 31))
        XCTAssertEqual(settings.schedule.days[2]?.targetSeconds, 8 * 3600)
        XCTAssertEqual(settings.schedule.days[2]?.startSeconds, 7 * 3600 + 1800)
        XCTAssertEqual(settings.schedule.days[2]?.breakSeconds, 1800)
        XCTAssertEqual(settings.schedule.days[6]?.targetSeconds, 4 * 3600)
        XCTAssertNil(settings.schedule.days[1])
    }

    func testSummaryMatchesMyTimeStyleTotals() throws {
        let result = try MyTimeImporter.parse(fixture)
        // 10 h initial + 1 h Monday − 7.5 h reduction + 2 h Sunday; the empty Tuesday counts 0
        XCTAssertEqual(result.summary.overtimeSeconds, Int(5.5 * 3600))
        XCTAssertEqual(result.summary.entryCount, 6)
        XCTAssertEqual(result.summary.vacationDaysTaken, 1)
        // 5 + 28 (2029) + 28 (2030) − 1
        XCTAssertEqual(result.summary.vacationRemaining, 60)
        XCTAssertEqual(result.summary.creditCandidates, 1)
    }

    func testGarbageThrows() {
        XCTAssertThrowsError(try MyTimeImporter.parse(Data("{}".utf8)))
        XCTAssertThrowsError(try MyTimeImporter.parse(Data("nope".utf8)))
    }
}
