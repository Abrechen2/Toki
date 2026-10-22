import XCTest
@testable import TokiCore

final class CalculatorTests: XCTestCase {
    private let hour = 3600

    private func work(_ start: Double, _ end: Double, breakMinutes: Int = 0) -> TimeEntry {
        TimeEntry(kind: .work, startSeconds: Int(start * 3600), endSeconds: Int(end * 3600),
                  breakSeconds: breakMinutes * 60)
    }

    func testLocalDateWeekdayAndArithmetic() {
        let date = LocalDate(2026, 10, 21)
        XCTAssertEqual(date.weekday, 4) // Wednesday, Apple numbering 1 = Sunday
        XCTAssertEqual(date.adding(days: 11), LocalDate(2026, 11, 1))
        XCTAssertEqual(LocalDate(2026, 12, 31).adding(days: 1), LocalDate(2027, 1, 1))
        XCTAssertEqual(LocalDate(iso: "2024-02-29"), LocalDate(2024, 2, 29))
        XCTAssertNil(LocalDate(iso: "2025-02-29"))
        XCTAssertEqual(LocalDate(2026, 1, 5).iso, "2026-01-05")
        XCTAssertEqual(LocalDate(2026, 1, 1).days(until: LocalDate(2026, 12, 31)), 364)
    }

    func testWorkdayWithBreakIsHalfHourShort() {
        let day = DayRecord(date: LocalDate(2026, 10, 19), targetSeconds: 8 * hour + 1800,
                            entries: [work(8, 16.5, breakMinutes: 30)])
        XCTAssertEqual(Calculator.worked(day), 8 * hour)
        XCTAssertEqual(Calculator.overtime(day), -1800)
    }

    func testAbsenceZeroesTarget() {
        let day = DayRecord(date: LocalDate(2026, 10, 19), targetSeconds: 8 * hour + 1800,
                            entries: [TimeEntry(kind: .vacation)])
        XCTAssertEqual(Calculator.effectiveTarget(day), 0)
        XCTAssertEqual(Calculator.overtime(day), 0)
        XCTAssertEqual(Calculator.vacationDays(day), 1)
    }

    func testOvertimeReductionShowsMinusTarget() {
        let day = DayRecord(date: LocalDate(2026, 5, 15), targetSeconds: 5 * hour,
                            entries: [TimeEntry(kind: .overtimeReduction)])
        XCTAssertEqual(Calculator.overtime(day), -5 * hour)
    }

    func testCreditedWeekendWork() {
        let day = DayRecord(date: LocalDate(2031, 3, 8), targetSeconds: 0,
                            entries: [work(8, 16)], credit: Credit(note: "Messe am Wochenende"))
        XCTAssertEqual(Calculator.worked(day), 8 * hour)
        XCTAssertEqual(Calculator.overtime(day), 0)
        XCTAssertEqual(Calculator.creditDays(day), 1)
    }

    func testCreditedRegularWorkdayCountsAsTargetFulfilled() {
        let day = DayRecord(date: LocalDate(2031, 3, 14), targetSeconds: 5 * hour,
                            entries: [], credit: Credit(note: "Reisetag"))
        XCTAssertEqual(Calculator.overtime(day), 0)
    }

    func testDayWithoutEntriesHasNoTarget() {
        // myTime only counts days that have entries; an untouched workday is not a deficit.
        let day = DayRecord(date: LocalDate(2026, 10, 19), targetSeconds: 8 * hour, entries: [])
        XCTAssertEqual(Calculator.effectiveTarget(day), 0)
        XCTAssertEqual(Calculator.overtime(day), 0)
    }

    func testAdjustmentIsAdded() {
        let day = DayRecord(date: LocalDate(2026, 1, 2), targetSeconds: 0, entries: [],
                            adjustmentSeconds: -2 * hour)
        XCTAssertEqual(Calculator.overtime(day), -2 * hour)
    }

    func testWorkAcrossMidnight() {
        let day = DayRecord(date: LocalDate(2026, 1, 2), targetSeconds: 0, entries: [work(22, 26)])
        XCTAssertEqual(Calculator.worked(day), 4 * hour)
    }

    func testHoursFormat() {
        XCTAssertEqual(HoursFormat.signed(Int((12.4925 * 3600).rounded())), "+12h 30m")
        XCTAssertEqual(HoursFormat.signed(-1800), "-0h 30m")
        XCTAssertEqual(HoursFormat.signed(0), "0h 00m")
        XCTAssertEqual(HoursFormat.plain(8 * 3600 + 1800), "8h 30m")
        XCTAssertEqual(HoursFormat.clock(8 * 3600 + 1800), "08:30")
        XCTAssertEqual(HoursFormat.clock(26 * 3600), "02:00")
        XCTAssertEqual(HoursFormat.days(1.5), "1,5")
        XCTAssertEqual(HoursFormat.days(38), "38")
    }
}
