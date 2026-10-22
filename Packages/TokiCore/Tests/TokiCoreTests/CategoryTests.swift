import XCTest
@testable import TokiCore

/// Categories: separate time (e.g. work abroad paid on its own) stays out of target and overtime
/// and has its own report; counting categories only label normal work.
final class CategoryTests: XCTestCase {
    private let abroad = EntryCategory(name: "Ausland", colorIndex: 2, countsAsWorkTime: false)
    private let project = EntryCategory(name: "Projekt", colorIndex: 0, countsAsWorkTime: true)
    private let tuesday = LocalDate(2030, 1, 8)

    private func entry(_ category: EntryCategory?, _ start: Double, _ end: Double, note: String = "") -> TimeEntry {
        var entry = TimeEntry.work(start: Int(start * 3600), end: Int(end * 3600), breakSeconds: 0, note: note)
        if let category { entry.assign(category) }
        return entry
    }

    func testSeparateTimeIsNotWorkTime() {
        let day = DayRecord(date: tuesday, targetSeconds: 8 * 3600, entries: [entry(abroad, 8, 17)])
        XCTAssertEqual(day.entries.first?.kind, .separateTime)
        XCTAssertEqual(Calculator.worked(day), 0)
        XCTAssertEqual(Calculator.effectiveTarget(day), 0, "a day with only separate time is like a day without entries")
        XCTAssertEqual(Calculator.overtime(day), 0)
        XCTAssertEqual(day.entries.first?.durationSeconds, 9 * 3600)
    }

    func testMixedDayCountsOnlyNormalWork() {
        let day = DayRecord(date: tuesday, targetSeconds: 8 * 3600, entries: [entry(abroad, 6, 10), entry(nil, 10, 18)])
        XCTAssertEqual(Calculator.worked(day), 8 * 3600)
        XCTAssertEqual(Calculator.overtime(day), 0)
    }

    func testCountingCategoryIsNormalWork() {
        let day = DayRecord(date: tuesday, targetSeconds: 8 * 3600, entries: [entry(project, 8, 17)])
        XCTAssertEqual(day.entries.first?.kind, .work)
        XCTAssertEqual(day.entries.first?.categoryID, project.id)
        XCTAssertEqual(Calculator.overtime(day), 3600)
    }

    func testSwitchingTheCategoryRuleMovesItsEntries() {
        var abroadCounts = abroad
        abroadCounts.countsAsWorkTime = true
        let days = [DayRecord(date: tuesday, targetSeconds: 8 * 3600, entries: [entry(abroad, 8, 17), entry(project, 17, 18)])]
        let updated = EntryCategory.apply(abroadCounts, to: days)
        XCTAssertEqual(updated[0].entries.map(\.kind), [.work, .work])
        XCTAssertEqual(EntryCategory.apply(abroad, to: updated)[0].entries.map(\.kind), [.separateTime, .work])
    }

    func testRemovingACategoryKeepsTheTimeOutsideTheAccount() {
        let days = [DayRecord(date: tuesday, targetSeconds: 8 * 3600, entries: [entry(abroad, 8, 17)])]
        let cleared = EntryCategory.remove(abroad.id, from: days)
        XCTAssertNil(cleared[0].entries[0].categoryID)
        XCTAssertEqual(cleared[0].entries[0].kind, .separateTime, "removing a label must not change overtime")
    }

    func testReportForOneCategoryAndPeriod() {
        let days = [
            DayRecord(date: LocalDate(2030, 1, 7), targetSeconds: 8 * 3600, entries: [entry(abroad, 8, 12, note: "Basel, Inbetriebnahme")]),
            DayRecord(date: tuesday, targetSeconds: 8 * 3600, entries: [entry(nil, 8, 16), entry(abroad, 16, 18, note: "Zürich")]),
            DayRecord(date: LocalDate(2030, 2, 1), targetSeconds: 8 * 3600, entries: [entry(abroad, 8, 9)]),
        ]
        let report = CategoryReport(days: days, categoryID: abroad.id, from: LocalDate(2030, 1, 1), to: LocalDate(2030, 1, 31))
        XCTAssertEqual(report.rows.map(\.date), [LocalDate(2030, 1, 7), tuesday])
        XCTAssertEqual(report.rows.map(\.note), ["Basel, Inbetriebnahme", "Zürich"])
        XCTAssertEqual(report.totalSeconds, 6 * 3600)
        let csv = report.csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(csv[0], "Datum;Wochentag;Beginn;Ende;Pause;Stunden;Notiz")
        XCTAssertEqual(csv[1], "07.01.2030;Mo;08:00;12:00;0,00;4,00;Basel, Inbetriebnahme")
        XCTAssertEqual(csv.last, "Summe;;;;;6,00;")
    }

    func testOldEntriesAndSettingsStillDecode() throws {
        let old = #"{"id":"6F8CF2DA-94C2-4471-B533-A7623D935A2F","kind":"work","breakSeconds":0,"note":""}"#
        XCTAssertNil(try JSONDecoder().decode(TimeEntry.self, from: Data(old.utf8)).categoryID)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Settings.default)) as! [String: Any]
        json.removeValue(forKey: "categories")
        XCTAssertEqual(try JSONDecoder().decode(Settings.self, from: JSONSerialization.data(withJSONObject: json)).categories, [])
    }
}
