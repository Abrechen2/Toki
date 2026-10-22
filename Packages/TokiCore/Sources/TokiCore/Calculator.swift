import Foundation

/// The day rules (see README, "How Toki calculates").
public enum Calculator {
    public static func worked(_ day: DayRecord) -> Int {
        day.entries.reduce(0) { $0 + $1.workedSeconds }
    }

    /// 0 on days without entries (myTime only counts entered days) and on absence days.
    public static func effectiveTarget(_ day: DayRecord) -> Int {
        if day.entries.isEmpty || day.entries.contains(where: { $0.kind.isAbsence }) { return 0 }
        return day.targetSeconds
    }

    /// A credited day contributes nothing; an overtime reduction day keeps its target and so shows −target.
    /// A day with a work entry still missing its end counts 0 until it is complete.
    public static func overtime(_ day: DayRecord) -> Int {
        if day.credit != nil || day.entries.contains(where: \.isIncomplete) { return 0 }
        return worked(day) - effectiveTarget(day) + day.adjustmentSeconds
    }

    public static func vacationDays(_ day: DayRecord) -> Double {
        Double(day.entries.filter { $0.kind == .vacation }.count)
    }

    public static func creditDays(_ day: DayRecord) -> Double {
        day.credit == nil ? 0 : 1
    }

    public static func count(_ kind: EntryKind, in days: [DayRecord]) -> Int {
        days.reduce(0) { $0 + $1.entries.filter { $0.kind == kind }.count }
    }
}

public enum OvertimeAccount {
    public static func total(days: [DayRecord], settings: Settings, through: LocalDate? = nil) -> Int {
        settings.initialOvertimeSeconds + sum(days.filter { through == nil || $0.date <= through! })
    }

    public static func sum(_ days: [DayRecord]) -> Int {
        days.reduce(0) { $0 + Calculator.overtime($1) }
    }
}
