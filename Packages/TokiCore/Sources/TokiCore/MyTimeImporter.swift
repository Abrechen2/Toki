import Foundation

public struct ImportSummary: Hashable, Sendable {
    public var dayCount: Int
    public var entryCount: Int
    public var firstDate: LocalDate?
    public var lastDate: LocalDate?
    /// Initial balance + all days, as myTime shows it.
    public var overtimeSeconds: Int
    public var vacationDaysTaken: Int
    /// Remaining vacation on the backup's export date, as myTime shows it.
    public var vacationRemaining: Double
    public var creditCandidates: Int
    public var warnings: [String]
}

public struct MyTimeImport: Sendable {
    public var settings: Settings
    public var days: [DayRecord]
    public var summary: ImportSummary
}

public enum MyTimeImportError: Error, Equatable {
    case notJSON
    case notAMyTimeBackup
}

/// Reads a `.mytimebackup` (plain JSON, see docs/mytime-backup-format.md).
public enum MyTimeImporter {
    static let berlin: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    public static func parse(_ data: Data, base: Settings = .default) throws -> MyTimeImport {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MyTimeImportError.notJSON
        }
        guard let jobs = root["jobsBackup"] as? [[String: Any]], let jobBackup = jobs.first,
              let years = root["yearsBackup"] as? [[String: Any]] else {
            throw MyTimeImportError.notAMyTimeBackup
        }
        var warnings: [String] = []
        let settings = parseSettings(jobBackup, base: base, warnings: &warnings)
        var byDate: [LocalDate: DayRecord] = [:]
        for year in years {
            for month in year["timeMonths"] as? [[String: Any]] ?? [] {
                for rawDay in month["days"] as? [[String: Any]] ?? [] {
                    guard let midnight = instant(rawDay["date"]) else { continue }
                    let date = LocalDate(date: midnight, calendar: berlin)
                    let entries = (rawDay["entries"] as? [[String: Any]] ?? []).compactMap {
                        parseEntry($0, midnight: midnight, date: date, warnings: &warnings)
                    }
                    let target = hours(rawDay["plannedHoursOfDay_value"], limit: 24) ?? {
                        warnings.append("\(date.german): Soll-Stunden unlesbar, als 0 übernommen")
                        return 0
                    }()
                    if var existing = byDate[date] {
                        existing.entries += entries
                        byDate[date] = existing
                    } else {
                        byDate[date] = DayRecord(date: date, targetSeconds: target, entries: entries)
                    }
                }
            }
        }
        let days = byDate.values.sorted { $0.date < $1.date }
        let exportDay = instant(root["exportDate"]).map { LocalDate(date: $0, calendar: berlin) }
            ?? days.last?.date ?? LocalDate.today()
        let summary = ImportSummary(
            dayCount: days.count,
            entryCount: days.reduce(0) { $0 + $1.entries.count },
            firstDate: days.first?.date,
            lastDate: days.last?.date,
            overtimeSeconds: OvertimeAccount.total(days: days, settings: settings),
            vacationDaysTaken: Calculator.count(.vacation, in: days),
            vacationRemaining: VacationLedger(days: days, settings: settings).balance(on: exportDay),
            creditCandidates: CreditCandidates.find(in: days).count,
            warnings: warnings
        )
        return MyTimeImport(settings: settings, days: days, summary: summary)
    }

    private static func parseSettings(_ backup: [String: Any], base: Settings, warnings: inout [String]) -> Settings {
        var settings = base
        let job = backup["job"] as? [String: Any] ?? [:]
        if let name = job["name_value"] as? String { settings.jobName = name }
        let config = job["configuration_value"] as? [String: Any] ?? [:]
        if let overtime = config["overtimeConfig_value"] as? [String: Any] {
            settings.initialOvertimeSeconds = hours(overtime["initialOvertimeHours_value"], limit: 100_000, negative: true) ?? {
                warnings.append("Überstunden-Startwert unlesbar, als 0 übernommen")
                return 0
            }()
        }
        if let vacation = config["vacationConfig_value"] as? [String: Any] {
            if let perYear = number(vacation["vacationDaysPerYear_value"]), perYear.isFinite, (0...366).contains(perYear) {
                settings.entitlementPerYear = perYear
            }
            let renewal = instant(vacation["vacationDaysRenewalDate_value"])
                .map { LocalDate(date: $0, calendar: berlin) } ?? LocalDate.today()
            // myTime also grants the year before the renewal date (format doc), so the anchor is
            // 31 December two years before it.
            settings.anchor = VacationAnchor(
                value: number(vacation["initialVacationDays_value"]).flatMap { $0.isFinite && abs($0) <= 10_000 ? $0 : nil } ?? 0,
                date: LocalDate(renewal.year - 2, 12, 31),
                note: "myTime-Import: Anfangsbestand"
            )
        }
        var schedule: [Int: DayTemplate] = [:]
        for day in backup["defaultDays"] as? [[String: Any]] ?? [] {
            guard let weekday = day["weekday"] as? Int, (1...7).contains(weekday) else { continue }
            guard let target = hours(day["plannedHoursOfDay_value"], limit: 24),
                  let start = hours(day["startTime_value"], limit: 48),
                  let end = hours(day["endTime_value"], limit: 48),
                  let breaks = breakSeconds(day["breakEntries_value"]) else {
                warnings.append("Standardwerte für Wochentag \(weekday) unlesbar, übersprungen")
                continue
            }
            guard target > 0 else { continue }
            schedule[weekday] = DayTemplate(targetSeconds: target, startSeconds: start, endSeconds: end, breakSeconds: breaks)
        }
        if !schedule.isEmpty { settings.schedule = WeekSchedule(days: schedule) }
        return settings
    }

    private static func parseEntry(_ raw: [String: Any], midnight: Date, date: LocalDate,
                                   warnings: inout [String]) -> TimeEntry? {
        let type = raw["entryType_value"] as? [String: Any] ?? [:]
        let start = instant(raw["startDate_value"])
        let end = instant(raw["endDate_value"])
        let note = raw["note_value"] as? String ?? ""
        let name = (type["nameOnExport_value"] as? String) ?? (type["name_value"] as? String) ?? "?"
        let kind: EntryKind
        if let mapped = kindFor(name: name, category: type["category_value"] as? Int) {
            kind = mapped
        } else if start != nil {
            kind = .work
            warnings.append("\(date.german): „\(name)“ als Arbeit übernommen")
        } else {
            warnings.append("\(date.german): „\(name)“ übersprungen")
            return nil
        }
        guard kind == .work, let start, let end else {
            return TimeEntry(kind: kind, note: note)
        }
        // Start within two days of the day, end within four, break at most a day: anything else
        // is a broken file and would overflow later.
        guard let startSeconds = Safe.seconds(interval: start.timeIntervalSince(midnight), in: 0...(2 * 86400 - 1)),
              let endSeconds = Safe.seconds(interval: end.timeIntervalSince(midnight), in: 0...(4 * 86400)),
              let breaks = breakSeconds(raw["breakEntries_value"]) else {
            warnings.append("\(date.german): Eintrag mit unmöglichen Zeiten übersprungen")
            return nil
        }
        return TimeEntry(kind: .work, startSeconds: startSeconds, endSeconds: endSeconds, breakSeconds: breaks, note: note)
    }

    static func kindFor(name: String, category: Int?) -> EntryKind? {
        let lower = name.lowercased()
        if lower.contains("überstundenabbau") { return .overtimeReduction }
        if lower.contains("sonderurlaub") { return .specialLeave }
        if lower.contains("urlaub") { return .vacation }
        if lower.contains("kind") { return .childSick }
        if lower.contains("krank") { return .sick }
        if lower.contains("feiertag") { return .publicHoliday }
        if category == 1 { return .work }
        return nil
    }

    private static let isoFormatter: ISO8601DateFormatter = ISO8601DateFormatter()

    private static func instant(_ value: Any?) -> Date? {
        (value as? String).flatMap { isoFormatter.date(from: $0) }
    }

    private static func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    /// Missing values count as 0; present but impossible values give nil.
    private static func hours(_ value: Any?, limit: Double, negative: Bool = false) -> Int? {
        guard let value = number(value) else { return 0 }
        return Safe.seconds(hours: value, limitHours: limit, allowNegative: negative)
    }

    /// Sum of the break entries, at most one day; nil when any value is impossible.
    private static func breakSeconds(_ value: Any?) -> Int? {
        var total = 0
        for entry in value as? [[String: Any]] ?? [] {
            guard let seconds = hours(entry["totalHours_value"], limit: 24) else { return nil }
            total += seconds
        }
        return total <= 86400 ? total : nil
    }
}
