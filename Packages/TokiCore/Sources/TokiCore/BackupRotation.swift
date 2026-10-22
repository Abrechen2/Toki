import Foundation

/// Naming and retention of the automatic backup files in the folder the owner picked.
public enum BackupRotation {
    public static let latestName = "Toki-Sicherung.json"
    public static let keepDays = 30
    private static let prefix = "Toki-Sicherung-"

    public static func dailyName(_ date: LocalDate) -> String { "\(prefix)\(date.iso).json" }

    /// Daily files older than `keepDays` (today included in the count); other files are never touched.
    public static func namesToDelete(existing: [String], today: LocalDate) -> [String] {
        let oldestKept = today.adding(days: -(keepDays - 1))
        return existing.filter { name in
            guard name.hasPrefix(prefix), name.hasSuffix(".json") else { return false }
            let datePart = String(name.dropFirst(prefix.count).dropLast(".json".count))
            guard let date = LocalDate(iso: datePart) else { return false }
            return date < oldestKept
        }.sorted()
    }

    /// An empty app (e.g. a fresh install before restoring) must not overwrite an existing backup.
    public static func shouldWrite(_ snapshot: Snapshot) -> Bool { !snapshot.days.isEmpty }
}
