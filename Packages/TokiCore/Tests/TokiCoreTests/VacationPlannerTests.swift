import XCTest
@testable import TokiCore

final class VacationPlannerTests: XCTestCase {
    private let schedule = WeekSchedule.standard

    private func booked(_ plan: [PlannedDay]) -> [LocalDate] {
        plan.filter { $0.status == .book }.map(\.date)
    }

    func testEasterBasedHolidays() {
        let holidays = Holidays.dates(year: 2026, region: .bavaria)
        XCTAssertNotNil(holidays[LocalDate(2026, 4, 3)])   // Karfreitag
        XCTAssertNotNil(holidays[LocalDate(2026, 4, 6)])   // Ostermontag
        XCTAssertNotNil(holidays[LocalDate(2026, 5, 14)])  // Christi Himmelfahrt
        XCTAssertNotNil(holidays[LocalDate(2026, 5, 25)])  // Pfingstmontag
        XCTAssertNotNil(holidays[LocalDate(2026, 6, 4)])   // Fronleichnam (Bayern)
        XCTAssertNotNil(holidays[LocalDate(2026, 1, 6)])   // Heilige Drei Könige (Bayern)
        XCTAssertNil(Holidays.dates(year: 2026, region: .berlin)[LocalDate(2026, 6, 4)])
        XCTAssertNotNil(Holidays.dates(year: 2026, region: .berlin)[LocalDate(2026, 3, 8)]) // Frauentag
        XCTAssertNotNil(Holidays.dates(year: 2025, region: .nationwide)[LocalDate(2025, 4, 18)]) // Karfreitag 2025
        XCTAssertNil(Holidays.dates(year: 2026, region: .nationwide)[LocalDate(2026, 12, 24)])
    }

    func testChristmasSkipsWeekendsAndHolidays() {
        let plan = VacationPlanner.plan(from: LocalDate(2026, 12, 24), to: LocalDate(2027, 1, 4),
                                        schedule: schedule, region: .bavaria, existing: [:])
        XCTAssertEqual(booked(plan), [LocalDate(2026, 12, 24), LocalDate(2026, 12, 28), LocalDate(2026, 12, 29),
                                      LocalDate(2026, 12, 30), LocalDate(2026, 12, 31), LocalDate(2027, 1, 4)])
        XCTAssertEqual(plan.count, 12)
        XCTAssertEqual(plan.first { $0.date == LocalDate(2026, 12, 25) }?.status, .holiday("1. Weihnachtstag"))
        XCTAssertEqual(plan.first { $0.date == LocalDate(2026, 12, 26) }?.status, .holiday("2. Weihnachtstag"))
        XCTAssertEqual(plan.first { $0.date == LocalDate(2026, 12, 27) }?.status, .weekend)
    }

    func testThreeWeekBlock() {
        let plan = VacationPlanner.plan(from: LocalDate(2031, 9, 1), to: LocalDate(2031, 9, 19),
                                        schedule: schedule, region: .bavaria, existing: [:])
        XCTAssertEqual(booked(plan).count, 15)
    }

    func testWorkdayCountSkipsWhitMonday() {
        let plan = VacationPlanner.plan(from: LocalDate(2031, 5, 26), workdays: 10,
                                        schedule: schedule, region: .bavaria, existing: [:])
        XCTAssertEqual(booked(plan).count, 10)
        XCTAssertEqual(plan.first { $0.date == LocalDate(2031, 6, 2) }?.status, .holiday("Pfingstmontag"))
        XCTAssertEqual(booked(plan).last, LocalDate(2031, 6, 9))
        XCTAssertEqual(plan.last?.date, LocalDate(2031, 6, 9))
    }

    func testStartOnWeekendStillCountsWorkdays() {
        let plan = VacationPlanner.plan(from: LocalDate(2026, 10, 3), workdays: 1,
                                        schedule: schedule, region: .bavaria, existing: [:])
        XCTAssertEqual(booked(plan), [LocalDate(2026, 10, 5)])
    }

    func testExistingEntriesAreNotBooked() {
        let existing = [LocalDate(2026, 10, 6): DayRecord(date: LocalDate(2026, 10, 6), targetSeconds: 8 * 3600,
                                                           entries: [TimeEntry(kind: .work, startSeconds: 0, endSeconds: 3600)])]
        let plan = VacationPlanner.plan(from: LocalDate(2026, 10, 5), to: LocalDate(2026, 10, 7),
                                        schedule: schedule, region: .bavaria, existing: existing)
        XCTAssertEqual(booked(plan), [LocalDate(2026, 10, 5), LocalDate(2026, 10, 7)])
        XCTAssertEqual(plan[1].status, .hasEntries)
    }

    func testExistingEmptyDayIsBooked() {
        let existing = [LocalDate(2026, 10, 6): DayRecord(date: LocalDate(2026, 10, 6), targetSeconds: 8 * 3600, entries: [])]
        let plan = VacationPlanner.plan(from: LocalDate(2026, 10, 6), to: LocalDate(2026, 10, 6),
                                        schedule: schedule, region: .bavaria, existing: existing)
        XCTAssertEqual(booked(plan), [LocalDate(2026, 10, 6)])
    }

    func testReversedRangeAndZeroCountAreEmpty() {
        XCTAssertTrue(VacationPlanner.plan(from: LocalDate(2026, 10, 7), to: LocalDate(2026, 10, 5),
                                           schedule: schedule, region: .bavaria, existing: [:]).isEmpty)
        XCTAssertTrue(VacationPlanner.plan(from: LocalDate(2026, 10, 7), workdays: 0,
                                           schedule: schedule, region: .bavaria, existing: [:]).isEmpty)
    }

    func testScheduleWithoutWorkdaysDoesNotLoopForever() {
        let plan = VacationPlanner.plan(from: LocalDate(2026, 10, 5), workdays: 3,
                                        schedule: WeekSchedule(days: [:]), region: .bavaria, existing: [:])
        XCTAssertTrue(booked(plan).isEmpty)
    }
}
