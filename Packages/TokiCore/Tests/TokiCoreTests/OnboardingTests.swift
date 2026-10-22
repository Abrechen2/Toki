import XCTest
@testable import TokiCore

final class OnboardingTests: XCTestCase {
    func testLegalBreakFollowsTheWorkingTimeAct() {
        XCTAssertEqual(WeekSchedule.legalBreakSeconds(forTarget: 6 * 3600), 0)
        XCTAssertEqual(WeekSchedule.legalBreakSeconds(forTarget: 6 * 3600 + 60), 1800)
        XCTAssertEqual(WeekSchedule.legalBreakSeconds(forTarget: 9 * 3600), 1800)
        XCTAssertEqual(WeekSchedule.legalBreakSeconds(forTarget: 9 * 3600 + 60), 2700)
    }

    func testUniformScheduleMondayToFriday() {
        let schedule = WeekSchedule.uniform(weekdays: [2, 3, 4, 5, 6], targetSeconds: 8 * 3600, startSeconds: 8 * 3600)
        XCTAssertEqual(schedule.days.keys.sorted(), [2, 3, 4, 5, 6])
        let monday = schedule.days[2]
        XCTAssertEqual(monday?.targetSeconds, 8 * 3600)
        XCTAssertEqual(monday?.breakSeconds, 1800)
        XCTAssertEqual(monday?.endSeconds, 16 * 3600 + 1800, "end = start + target + break")
        XCTAssertNil(schedule.days[7])
    }

    func testShortDayHasNoBreak() {
        let schedule = WeekSchedule.uniform(weekdays: [2], targetSeconds: 4 * 3600, startSeconds: 9 * 3600)
        XCTAssertEqual(schedule.days[2]?.breakSeconds, 0)
        XCTAssertEqual(schedule.days[2]?.endSeconds, 13 * 3600)
    }

    func testRemainingVacationTodayBecomesTheAnchor() {
        let anchor = VacationAnchor.remaining(12, today: LocalDate(2031, 3, 10))
        XCTAssertEqual(anchor.date, LocalDate(2031, 3, 9))
        var settings = Settings.default
        settings.anchor = anchor
        let ledger = VacationLedger(days: [], settings: settings)
        XCTAssertEqual(ledger.balance(on: LocalDate(2031, 3, 10)), 12)
        XCTAssertEqual(ledger.balance(on: LocalDate(2032, 1, 1)), 42)
    }

    func testRemainingVacationOnFirstOfJanuaryIsNotCountedTwice() {
        var settings = Settings.default
        settings.anchor = VacationAnchor.remaining(30, today: LocalDate(2031, 1, 1))
        XCTAssertEqual(VacationLedger(days: [], settings: settings).balance(on: LocalDate(2031, 1, 1)), 30)
    }
}
