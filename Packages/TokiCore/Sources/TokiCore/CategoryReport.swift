import Foundation

/// Entries of one category in a period, e.g. "work in Switzerland, October", with their total.
public struct CategoryReport: Sendable {
    public struct Row: Hashable, Sendable {
        public var date: LocalDate
        public var startSeconds: Int?
        public var endSeconds: Int?
        public var breakSeconds: Int
        public var durationSeconds: Int
        public var note: String
    }

    public let rows: [Row]
    public var totalSeconds: Int { rows.reduce(0) { $0 + $1.durationSeconds } }

    public init(days: [DayRecord], categoryID: UUID, from: LocalDate, to: LocalDate) {
        rows = days.filter { $0.date >= from && $0.date <= to }.sorted { $0.date < $1.date }.flatMap { day in
            day.entries.filter { $0.categoryID == categoryID }.map {
                Row(date: day.date, startSeconds: $0.startSeconds, endSeconds: $0.endSeconds,
                    breakSeconds: $0.breakSeconds, durationSeconds: $0.durationSeconds, note: $0.note)
            }
        }
    }

    /// Semicolon CSV with German decimals and a total line.
    public var csv: String {
        var lines = ["Datum;Wochentag;Beginn;Ende;Pause;Stunden;Notiz"]
        for row in rows {
            lines.append([row.date.german, CSVExport.weekdays[row.date.weekday - 1],
                          row.startSeconds.map(HoursFormat.clock) ?? "", row.endSeconds.map(HoursFormat.clock) ?? "",
                          HoursFormat.decimal(row.breakSeconds), HoursFormat.decimal(row.durationSeconds),
                          CSVExport.escape(row.note)].joined(separator: ";"))
        }
        lines.append("Summe;;;;;\(HoursFormat.decimal(totalSeconds));")
        return lines.joined(separator: "\n") + "\n"
    }
}
