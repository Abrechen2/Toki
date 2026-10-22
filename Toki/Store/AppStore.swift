import Foundation
import Observation
import SwiftData
import TokiCore
import UIKit

/// In-memory source of truth for the UI, written through to SwiftData on every change.
/// All numbers come from TokiCore.
@MainActor
@Observable
final class AppStore {
    private(set) var days: [LocalDate: DayRecord] = [:]
    private(set) var settings: Settings = .default
    var lastError: String?
    /// Increases with every saved change; drives the automatic backup.
    private(set) var revision = 0
    /// Short confirmation shown over the whole app ("Gespeichert"); survives closing a page.
    private(set) var toast: String?
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    @ObservationIgnored private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        load()
    }

    // MARK: Reading

    var sortedDays: [DayRecord] { days.values.sorted { $0.date < $1.date } }

    /// The stored day, or a fresh one with today's schedule target.
    func day(_ date: LocalDate) -> DayRecord {
        days[date] ?? DayRecord(date: date, targetSeconds: settings.schedule.targetSeconds(for: date), entries: [])
    }

    func days(in month: LocalDate) -> [DayRecord] {
        (0..<month.daysInMonth).map { day(month.firstOfMonth.adding(days: $0)) }
    }

    func storedDays(year: Int) -> [DayRecord] {
        sortedDays.filter { $0.date.year == year }
    }

    var ledger: VacationLedger { VacationLedger(days: sortedDays, settings: settings) }

    var overtimeTotal: Int { OvertimeAccount.total(days: sortedDays, settings: settings, through: .today()) }

    func vacationBalance(on date: LocalDate) -> Double { ledger.balance(on: date) }

    // MARK: Writing

    func showToast(_ text: String) {
        toast = text
        UIAccessibility.post(notification: .announcement, argument: text)
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            toast = nil
        }
    }

    func save(_ record: DayRecord) {
        let isDefault = record.entries.isEmpty && record.credit == nil && record.adjustmentSeconds == 0
            && record.targetSeconds == settings.schedule.targetSeconds(for: record.date)
        if isDefault {
            days[record.date] = nil
        } else {
            days[record.date] = record
        }
        write(record, delete: isDefault)
        persist()
    }

    /// One-tap booking: adds a work entry with the schedule's default times.
    func addStandardWorkday(_ date: LocalDate) {
        addWorkday(date, entry: settings.schedule.workEntry(for: date))
    }

    func addWorkday(_ date: LocalDate, entry: TimeEntry) {
        var record = day(date)
        record.entries.append(entry)
        save(record)
    }

    /// One-tap booking of a whole-day type (vacation, sick, holiday …).
    func addDayType(_ kind: EntryKind, on date: LocalDate) {
        var record = day(date)
        record.entries.append(TimeEntry(kind: kind))
        save(record)
    }

    /// Adds a vacation entry to each date (planner already excluded days with entries).
    func bookVacation(_ dates: [LocalDate], note: String) {
        for date in dates {
            var record = day(date)
            record.entries.append(TimeEntry(kind: .vacation, note: note))
            days[date] = record
            write(record, delete: false)
        }
        persist()
    }

    /// Removes vacation entries between `start` and `end` (used to cancel a planned block).
    func removeVacation(from start: LocalDate, to end: LocalDate) {
        for record in sortedDays where record.date >= start && record.date <= end {
            var changed = record
            changed.entries.removeAll { $0.kind == .vacation }
            if changed != record { save(changed) }
        }
    }

    func setCredit(_ date: LocalDate, note: String?) {
        var record = day(date)
        record.credit = note.map(Credit.init(note:))
        save(record)
    }

    func saveSettings(_ new: Settings) {
        settings = new
        do {
            let data = try JSONEncoder().encode(new)
            let existing = try context.fetch(FetchDescriptor<SettingsModel>())
            if let model = existing.first {
                model.json = data
            } else {
                context.insert(SettingsModel(json: data))
            }
        } catch {
            lastError = error.localizedDescription
        }
        persist()
    }

    /// Merges imported days (same date replaced, credits kept) and optionally takes the import's settings.
    func applyImport(_ imported: MyTimeImport, takeSettings: Bool) {
        let merged = DayMerge.merge(existing: sortedDays, incoming: imported.days)
        replaceDays(merged)
        if takeSettings { saveSettings(imported.settings) }
    }

    func restore(_ snapshot: Snapshot) {
        replaceDays(snapshot.days)
        saveSettings(snapshot.settings)
    }

    var snapshot: Snapshot { Snapshot(settings: settings, days: sortedDays) }

    // MARK: Automatic entries by location

    /// Geofence entered. A second arrival while a visit is open is ignored (duplicate event).
    func recordArrival(at time: Date) {
        if openVisit() != nil { return }
        context.insert(VisitModel(arrival: time, departure: nil))
        applyLocation(on: LocalDate(date: time, calendar: .current))
    }

    /// Geofence left: closes the open visit (if any) and updates that visit's day.
    func recordDeparture(at time: Date) {
        guard let open = openVisit() else { return }
        open.departure = time
        applyLocation(on: LocalDate(date: open.arrival, calendar: .current))
    }

    var isAtOffice: Bool { openVisit() != nil }

    var openVisitArrival: Date? { openVisit()?.arrival }

    /// The office moved or tracking was switched off: an open stay belongs to the old place, so it
    /// is dropped and its day recomputed. Finished stays are kept.
    func discardOpenVisit() {
        guard let open = openVisit() else { return }
        let date = LocalDate(date: open.arrival, calendar: .current)
        context.delete(open)
        applyLocation(on: date)
    }

    /// Recomputes recent days, e.g. a day left open yesterday becomes "Ende fehlt".
    func refreshLocationDays(lookBack: Int = 7) {
        let today = LocalDate.today()
        for offset in 0...lookBack { applyLocation(on: today.adding(days: -offset)) }
    }

    /// Accepts an automatic entry as it is: it becomes a normal entry and is no longer touched.
    func confirm(_ entryID: UUID, on date: LocalDate) {
        var record = day(date)
        guard let index = record.entries.firstIndex(where: { $0.id == entryID }) else { return }
        record.entries[index].origin = nil
        save(record)
    }

    /// Hand-made entries win: a day with any manual entry is never changed automatically.
    private func applyLocation(on date: LocalDate) {
        let visits = (try? context.fetch(FetchDescriptor<VisitModel>()))?.map(\.visit) ?? []
        let computed = LocationDay.entry(for: date, visits: visits, now: Date(), calendar: .current,
                                         schedule: settings.schedule, region: settings.holidayRegion)
        var record = day(date)
        if record.entries.contains(where: { $0.origin == nil }) {
            persist()
            return
        }
        let previous = record.entries.first { $0.origin != nil }
        guard previous?.withoutIDAndNote != computed?.withoutIDAndNote else {
            persist()
            return
        }
        record.entries.removeAll { $0.origin != nil }
        if var computed {
            if let previous {
                computed.id = previous.id
                computed.note = previous.note
            }
            record.entries.append(computed)
        }
        save(record)
    }

    private func openVisit() -> VisitModel? {
        var descriptor = FetchDescriptor<VisitModel>(predicate: #Predicate { $0.departure == nil },
                                                     sortBy: [SortDescriptor(\.arrival, order: .reverse)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    // MARK: Persistence

    private func load() {
        do {
            if let model = try context.fetch(FetchDescriptor<SettingsModel>()).first {
                settings = try JSONDecoder().decode(Settings.self, from: model.json)
            }
            let records = try context.fetch(FetchDescriptor<DayModel>()).compactMap(\.record)
            days = Dictionary(records.map { ($0.date, $0) }, uniquingKeysWith: { first, _ in first })
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func replaceDays(_ records: [DayRecord]) {
        do {
            try context.delete(model: DayModel.self)
        } catch {
            lastError = error.localizedDescription
        }
        days = Dictionary(records.map { ($0.date, $0) }, uniquingKeysWith: { _, last in last })
        for record in records { insert(record) }
        persist()
    }

    private func write(_ record: DayRecord, delete: Bool) {
        let key = record.date.iso
        do {
            let existing = try context.fetch(FetchDescriptor<DayModel>(predicate: #Predicate { $0.key == key }))
            existing.forEach(context.delete)
        } catch {
            lastError = error.localizedDescription
        }
        if !delete { insert(record) }
    }

    private func insert(_ record: DayRecord) {
        let model = DayModel(key: record.date.iso, targetSeconds: record.targetSeconds,
                             creditNote: record.credit?.note, adjustmentSeconds: record.adjustmentSeconds)
        context.insert(model)
        model.entries = record.entries.enumerated().map { EntryModel($1, order: $0) }
    }

    private func persist() {
        revision += 1
        do {
            try context.save()
        } catch {
            lastError = error.localizedDescription
        }
    }
}
