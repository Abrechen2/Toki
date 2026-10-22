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
    /// True on a fresh install until the first-launch assistant is finished or skipped by an import.
    private(set) var needsOnboarding = false
    @ObservationIgnored private var hasSavedSettings = false
    static let onboardingDoneKey = "onboarding.done"

    /// Increases with every saved change; drives the automatic backup.
    private(set) var revision = 0
    @ObservationIgnored private var lastSaveFailed = false
    /// Short confirmation shown over the whole app ("Gespeichert"); survives closing a page.
    private(set) var toast: String?
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    @ObservationIgnored private let context: ModelContext

    init(context: ModelContext, onboardingAllowed: Bool = true) {
        self.context = context
        load()
        needsOnboarding = onboardingAllowed && !hasSavedSettings && days.isEmpty
            && !UserDefaults.standard.bool(forKey: Self.onboardingDoneKey)
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.onboardingDoneKey)
        needsOnboarding = false
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
        guard !lastSaveFailed else { return }
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
        transaction { try write(record, delete: isDefault) }
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
        var records: [DayRecord] = []
        for date in dates {
            var record = day(date)
            record.entries.append(TimeEntry(kind: .vacation, note: note))
            days[date] = record
            records.append(record)
        }
        transaction { for record in records { try write(record, delete: false) } }
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
        transaction { try writeSettings(new) }
    }

    /// Merges imported days (same date replaced, credits kept) and optionally takes the import's
    /// settings — saved together, so a failure never leaves half an import.
    func applyImport(_ imported: MyTimeImport, takeSettings: Bool) {
        let merged = DayMerge.merge(existing: sortedDays, incoming: imported.days)
        days = Dictionary(merged.map { ($0.date, $0) }, uniquingKeysWith: { _, last in last })
        if takeSettings { settings = imported.settings }
        transaction {
            try replaceDayModels(merged)
            if takeSettings { try writeSettings(imported.settings) }
        }
    }

    /// Replaces everything in one save. Stays recorded before the restore belong to the old data;
    /// keeping them would let the next location refresh overwrite restored automatic entries.
    func restore(_ snapshot: Snapshot) {
        days = Dictionary(snapshot.days.map { ($0.date, $0) }, uniquingKeysWith: { _, last in last })
        settings = snapshot.settings
        transaction {
            try context.delete(model: VisitModel.self)
            try replaceDayModels(snapshot.days)
            try writeSettings(snapshot.settings)
        }
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

    /// Recomputes recent days, e.g. a day left open yesterday becomes "Ende fehlt". Days without
    /// stored stays are left alone: their automatic entries may come from a restored backup.
    func refreshLocationDays(lookBack: Int = 7) {
        let today = LocalDate.today()
        for offset in 0...lookBack { applyLocation(on: today.adding(days: -offset), onlyWithStays: true) }
    }

    /// Accepts an automatic entry as it is: it becomes a normal entry and is no longer touched.
    func confirm(_ entryID: UUID, on date: LocalDate) {
        var record = day(date)
        guard let index = record.entries.firstIndex(where: { $0.id == entryID }) else { return }
        record.entries[index].origin = nil
        save(record)
    }

    /// Hand-made entries win: a day with any manual entry is never changed automatically.
    private func applyLocation(on date: LocalDate, onlyWithStays: Bool = false) {
        let visits = (try? context.fetch(FetchDescriptor<VisitModel>()))?.map(\.visit) ?? []
        if onlyWithStays && !visits.contains(where: { LocalDate(date: $0.arrival, calendar: .current) == date }) {
            return
        }
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
                hasSavedSettings = true
                settings = try JSONDecoder().decode(Settings.self, from: model.json)
            }
            let records = try context.fetch(FetchDescriptor<DayModel>()).compactMap(\.record)
            days = Dictionary(records.map { ($0.date, $0) }, uniquingKeysWith: { first, _ in first })
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func replaceDayModels(_ records: [DayRecord]) throws {
        try context.delete(model: DayModel.self)
        for record in records { insert(record) }
    }

    private func writeSettings(_ new: Settings) throws {
        let data = try JSONEncoder().encode(new)
        if let model = try context.fetch(FetchDescriptor<SettingsModel>()).first {
            model.json = data
        } else {
            context.insert(SettingsModel(json: data))
        }
    }

    /// A failed lookup throws instead of inserting a duplicate next to the old day.
    private func write(_ record: DayRecord, delete: Bool) throws {
        let key = record.date.iso
        try context.fetch(FetchDescriptor<DayModel>(predicate: #Predicate { $0.key == key })).forEach(context.delete)
        if !delete { insert(record) }
    }

    private func insert(_ record: DayRecord) {
        let model = DayModel(key: record.date.iso, targetSeconds: record.targetSeconds,
                             creditNote: record.credit?.note, adjustmentSeconds: record.adjustmentSeconds)
        context.insert(model)
        model.entries = record.entries.enumerated().map { EntryModel($1, order: $0) }
    }

    /// Runs all changes of one action and saves them together, or none of them.
    private func transaction(_ changes: () throws -> Void) {
        do {
            try changes()
        } catch {
            fail(error)
            return
        }
        persist()
    }

    private func persist() {
        do {
            try context.save()
            lastSaveFailed = false
            revision += 1
        } catch {
            fail(error)
        }
    }

    /// Rolls back unsaved changes and reloads memory from the store, so the UI never shows data
    /// that is not saved; no confirmation and no backup follow.
    private func fail(_ error: Error) {
        lastSaveFailed = true
        lastError = String(localized: "Speichern fehlgeschlagen: \(error.localizedDescription)")
        context.rollback()
        load()
    }
}
