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
                let notes = [entry?.note, first ? day.credit?.note : nil].compactMap { $0 }.filter { !$0.isEmpty }
                let fields: [String] = [
                    day.date.german,
                    weekdays[day.date.weekday - 1],
                    entry?.kind.exportName ?? "",
                    entry?.startSeconds.map(HoursFormat.clock) ?? "",
                    entry?.endSeconds.map(HoursFormat.clock) ?? "",
                    entry.map { HoursFormat.decimal($0.breakSeconds) } ?? "",
                    first ? HoursFormat.decimal(Calculator.effectiveTarget(day)) : "",
                    entry.map { HoursFormat.decimal($0.workedSeconds) } ?? "",
                    first ? HoursFormat.decimal(Calculator.overtime(day)) : "",
                    first && day.credit != nil ? "1" : "",
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
