import Foundation

/// Conversions for numbers that come from files. `Int(Double)` traps on NaN, infinity and values
/// outside Int's range, so everything from outside goes through here.
public enum Safe {
    /// Hours → whole seconds, or nil when not finite or outside 0...limit (±limit if negative allowed).
    public static func seconds(hours: Double, limitHours: Double, allowNegative: Bool = false) -> Int? {
        guard hours.isFinite, abs(hours) <= limitHours, allowNegative || hours >= 0 else { return nil }
        return Int((hours * 3600).rounded())
    }

    /// Time interval → whole seconds, or nil when not finite or outside the range.
    public static func seconds(interval: TimeInterval, in range: ClosedRange<Double>) -> Int? {
        guard interval.isFinite, range.contains(interval) else { return nil }
        return Int(interval.rounded())
    }
}

public enum SnapshotError: Error, Equatable {
    case invalidSettings
    case invalidDay(LocalDate)
}

/// Limits a stored value may have; anything outside means a broken or manipulated file.
enum Limits {
    static let day = 86400
    static let maxOvertimeSeconds = 100_000 * 3600
    static let maxAdjustmentSeconds = 1000 * 3600

    static func isValid(_ settings: Settings) -> Bool {
        guard abs(settings.initialOvertimeSeconds) <= maxOvertimeSeconds,
              settings.anchor.value.isFinite, abs(settings.anchor.value) <= 10_000,
              settings.entitlementPerYear.isFinite, (0...366).contains(settings.entitlementPerYear),
              settings.schedule.days.allSatisfy({ (1...7).contains($0.key) && isValid($0.value) }) else { return false }
        if let office = settings.office {
            guard office.latitude.isFinite, (-90...90).contains(office.latitude),
                  office.longitude.isFinite, (-180...180).contains(office.longitude),
                  office.radius.isFinite, (1...10_000).contains(office.radius) else { return false }
        }
        return true
    }

    static func isValid(_ template: DayTemplate) -> Bool {
        (0...day).contains(template.targetSeconds) && (0...(2 * day)).contains(template.startSeconds)
            && (0...(2 * day)).contains(template.endSeconds) && (0...day).contains(template.breakSeconds)
    }

    static func isValid(_ record: DayRecord) -> Bool {
        (0...day).contains(record.targetSeconds) && abs(record.adjustmentSeconds) <= maxAdjustmentSeconds
            && record.entries.allSatisfy(isValid)
    }

    static func isValid(_ entry: TimeEntry) -> Bool {
        if let start = entry.startSeconds, !(0..<(2 * day)).contains(start) { return false }
        if let end = entry.endSeconds, !(0...(4 * day)).contains(end) { return false }
        return (0...day).contains(entry.breakSeconds)
    }
}
