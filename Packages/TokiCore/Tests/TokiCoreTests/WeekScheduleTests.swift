import XCTest
@testable import TokiCore

final class WeekScheduleTests: XCTestCase {
    func testStandardIsHalfPastEightToHalfPastFourMondayToThursday() {
        let monday = WeekSchedule.standard.days[2]
        XCTAssertEqual(monday?.startSeconds, 8 * 3600 + 1800)
        XCTAssertEqual(monday?.endSeconds, 16 * 3600 + 1800)
        XCTAssertEqual(monday?.targetSeconds, 8 * 3600)
        XCTAssertEqual(WeekSchedule.standard.days[6]?.targetSeconds, 5 * 3600)
    }

    func testWorkEntryUsesTheWeekdayTemplate() {
        let entry = WeekSchedule.standard.workEntry(for: LocalDate(2026, 10, 19)) // Monday
        XCTAssertEqual(entry.kind, .work)
        XCTAssertEqual(entry.startSeconds, 8 * 3600 + 1800)
        XCTAssertEqual(entry.endSeconds, 16 * 3600 + 1800)
    }

    func testWorkEntryOnWeekendFallsBackToFirstWorkday() {
        let entry = WeekSchedule.standard.workEntry(for: LocalDate(2026, 10, 24)) // Saturday
        XCTAssertEqual(entry.startSeconds, 8 * 3600 + 1800)
        XCTAssertEqual(entry.endSeconds, 16 * 3600 + 1800)
        XCTAssertEqual(WeekSchedule.standard.targetSeconds(for: LocalDate(2026, 10, 24)), 0)
    }

    func testWorkEntryWithEmptyScheduleUsesHalfPastEightToHalfPastFour() {
        let entry = WeekSchedule(days: [:]).workEntry(for: LocalDate(2026, 10, 19))
        XCTAssertEqual(entry.startSeconds, 8 * 3600 + 1800)
        XCTAssertEqual(entry.endSeconds, 16 * 3600 + 1800)
    }

    func testWorkFactoryKeepsDayTimes() {
        let entry = TimeEntry.work(start: 9 * 3600, end: 17 * 3600, breakSeconds: 1800)
        XCTAssertEqual(entry.startSeconds, 9 * 3600)
        XCTAssertEqual(entry.endSeconds, 17 * 3600)
        XCTAssertEqual(entry.workedSeconds, 7 * 3600 + 1800)
    }

    func testWorkFactoryMovesEndBeforeStartToNextDay() {
        let entry = TimeEntry.work(start: 22 * 3600, end: 2 * 3600, breakSeconds: 0)
        XCTAssertEqual(entry.endSeconds, 26 * 3600)
        XCTAssertEqual(entry.workedSeconds, 4 * 3600)
    }

    func testWorkFactoryWrapsTimesGivenAfterMidnight() {
        let entry = TimeEntry.work(start: 8 * 3600, end: 26 * 3600 + 86400, breakSeconds: 0)
        XCTAssertEqual(entry.endSeconds, 26 * 3600)
    }

    func testWorkFactoryEqualTimesIsZeroHours() {
        XCTAssertEqual(TimeEntry.work(start: 8 * 3600, end: 8 * 3600, breakSeconds: 0).workedSeconds, 0)
    }
}
