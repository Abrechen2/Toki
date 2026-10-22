import XCTest
@testable import TokiCore

/// Half vacation days, fractional credits and corrections of the vacation account
/// (needed to reproduce official vacation cards exactly).
final class VacationDetailsTests: XCTestCase {
    private func settings(anchor: Double) -> Settings {
        var settings = Settings.default
        settings.anchor = VacationAnchor(value: anchor, date: LocalDate(2030, 1, 1), note: "")
        return settings
    }

    func testHalfVacationDayCountsHalf() {
        let day = DayRecord(date: LocalDate(2030, 12, 31), targetSeconds: 8 * 3600,
                            entries: [TimeEntry(kind: .vacation, dayFraction: 0.5)])
        XCTAssertEqual(Calculator.vacationDays(day), 0.5)
        XCTAssertEqual(Calculator.overtime(day), 0, "an absence day has no target, like a full one")
        XCTAssertEqual(VacationLedger(days: [day], settings: settings(anchor: 10)).balance(on: LocalDate(2030, 12, 31)), 9.5)
    }

    func testFractionalCredit() {
        let day = DayRecord(date: LocalDate(2030, 5, 1), targetSeconds: 0, entries: [],
                            credit: Credit(note: "Feiertag gearbeitet", days: 1.5))
        XCTAssertEqual(Calculator.creditDays(day), 1.5)
        XCTAssertEqual(VacationLedger(days: [day], settings: settings(anchor: 10)).balance(on: LocalDate(2030, 5, 1)), 11.5)
    }

    func testCorrectionAppearsAsLedgerLine() {
        let day = DayRecord(date: LocalDate(2030, 12, 31), targetSeconds: 0, entries: [],
                            vacationCorrection: VacationCorrection(days: 3.5, note: "laut Urlaubskarte"))
        let ledger = VacationLedger(days: [day], settings: settings(anchor: 10))
        XCTAssertEqual(ledger.balance(on: LocalDate(2030, 12, 31)), 13.5)
        let line = ledger.lines.last
        XCTAssertEqual(line?.kind, .correction)
        XCTAssertEqual(line?.change, 3.5)
        XCTAssertEqual(line?.note, "laut Urlaubskarte")
        XCTAssertEqual(Calculator.overtime(day), 0)
    }

    func testVacationBlocksAddFractions() {
        let days = [
            DayRecord(date: LocalDate(2030, 12, 30), targetSeconds: 0, entries: [TimeEntry(kind: .vacation)]),
            DayRecord(date: LocalDate(2030, 12, 31), targetSeconds: 0, entries: [TimeEntry(kind: .vacation, dayFraction: 0.5)]),
        ]
        let blocks = VacationLedger(days: days, settings: settings(anchor: 10)).vacationBlocks(through: LocalDate(2031, 1, 1))
        XCTAssertEqual(blocks.first?.days, 1.5)
    }

    func testOldDataWithoutTheNewFieldsStillDecodes() throws {
        let json = #"{"version":1,"settings":\#(String(decoding: try JSONEncoder().encode(Settings.default), as: UTF8.self)),"days":[{"date":"2030-01-07","targetSeconds":0,"adjustmentSeconds":0,"credit":{"note":"x"},"entries":[{"id":"6F8CF2DA-94C2-4471-B533-A7623D935A2F","kind":"vacation","breakSeconds":0,"note":""}]}]}"#
        let snapshot = try Snapshot.decode(Data(json.utf8))
        XCTAssertEqual(snapshot.days.first?.credit?.days, 1)
        XCTAssertNil(snapshot.days.first?.entries.first?.dayFraction)
        XCTAssertNil(snapshot.days.first?.vacationCorrection)
    }

    func testImpossibleFractionsAreRejected() throws {
        var bad = DayRecord(date: LocalDate(2030, 1, 7), targetSeconds: 0, entries: [TimeEntry(kind: .vacation, dayFraction: 3)])
        XCTAssertThrowsError(try Snapshot.decode(Snapshot(settings: .default, days: [bad]).encoded()))
        bad = DayRecord(date: LocalDate(2030, 1, 7), targetSeconds: 0, entries: [],
                        vacationCorrection: VacationCorrection(days: .infinity, note: ""))
        XCTAssertThrowsError(try Snapshot.decode(Snapshot(settings: .default, days: [bad]).encoded()))
    }

    func testCSVShowsFractionsAndCorrections() {
        let day = DayRecord(date: LocalDate(2030, 5, 1), targetSeconds: 0, entries: [TimeEntry(kind: .vacation, dayFraction: 0.5)],
                            credit: Credit(note: "Feiertag", days: 1.5),
                            vacationCorrection: VacationCorrection(days: -1, note: "Korrektur"))
        let line = CSVExport.make(days: [day]).split(separator: "\n")[1]
        XCTAssertTrue(line.contains("½ Urlaub"), String(line))
        XCTAssertTrue(line.contains(";1,5;"), String(line))
        XCTAssertTrue(line.contains("Urlaubskorrektur -1"), String(line))
    }
}
