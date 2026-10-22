import SwiftUI
import TokiCore

/// Sheet for one day: entries, frozen target, vacation credit, overtime correction.
struct DayEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let date: LocalDate

    @State private var record: DayRecord?
    @State private var editing: EntryEditing?
    @State private var creditOn = false
    @State private var creditDays = 1.0
    @State private var correctionDays = 0.0
    @State private var correctionNote = ""
    @State private var creditNote = ""
    @State private var quickStart = 8 * 3600 + 1800
    @State private var quickEnd = 16 * 3600 + 1800
    @State private var quickBreak = 0
    @State private var quickEntry = TimeEntry(kind: .work)

    var body: some View {
        NavigationStack {
            Form {
                if let record {
                    if record.entries.isEmpty {
                        quickSection
                    }
                    summary(record)
                    entriesSection(record)
                    creditSection
                    correctionSection
                    targetSection
                }
            }
            .navigationTitle(DateText.long(date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }.disabled(!canSave)
                }
            }
            .sheet(item: $editing) { editing in
                EntryEditorView(date: date, entry: editing.entry, isNew: editing.isNew) { result in
                    apply(result, isNew: editing.isNew)
                }
            }
            .onAppear(perform: load)
        }
    }

    /// Times are prefilled from the schedule; one tap books the day and closes the sheet.
    private var quickSection: some View {
        var work = TimeEntry.work(start: quickStart, end: quickEnd, breakSeconds: quickBreak)
        if let category = store.category(quickEntry.categoryID) { work.assign(category) }
        return Section {
            DatePicker("Beginn", selection: TimeOfDay.binding($quickStart, on: date), displayedComponents: .hourAndMinute)
            DatePicker("Ende", selection: TimeOfDay.binding($quickEnd, on: date), displayedComponents: .hourAndMinute)
            Picker("Pause", selection: $quickBreak) {
                ForEach(Set([0, 15, 30, 45, 60, 90, quickBreak / 60]).sorted(), id: \.self) { minutes in
                    Text(minutes == 0 ? String(localized: "keine") : HoursFormat.plain(minutes * 60)).tag(minutes * 60)
                }
            }
            .accessibilityIdentifier("quickBreak")
            if !store.settings.categories.isEmpty {
                CategoryPicker(entry: $quickEntry)
            }
            Button {
                store.addWorkday(date, entry: work)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "clock.fill")
                    Text("Arbeitstag eintragen").font(.headline)
                    Spacer()
                    Text(HoursFormat.plain(work.durationSeconds)).font(.headline.monospacedDigit())
                }
                .padding(.vertical, 6)
                .foregroundStyle(.white)
            }
            .listRowBackground(Theme.positive.opacity(0.85))
            .accessibilityIdentifier("quickWorkday")
            HStack(spacing: 8) {
                ForEach([EntryKind.vacation, .sick, .publicHoliday], id: \.self) { kind in
                    Button {
                        store.addDayType(kind, on: date)
                        dismiss()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: kind.symbol)
                            Text(kind.localizedName).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("quick-\(kind.rawValue)")
                }
            }
        } header: {
            Text("Schnell eintragen")
        }
    }

    private func summary(_ record: DayRecord) -> some View {
        let preview = previewRecord(record)
        return Section("Zusammenfassung Tag") {
            HStack {
                StatTile(title: "Soll", value: HoursFormat.plain(Calculator.effectiveTarget(preview)))
                StatTile(title: "Ist", value: HoursFormat.plain(Calculator.worked(preview)))
                StatTile(title: "Überstunden", value: HoursFormat.signed(Calculator.overtime(preview)),
                         color: Theme.overtimeColor(Calculator.overtime(preview)))
            }
            if creditOn {
                Text("Gutschrift: +1 Urlaubstag, der Tag zählt 0 Überstunden.")
                    .font(.caption).foregroundStyle(Theme.positive)
            }
        }
    }

    private func entriesSection(_ record: DayRecord) -> some View {
        Section("Einträge") {
            ForEach(record.entries) { entry in
                Button { editing = EntryEditing(entry: entry, isNew: false) } label: {
                    EntrySummary(entry: entry).foregroundStyle(.primary)
                }
                if let reasons = entry.origin?.uncertain, !reasons.isEmpty, entry.endSeconds != nil {
                    Button {
                        if let index = self.record?.entries.firstIndex(where: { $0.id == entry.id }) {
                            self.record?.entries[index].origin = nil
                        }
                    } label: {
                        Label("Passt so", systemImage: "checkmark.circle")
                    }
                    .accessibilityIdentifier("confirmEntry")
                }
            }
            .onDelete { offsets in self.record?.entries.remove(atOffsets: offsets) }
            Menu {
                ForEach(EntryKind.allCases.filter { $0 != .separateTime }, id: \.self) { kind in
                    Button { editing = EntryEditing(entry: newEntry(kind), isNew: true) } label: {
                        Label(kind.localizedName, systemImage: kind.symbol)
                    }
                }
            } label: {
                Label("Eintrag hinzufügen", systemImage: "plus")
            }
        }
    }

    private var creditSection: some View {
        Section {
            Toggle(creditDays == 1 ? String(localized: "Urlaubstag-Gutschrift (+1 Tag)")
                   : String(localized: "Urlaubstag-Gutschrift (+\(HoursFormat.days(creditDays)) Tage)"), isOn: $creditOn)
            if creditOn {
                TextField("Grund (Pflicht), z. B. Wochenend-Einsatz", text: $creditNote)
            }
        } header: {
            Text("Gutschrift")
        } footer: {
            Text("Für Tage, an denen du einen ganzen Urlaubstag zusätzlich bekommst. Erfasste Stunden bleiben sichtbar, zählen aber nicht als Überstunden.")
        }
    }

    /// Explicit change of the vacation balance, e.g. to match the official vacation card.
    private var correctionSection: some View {
        Section {
            Stepper(value: $correctionDays, in: -60...60, step: 0.5) {
                LabeledContent("Urlaubstage", value: (correctionDays > 0 ? "+" : "") + HoursFormat.days(correctionDays))
            }
            .accessibilityIdentifier("vacationCorrection")
            if correctionDays != 0 {
                TextField("Grund (Pflicht), z. B. laut Urlaubskarte", text: $correctionNote)
                    .accessibilityIdentifier("vacationCorrectionNote")
            }
        } header: {
            Text("Korrektur Urlaubskonto")
        } footer: {
            Text("Nur für Abweichungen, die sich nicht aus Einträgen ergeben, etwa eine Korrektur durch den Arbeitgeber.")
        }
    }

    private var canSave: Bool {
        let creditOK = !creditOn || !creditNote.trimmingCharacters(in: .whitespaces).isEmpty
        let correctionOK = correctionDays == 0 || !correctionNote.trimmingCharacters(in: .whitespaces).isEmpty
        return creditOK && correctionOK
    }

    private var targetSection: some View {
        Section {
            Stepper(value: targetBinding, in: 0...(12 * 3600), step: 900) {
                LabeledContent("Sollstunden Tag", value: HoursFormat.plain(record?.targetSeconds ?? 0))
            }
            Stepper(value: adjustmentBinding, in: -(24 * 3600)...(24 * 3600), step: 900) {
                LabeledContent("Korrektur Überstunden", value: HoursFormat.signed(record?.adjustmentSeconds ?? 0))
            }
        } header: {
            Text("Soll und Korrektur")
        } footer: {
            Text("Das Soll wird pro Tag gespeichert; spätere Änderungen am Wochenplan ändern vergangene Tage nicht.")
        }
    }

    private var targetBinding: Binding<Int> {
        Binding(get: { record?.targetSeconds ?? 0 }, set: { record?.targetSeconds = $0 })
    }

    private var adjustmentBinding: Binding<Int> {
        Binding(get: { record?.adjustmentSeconds ?? 0 }, set: { record?.adjustmentSeconds = $0 })
    }

    private func previewRecord(_ record: DayRecord) -> DayRecord {
        var copy = record
        copy.credit = creditOn ? Credit(note: creditNote, days: creditDays) : nil
        copy.vacationCorrection = correctionDays == 0 ? nil : VacationCorrection(days: correctionDays, note: correctionNote)
        return copy
    }

    private func newEntry(_ kind: EntryKind) -> TimeEntry {
        kind == .work ? store.settings.schedule.workEntry(for: date) : TimeEntry(kind: kind)
    }

    private func apply(_ entry: TimeEntry, isNew: Bool) {
        guard var current = record else { return }
        if isNew {
            current.entries.append(entry)
        } else if let index = current.entries.firstIndex(where: { $0.id == entry.id }) {
            current.entries[index] = entry
        }
        record = current
    }

    private func load() {
        guard record == nil else { return }
        let day = store.day(date)
        record = day
        creditOn = day.credit != nil
        creditDays = day.credit?.days ?? 1
        correctionDays = day.vacationCorrection?.days ?? 0
        correctionNote = day.vacationCorrection?.note ?? ""
        creditNote = day.credit?.note ?? ""
        let template = store.settings.schedule.workEntry(for: date)
        quickStart = template.startSeconds ?? quickStart
        quickEnd = template.endSeconds ?? quickEnd
        quickBreak = template.breakSeconds
    }

    private func save() {
        guard let record else { return }
        store.save(previewRecord(record))
        store.showToast(String(localized: "Gespeichert"))
        dismiss()
    }
}

struct EntryEditing: Identifiable {
    let entry: TimeEntry
    let isNew: Bool
    var id: UUID { entry.id }
}
