import SwiftUI
import TokiCore

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
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
                Picker("Eintragstyp", selection: $entry.kind) {
                    ForEach(EntryKind.allCases, id: \.self) { kind in
                        Label(kind.localizedName, systemImage: kind.symbol).tag(kind)
                    }
                }
                if entry.kind == .work {
                    Section("Zeit") {
                        DatePicker("Beginn", selection: timeBinding(\.startSeconds), displayedComponents: .hourAndMinute)
                        DatePicker("Ende", selection: timeBinding(\.endSeconds), displayedComponents: .hourAndMinute)
                        Stepper(value: $entry.breakSeconds, in: 0...(4 * 3600), step: 300) {
                            LabeledContent("Pause", value: HoursFormat.plain(entry.breakSeconds))
                        }
                        LabeledContent("Stunden", value: HoursFormat.plain(entry.workedSeconds))
                    }
                } else if entry.kind == .overtimeReduction {
                    Text("Der Tag behält sein Soll; ohne Arbeitszeit wird es vom Überstundenkonto abgezogen.")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                } else {
                    Text("Ganzer Tag ohne Stunden; das Soll des Tages ist 0.")
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
        guard entry.kind == .work else {
            return TimeEntry(id: entry.id, kind: entry.kind, note: entry.note)
        }
        var result = TimeEntry.work(start: entry.startSeconds ?? 8 * 3600, end: entry.endSeconds ?? 8 * 3600,
                                    breakSeconds: entry.breakSeconds, note: entry.note)
        result.id = entry.id
        return result
    }

    private func timeBinding(_ path: WritableKeyPath<TimeEntry, Int?>) -> Binding<Date> {
        TimeOfDay.binding(Binding(get: { entry[keyPath: path] ?? 8 * 3600 }, set: { entry[keyPath: path] = $0 }), on: date)
    }
}
