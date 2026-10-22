import Foundation

public enum EntryKind: String, Codable, CaseIterable, Sendable {
    case work
    case vacation
    case sick
    case childSick
    case publicHoliday
    case specialLeave
    case overtimeReduction

    /// Day types that set the day's target to 0 (myTime stores target 0 on those days).
    public var isAbsence: Bool {
        switch self {
        case .vacation, .sick, .childSick, .publicHoliday, .specialLeave: return true
        case .work, .overtimeReduction: return false
        }
    }

    public var hasTimes: Bool { self == .work }

    /// German export name, matching myTime's `nameOnExport`.
    public var exportName: String {
        switch self {
        case .work: return "Arbeit"
        case .vacation: return "Urlaub"
        case .sick: return "Krankheit"
        case .childSick: return "Kind krank"
        case .publicHoliday: return "Feiertag"
        case .specialLeave: return "Sonderurlaub"
        case .overtimeReduction: return "Überstundenabbau"
        }
    }
}

public struct TimeEntry: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var kind: EntryKind
    /// Seconds from local midnight of the day; `end` may exceed 24 h for night shifts.
    public var startSeconds: Int?
    public var endSeconds: Int?
    public var breakSeconds: Int
    public var note: String
    /// nil = entered by hand (or confirmed); set for automatic entries.
    public var origin: EntryOrigin?

    public init(id: UUID = UUID(), kind: EntryKind, startSeconds: Int? = nil, endSeconds: Int? = nil,
                breakSeconds: Int = 0, note: String = "", origin: EntryOrigin? = nil) {
        self.id = id
        self.kind = kind
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.breakSeconds = breakSeconds
        self.note = note
        self.origin = origin
    }

    /// Work entry with a start but no end yet: still at the office, or the end is missing.
    public var isIncomplete: Bool { kind == .work && startSeconds != nil && endSeconds == nil }

    /// Automatic entry of a day that is still going on.
    public var isRunning: Bool { isIncomplete && origin != nil && origin?.uncertain.contains(.missingEnd) == false }

    /// Work entry from times of day; an end before the start means the shift ends after midnight.
    public static func work(start: Int, end: Int, breakSeconds: Int, note: String = "") -> TimeEntry {
        let day = 86400
        let start = start % day
        var end = end % day
        if end < start { end += day }
        return TimeEntry(kind: .work, startSeconds: start, endSeconds: end, breakSeconds: breakSeconds, note: note)
    }

    public var workedSeconds: Int {
        guard kind.hasTimes, let start = startSeconds, let end = endSeconds else { return 0 }
        return max(0, end - start - breakSeconds)
    }
}

/// Where an automatic entry came from and why it may be wrong.
public struct EntryOrigin: Codable, Hashable, Sendable {
    public enum Source: String, Codable, Sendable { case location }

    public var source: Source
    public var uncertain: [UncertainReason]

    public init(source: Source, uncertain: [UncertainReason]) {
        self.source = source
        self.uncertain = uncertain
    }
}

public enum UncertainReason: String, Codable, CaseIterable, Sendable {
    case missingEnd, overnight, longDay, unusualTime, nonWorkday
}

/// Whole extra vacation day earned on a day (the feature myTime lacks).
public struct Credit: Codable, Hashable, Sendable {
    public var note: String
    public init(note: String) { self.note = note }
}

public struct DayRecord: Codable, Hashable, Identifiable, Sendable {
    public var date: LocalDate
    /// Target frozen for this day; later schedule changes never rewrite it.
    public var targetSeconds: Int
    public var entries: [TimeEntry]
    public var credit: Credit?
    /// Manual correction of the overtime account on this day.
    public var adjustmentSeconds: Int

    public var id: LocalDate { date }

    public init(date: LocalDate, targetSeconds: Int, entries: [TimeEntry], credit: Credit? = nil,
                adjustmentSeconds: Int = 0) {
        self.date = date
        self.targetSeconds = targetSeconds
        self.entries = entries
        self.credit = credit
        self.adjustmentSeconds = adjustmentSeconds
    }
}

/// Default times and target for one weekday.
public struct DayTemplate: Codable, Hashable, Sendable {
    public var targetSeconds: Int
    public var startSeconds: Int
    public var endSeconds: Int
    public var breakSeconds: Int

    public init(targetSeconds: Int, startSeconds: Int, endSeconds: Int, breakSeconds: Int = 0) {
        self.targetSeconds = targetSeconds
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.breakSeconds = breakSeconds
    }
}

public struct WeekSchedule: Codable, Hashable, Sendable {
    /// Keyed by Apple weekday (1 = Sunday … 7 = Saturday); missing = no target.
    public var days: [Int: DayTemplate]

    public init(days: [Int: DayTemplate]) { self.days = days }

    public func targetSeconds(for date: LocalDate) -> Int { days[date.weekday]?.targetSeconds ?? 0 }

    /// Default work entry for one-tap booking. Days without a template (weekends) use the first
    /// workday's times from Monday on; an empty schedule falls back to 08:30–16:30.
    public func workEntry(for date: LocalDate) -> TimeEntry {
        let template = days[date.weekday]
            ?? [2, 3, 4, 5, 6, 7, 1].lazy.compactMap { days[$0] }.first
            ?? DayTemplate(targetSeconds: 28800, startSeconds: 30600, endSeconds: 59400)
        return TimeEntry(kind: .work, startSeconds: template.startSeconds, endSeconds: template.endSeconds,
                         breakSeconds: template.breakSeconds)
    }

    /// Mon–Thu 8 h 08:30–16:30, Fri 5 h 08:00–13:00.
    public static let standard: WeekSchedule = {
        let long = DayTemplate(targetSeconds: 28800, startSeconds: 30600, endSeconds: 59400)
        let short = DayTemplate(targetSeconds: 18000, startSeconds: 28800, endSeconds: 46800)
        return WeekSchedule(days: [2: long, 3: long, 4: long, 5: long, 6: short])
    }()
}

public struct VacationAnchor: Codable, Hashable, Sendable {
    /// Balance at the end of `date`.
    public var value: Double
    public var date: LocalDate
    public var note: String

    public init(value: Double, date: LocalDate, note: String) {
        self.value = value
        self.date = date
        self.note = note
    }
}

public struct Settings: Codable, Hashable, Sendable {
    public var jobName: String
    public var initialOvertimeSeconds: Int
    public var anchor: VacationAnchor
    public var entitlementPerYear: Double
    public var schedule: WeekSchedule
    public var holidayRegion: HolidayRegion
    /// Office for automatic entries by location; nil = off.
    public var office: OfficeLocation?

    public init(jobName: String, initialOvertimeSeconds: Int, anchor: VacationAnchor,
                entitlementPerYear: Double, schedule: WeekSchedule, holidayRegion: HolidayRegion,
                office: OfficeLocation? = nil) {
        self.office = office
        self.jobName = jobName
        self.initialOvertimeSeconds = initialOvertimeSeconds
        self.anchor = anchor
        self.entitlementPerYear = entitlementPerYear
        self.schedule = schedule
        self.holidayRegion = holidayRegion
    }

    public static let `default` = Settings(
        jobName: "",
        initialOvertimeSeconds: 0,
        anchor: VacationAnchor(value: 0, date: LocalDate(2025, 12, 31), note: ""),
        entitlementPerYear: 30,
        schedule: .standard,
        holidayRegion: .bavaria
    )
}

public struct OfficeLocation: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double
    /// Geofence radius in metres.
    public var radius: Double
    public var name: String
    /// Short notification when a start or end was recorded.
    public var notify: Bool
    /// When this place was set; nil for offices saved before this existed.
    public var since: Date?

    public init(latitude: Double, longitude: Double, radius: Double, name: String, notify: Bool, since: Date? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.name = name
        self.notify = notify
        self.since = since
    }

    /// An open stay that began before this place was set belongs to an earlier place.
    public func isStale(openArrival: Date) -> Bool {
        guard let since else { return true }
        return openArrival < since
    }

    /// Whether a geofence event belongs to this office (events for a replaced region can still arrive).
    public func matches(latitude: Double, longitude: Double) -> Bool {
        abs(self.latitude - latitude) < 1e-6 && abs(self.longitude - longitude) < 1e-6
    }

    /// Same geofence: position and radius; name and notifications do not matter.
    public func isSamePlace(as other: OfficeLocation?) -> Bool {
        guard let other else { return false }
        return matches(latitude: other.latitude, longitude: other.longitude) && radius == other.radius
    }
}
