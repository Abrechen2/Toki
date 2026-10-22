import Foundation

/// Full database as JSON (own backup format, independent of SwiftData).
public struct Snapshot: Codable, Hashable, Sendable {
    public var version: Int
    public var settings: Settings
    public var days: [DayRecord]

    public init(settings: Settings, days: [DayRecord]) {
        self.version = 1
        self.settings = settings
        self.days = days.sorted { $0.date < $1.date }
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Decodes and rejects files with values no real day can have (they could overflow later).
    public static func decode(_ data: Data) throws -> Snapshot {
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
        guard Limits.isValid(snapshot.settings) else { throw SnapshotError.invalidSettings }
        if let bad = snapshot.days.first(where: { !Limits.isValid($0) }) { throw SnapshotError.invalidDay(bad.date) }
        return snapshot
    }
}

/// Repeatable import: incoming days replace days with the same date; a credit set in
/// Toki survives when the incoming day carries none (myTime cannot have credits).
public enum DayMerge {
    public static func merge(existing: [DayRecord], incoming: [DayRecord]) -> [DayRecord] {
        var byDate = Dictionary(existing.map { ($0.date, $0) }, uniquingKeysWith: { _, last in last })
        for day in incoming {
            var merged = day
            if merged.credit == nil { merged.credit = byDate[day.date]?.credit }
            if merged.vacationCorrection == nil { merged.vacationCorrection = byDate[day.date]?.vacationCorrection }
            if let old = byDate[day.date], old.entries.map(\.withoutID) == day.entries.map(\.withoutID) {
                merged.entries = old.entries
            }
            byDate[day.date] = merged
        }
        return byDate.values.sorted { $0.date < $1.date }
    }
}

extension TimeEntry {
    /// Content equality ignoring the generated id, so re-imports compare equal.
    var withoutID: TimeEntry {
        var copy = self
        copy.id = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        return copy
    }
}
