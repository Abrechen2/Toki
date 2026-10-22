import Foundation

/// A calendar day without time or time zone. All arithmetic runs in UTC so DST never shifts a day.
public struct LocalDate: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(_ year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses `yyyy-MM-dd`; returns nil for impossible dates such as 2025-02-29.
    public init?(iso: String) {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let candidate = LocalDate(parts[0], parts[1], parts[2])
        guard let date = LocalDate.utc.date(from: candidate.components),
              LocalDate(date: date, calendar: LocalDate.utc) == candidate else { return nil }
        self = candidate
    }

    /// The calendar day of `date` as seen in `calendar`'s time zone.
    public init(date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(c.year!, c.month!, c.day!)
    }

    public static func today(calendar: Calendar = .current) -> LocalDate {
        LocalDate(date: Date(), calendar: calendar)
    }

    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private var components: DateComponents {
        DateComponents(year: year, month: month, day: day, hour: 12)
    }

    /// Noon UTC of this day; stable key for Foundation APIs.
    public var utcNoon: Date { LocalDate.utc.date(from: components)! }

    /// Midnight of this day in `calendar`'s time zone (for DatePicker and formatting).
    public func date(in calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Apple numbering: 1 = Sunday … 7 = Saturday.
    public var weekday: Int { LocalDate.utc.component(.weekday, from: utcNoon) }

    public var isWeekend: Bool { weekday == 1 || weekday == 7 }

    public func adding(days: Int) -> LocalDate {
        LocalDate(date: LocalDate.utc.date(byAdding: .day, value: days, to: utcNoon)!, calendar: LocalDate.utc)
    }

    public func days(until other: LocalDate) -> Int {
        LocalDate.utc.dateComponents([.day], from: utcNoon, to: other.utcNoon).day!
    }

    public var firstOfMonth: LocalDate { LocalDate(year, month, 1) }

    public var daysInMonth: Int {
        LocalDate.utc.range(of: .day, in: .month, for: utcNoon)!.count
    }

    public var lastOfMonth: LocalDate { LocalDate(year, month, daysInMonth) }

    public func addingMonths(_ months: Int) -> LocalDate {
        LocalDate(date: LocalDate.utc.date(byAdding: .month, value: months, to: firstOfMonth.utcNoon)!,
                  calendar: LocalDate.utc)
    }

    public var iso: String { String(format: "%04d-%02d-%02d", year, month, day) }

    /// German short form, e.g. `05.01.2026`.
    public var german: String { String(format: "%02d.%02d.%04d", day, month, year) }

    public var description: String { iso }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let date = LocalDate(iso: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "invalid date \(text)")
        }
        self = date
    }
}
