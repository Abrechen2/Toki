import Foundation

/// Semicolon-separated, German decimals (opens directly in German Excel/Numbers).
/// One row per entry; day values (target, overtime, credit) only on the day's first row.
public enum CSVExport {
    static let header = "Datum;Wochentag;Art;Beginn;Ende;Pause;Soll;Ist;Überstunden;Gutschrift;Notiz"
    static let weekdays = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]

    public static func make(days: [DayRecord]) -> String {
        var lines = [header]
        for day in days.sorted(by: { $0.date < $1.date }) {
            let entries: [TimeEntry?] = day.entries.isEmpty ? [nil] : day.entries
            for (index, entry) in entries.enumerated() {
                let first = index == 0
                let correction = first ? day.vacationCorrection.map { c in
                    "Urlaubskorrektur \(c.days > 0 ? "+" : "")\(HoursFormat.days(c.days))" + (c.note.isEmpty ? "" : " (\(c.note))")
                } : nil
                let notes = [entry?.note, first ? day.credit?.note : nil, correction].compactMap { $0 }.filter { !$0.isEmpty }
                let kind = entry.map { $0.dayFraction == 0.5 ? "½ \($0.kind.exportName)" : $0.kind.exportName } ?? ""
                let fields: [String] = [
                    day.date.german,
                    weekdays[day.date.weekday - 1],
                    kind,
                    entry?.startSeconds.map(HoursFormat.clock) ?? "",
                    entry?.endSeconds.map(HoursFormat.clock) ?? "",
                    entry.map { HoursFormat.decimal($0.breakSeconds) } ?? "",
                    first ? HoursFormat.decimal(Calculator.effectiveTarget(day)) : "",
                    entry.map { HoursFormat.decimal($0.workedSeconds) } ?? "",
                    first ? HoursFormat.decimal(Calculator.overtime(day)) : "",
                    first ? day.credit.map { HoursFormat.days($0.days) } ?? "" : "",
                    notes.joined(separator: " · "),
                ]
                lines.append(fields.map(escape).joined(separator: ";"))
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == ";" || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
