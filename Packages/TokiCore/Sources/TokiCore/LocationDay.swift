import Foundation

/// One stay inside the office geofence; `departure` is nil while still inside.
public struct Visit: Codable, Hashable, Sendable {
    public var arrival: Date
    public var departure: Date?

    public init(arrival: Date, departure: Date?) {
        self.arrival = arrival
        self.departure = departure
    }
}

/// Turns geofence visits into the automatic work entry of a day:
/// start = first arrival, end = last departure, both rounded to 5 minutes; visits under one hour
/// are ignored; odd results are kept but flagged as uncertain.
public enum LocationDay {
    public static let minimumVisit: TimeInterval = 3600
    public static let rounding = 300
    static let longDay = 12 * 3600
    static let earliestStart = 5 * 3600
    static let latestEnd = 22 * 3600

    public static func entry(for date: LocalDate, visits: [Visit], now: Date, calendar: Calendar,
                             schedule: WeekSchedule, region: HolidayRegion) -> TimeEntry? {
        let dayVisits = visits.filter { LocalDate(date: $0.arrival, calendar: calendar) == date }
            .sorted { $0.arrival < $1.arrival }
        let open = dayVisits.last.flatMap { $0.departure == nil ? $0 : nil }
        let counted = dayVisits.filter { visit in
            guard let departure = visit.departure else { return false }
            return departure.timeIntervalSince(visit.arrival) >= minimumVisit
        }
        let relevant = counted + (open.map { [$0] } ?? [])
        guard let first = relevant.min(by: { $0.arrival < $1.arrival }) else { return nil }

        let start = rounded(seconds(of: first.arrival, from: date, calendar: calendar))
        var end: Int?
        if open == nil, let last = counted.compactMap(\.departure).max() {
            end = rounded(seconds(of: last, from: date, calendar: calendar))
        }

        var reasons: [UncertainReason] = []
        if open != nil && LocalDate(date: now, calendar: calendar) != date { reasons.append(.missingEnd) }
        if let end {
            if end > 86400 { reasons.append(.overnight) }
            if end - start > longDay { reasons.append(.longDay) }
        }
        if start < earliestStart || (end ?? 0) > latestEnd { reasons.append(.unusualTime) }
        if schedule.targetSeconds(for: date) == 0 || Holidays.dates(year: date.year, region: region)[date] != nil {
            reasons.append(.nonWorkday)
        }

        return TimeEntry(kind: .work, startSeconds: start, endSeconds: end,
                         breakSeconds: end == nil ? 0 : schedule.days[date.weekday]?.breakSeconds ?? 0,
                         origin: EntryOrigin(source: .location, uncertain: reasons))
    }

    /// Seconds from local midnight of `date` (wall clock, so DST days stay correct); later days add 24 h each.
    static func seconds(of instant: Date, from date: LocalDate, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: instant)
        let days = date.days(until: LocalDate(date: instant, calendar: calendar))
        return days * 86400 + (parts.hour ?? 0) * 3600 + (parts.minute ?? 0) * 60 + (parts.second ?? 0)
    }

    static func rounded(_ seconds: Int) -> Int {
        (seconds + rounding / 2) / rounding * rounding
    }
}

extension TimeEntry {
    /// Compares what the geofence decides (times, break, flags), ignoring id and the owner's note.
    public var withoutIDAndNote: TimeEntry {
        var copy = self
        copy.id = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        copy.note = ""
        return copy
    }
}
