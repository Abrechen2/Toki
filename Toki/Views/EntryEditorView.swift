import SwiftUI
import TokiCore

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    let date: LocalDate
    let isNew: Bool
    let onSave: (TimeEntry) -> Void
    @State private var entry: TimeEntry

    init(date: LocalDate, entry: TimeEntry, isNew: Bool, onSave: @escaping (TimeEntry) -> Void) {
        self.date = date
        self.isNew = isNew
        self.onSave = onSave
        _entry = State(initialValue: entry)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Eintragstyp", selection: kindBinding) {
                    // Separate time is not chosen directly; it follows from the category.
                    ForEach(EntryKind.allCases.filter { $0 != .separateTime }, id: \.self) { kind in
                        Label(kind.localizedName, systemImage: kind.symbol).tag(kind)
                    }
                }
                if entry.kind.hasTimes {
                    if !store.settings.categories.isEmpty {
                        CategoryPicker(entry: $entry)
                    }
                    Section("Zeit") {
                        DatePicker("Beginn", selection: timeBinding(\.startSeconds), displayedComponents: .hourAndMinute)
                        DatePicker("Ende", selection: timeBinding(\.endSeconds), displayedComponents: .hourAndMinute)
                        Stepper(value: $entry.breakSeconds, in: 0...(4 * 3600), step: 300) {
                            LabeledContent("Pause", value: HoursFormat.plain(entry.breakSeconds))
                        }
                        LabeledContent("Stunden", value: HoursFormat.plain(entry.durationSeconds))
                        if entry.kind == .separateTime {
                            Text("Getrennte Zeit: zählt nicht für Soll und Überstunden.")
                                .font(.footnote).foregroundStyle(Theme.secondaryText)
                        }
                    }
                } else if entry.kind == .overtimeReduction {
                    Text("Der Tag behält sein Soll; ohne Arbeitszeit wird es vom Überstundenkonto abgezogen.")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                } else {
                    Toggle("Halber Tag", isOn: Binding(get: { entry.dayFraction == 0.5 },
                                                       set: { entry.dayFraction = $0 ? 0.5 : nil }))
                    Text(entry.kind == .vacation && entry.dayFraction == 0.5
                         ? "Zählt als halber Urlaubstag; das Soll des Tages ist 0."
                         : "Ganzer Tag ohne Stunden; das Soll des Tages ist 0.")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                }
                Section("Notiz") {
                    TextField("Notiz", text: $entry.note, axis: .vertical)
                }
            }
            .navigationTitle(isNew ? "Neuer Eintrag" : "Eintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        onSave(normalized)
                        dismiss()
                    }
                }
            }
        }
    }

    /// Day types carry no times; work times go through the core's overnight rule.
    private var normalized: TimeEntry {
        guard entry.kind.hasTimes else {
            return TimeEntry(id: entry.id, kind: entry.kind, note: entry.note, dayFraction: entry.dayFraction)
        }
        var result = TimeEntry.work(start: entry.startSeconds ?? 8 * 3600, end: entry.endSeconds ?? 8 * 3600,
                                    breakSeconds: entry.breakSeconds, note: entry.note)
        result.id = entry.id
        result.kind = entry.kind
        result.categoryID = entry.categoryID
        return result
    }

    /// Shows separate time as "Arbeit"; choosing another type drops the category.
    private var kindBinding: Binding<EntryKind> {
        Binding(get: { entry.kind == .separateTime ? .work : entry.kind },
                set: { kind in
                    guard kind != .work else { return }
                    entry.kind = kind
                    entry.categoryID = nil
                })
    }

    private func timeBinding(_ path: WritableKeyPath<TimeEntry, Int?>) -> Binding<Date> {
        TimeOfDay.binding(Binding(get: { entry[keyPath: path] ?? 8 * 3600 }, set: { entry[keyPath: path] = $0 }), on: date)
    }
}
