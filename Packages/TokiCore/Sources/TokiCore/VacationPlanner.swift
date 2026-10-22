import Foundation

public struct PlannedDay: Hashable, Sendable, Identifiable {
    public enum Status: Hashable, Sendable {
        case book
        case weekend
        case holiday(String)
        case hasEntries
    }

    public var date: LocalDate
    public var status: Status
    public var id: LocalDate { date }
}

/// Quick vacation entry: turns a date range (or a number of workdays) into the days to book.
/// A day is booked when the schedule has a target for its weekday, it is no public holiday
/// and it has no entries yet. Nothing existing is ever overwritten.
public enum VacationPlanner {
    /// Upper bound for scanning, so a schedule without workdays cannot loop forever.
    static let maxDays = 400

    public static func plan(from start: LocalDate, to end: LocalDate, schedule: WeekSchedule,
                            region: HolidayRegion, existing: [LocalDate: DayRecord]) -> [PlannedDay] {
        guard start <= end else { return [] }
        var result: [PlannedDay] = []
        var date = start
        var holidays = HolidayCache(region: region)
        while date <= end, result.count < maxDays {
            result.append(PlannedDay(date: date, status: status(date, schedule, &holidays, existing)))
            date = date.adding(days: 1)
        }
        return result
    }

    /// Plans from `start` until `workdays` days are booked; the result ends on the last booked day.
    public static func plan(from start: LocalDate, workdays: Int, schedule: WeekSchedule,
                            region: HolidayRegion, existing: [LocalDate: DayRecord]) -> [PlannedDay] {
        guard workdays > 0 else { return [] }
        var result: [PlannedDay] = []
        var booked = 0
        var date = start
        var holidays = HolidayCache(region: region)
        while booked < workdays, result.count < maxDays {
            let status = status(date, schedule, &holidays, existing)
            result.append(PlannedDay(date: date, status: status))
            if status == .book { booked += 1 }
            date = date.adding(days: 1)
        }
        guard booked > 0 else { return result }
        while let last = result.last, last.status != .book { result.removeLast() }
        return result
    }

    private static func status(_ date: LocalDate, _ schedule: WeekSchedule, _ holidays: inout HolidayCache,
                               _ existing: [LocalDate: DayRecord]) -> PlannedDay.Status {
        if let name = holidays.name(for: date) { return .holiday(name) }
        if schedule.targetSeconds(for: date) == 0 { return .weekend }
        if let day = existing[date], !day.entries.isEmpty { return .hasEntries }
        return .book
    }
}

struct HolidayCache {
    let region: HolidayRegion
    private var years: [Int: [LocalDate: String]] = [:]

    init(region: HolidayRegion) { self.region = region }

    mutating func name(for date: LocalDate) -> String? {
        if years[date.year] == nil { years[date.year] = Holidays.dates(year: date.year, region: region) }
        return years[date.year]?[date]
    }
}
