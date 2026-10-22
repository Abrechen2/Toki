import XCTest
@testable import TokiCore

final class AccountsTests: XCTestCase {
    private func vacation(_ date: LocalDate) -> DayRecord {
        DayRecord(date: date, targetSeconds: 0, entries: [TimeEntry(kind: .vacation)])
    }

    private func vacations(_ from: LocalDate, _ to: LocalDate) -> [DayRecord] {
        var result: [DayRecord] = []
        var date = from
        while date <= to {
            if (2...6).contains(date.weekday) { result.append(vacation(date)) }
            date = date.adding(days: 1)
        }
        return result
    }

    private func credit(_ date: LocalDate) -> DayRecord {
        DayRecord(date: date, targetSeconds: 0, entries: [], credit: Credit(note: "Reise"))
    }

    func testEntitlementOnEveryFirstOfJanuaryAfterAnchor() {
        var settings = Settings.default
        settings.anchor = VacationAnchor(value: 15, date: LocalDate(2029, 12, 31), note: "Start")
        let ledger = VacationLedger(days: [], settings: settings)
        XCTAssertEqual(ledger.balance(on: LocalDate(2029, 12, 31)), 15)
        XCTAssertEqual(ledger.balance(on: LocalDate(2030, 1, 1)), 45)
        XCTAssertEqual(ledger.balance(on: LocalDate(2033, 6, 30)), 135)
    }

    func testDaysBeforeAnchorAreIgnored() {
        var settings = Settings.default
        settings.anchor = VacationAnchor(value: 20, date: LocalDate(2030, 4, 30), note: "")
        let ledger = VacationLedger(days: [vacation(LocalDate(2030, 4, 30)), vacation(LocalDate(2030, 5, 2))],
                                    settings: settings)
        XCTAssertEqual(ledger.balance(on: LocalDate(2030, 5, 2)), 19)
    }

    func testVacationBlocksCreditsAndEntitlementAcrossYears() {
        var settings = Settings.default
        settings.anchor = VacationAnchor(value: 20, date: LocalDate(2030, 6, 30), note: "Start")
        let days = vacations(LocalDate(2030, 8, 5), LocalDate(2030, 8, 16))      // 10 weekdays
            + vacations(LocalDate(2031, 3, 3), LocalDate(2031, 3, 7))            // 5 weekdays
            + [LocalDate(2030, 9, 7), LocalDate(2030, 9, 8)].map(credit)          // Sat + Sun
        let ledger = VacationLedger(days: days, settings: settings)
        XCTAssertEqual(ledger.balance(on: LocalDate(2030, 8, 31)), 10)
        XCTAssertEqual(ledger.balance(on: LocalDate(2030, 12, 31)), 12)
        XCTAssertEqual(ledger.balance(on: LocalDate(2031, 1, 1)), 42)
        XCTAssertEqual(ledger.balance(on: LocalDate(2031, 3, 31)), 37)
        XCTAssertEqual(ledger.lines.filter { $0.kind == .credit }.count, 2)
        XCTAssertEqual(ledger.lines.first?.kind, .anchor)
    }

    func testLedgerLinesCarryRunningBalance() {
        var settings = Settings.default
        settings.anchor = VacationAnchor(value: 10, date: LocalDate(2025, 12, 1), note: "")
        let ledger = VacationLedger(days: [vacation(LocalDate(2025, 12, 2)), credit(LocalDate(2026, 1, 3))],
                                    settings: settings)
        XCTAssertEqual(ledger.lines.map(\.balance), [10, 9, 39, 40])
        XCTAssertEqual(ledger.lines.map(\.kind), [.anchor, .vacation, .entitlement, .credit])
    }

    func testOvertimeAccountAddsInitialBalance() {
        var settings = Settings.default
        settings.initialOvertimeSeconds = 25 * 3600
        let day = DayRecord(date: LocalDate(2026, 1, 3), targetSeconds: 0,
                            entries: [TimeEntry(kind: .work, startSeconds: 8 * 3600, endSeconds: 10 * 3600)])
        XCTAssertEqual(OvertimeAccount.total(days: [day], settings: settings), 27 * 3600)
        XCTAssertEqual(OvertimeAccount.total(days: [day], settings: settings, through: LocalDate(2026, 1, 2)),
                       25 * 3600)
    }
}
