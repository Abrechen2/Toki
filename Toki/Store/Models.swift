import Foundation
import SwiftData
import TokiCore

/// One stored day. Only days that differ from an untouched schedule day are stored.
@Model
final class DayModel {
    @Attribute(.unique) var key: String
    var targetSeconds: Int
    var creditNote: String?
    var adjustmentSeconds: Int
    @Relationship(deleteRule: .cascade, inverse: \EntryModel.day) var entries: [EntryModel] = []

    init(key: String, targetSeconds: Int, creditNote: String?, adjustmentSeconds: Int) {
        self.key = key
        self.targetSeconds = targetSeconds
        self.creditNote = creditNote
        self.adjustmentSeconds = adjustmentSeconds
    }

    var record: DayRecord? {
        guard let date = LocalDate(iso: key) else { return nil }
        return DayRecord(date: date, targetSeconds: targetSeconds,
                         entries: entries.sorted { $0.order < $1.order }.map(\.entry),
                         credit: creditNote.map(Credit.init(note:)),
                         adjustmentSeconds: adjustmentSeconds)
    }
}

@Model
final class EntryModel {
    var id: UUID
    var order: Int
    var kindRaw: String
    var startSeconds: Int?
    var endSeconds: Int?
    var breakSeconds: Int
    var note: String
    /// JSON of `EntryOrigin`; nil for entries made by hand.
    var originJSON: Data?
    var day: DayModel?

    init(_ entry: TimeEntry, order: Int) {
        id = entry.id
        self.order = order
        kindRaw = entry.kind.rawValue
        startSeconds = entry.startSeconds
        endSeconds = entry.endSeconds
        breakSeconds = entry.breakSeconds
        note = entry.note
        originJSON = entry.origin.flatMap { try? JSONEncoder().encode($0) }
    }

    var entry: TimeEntry {
        TimeEntry(id: id, kind: EntryKind(rawValue: kindRaw) ?? .work, startSeconds: startSeconds,
                  endSeconds: endSeconds, breakSeconds: breakSeconds, note: note,
                  origin: originJSON.flatMap { try? JSONDecoder().decode(EntryOrigin.self, from: $0) })
    }
}

/// Settings as one JSON blob, so new settings never need a schema migration.
@Model
final class SettingsModel {
    var json: Data

    init(json: Data) { self.json = json }
}

/// One stay inside the office geofence (raw log behind automatic entries).
@Model
final class VisitModel {
    var arrival: Date
    var departure: Date?

    init(arrival: Date, departure: Date?) {
        self.arrival = arrival
        self.departure = departure
    }

    var visit: Visit { Visit(arrival: arrival, departure: departure) }
}
