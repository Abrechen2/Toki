import SwiftUI
import TokiCore

/// Quick vacation entry: first day + end date or number of workdays. Workdays of the schedule are
/// booked as vacation; weekends, public holidays and days with entries are skipped. Every day can
/// be unticked in the preview before anything is saved.
struct QuickVacationView: View {
    enum Mode: Hashable { case until, count }

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var start: LocalDate
    @State private var end: LocalDate
    @State private var mode: Mode = .until
    @State private var workdays = 5
    @State private var note = ""
    @State private var excluded: Set<LocalDate> = []

    init(start: LocalDate) {
        _start = State(initialValue: start)
        _end = State(initialValue: start.adding(days: 4))
    }

    private var plan: [PlannedDay] {
        let settings = store.settings
        switch mode {
        case .until:
            return VacationPlanner.plan(from: start, to: end, schedule: settings.schedule,
                                        region: settings.holidayRegion, existing: store.days)
        case .count:
            return VacationPlanner.plan(from: start, workdays: workdays, schedule: settings.schedule,
                                        region: settings.holidayRegion, existing: store.days)
        }
    }

    private var datesToBook: [LocalDate] {
        plan.filter { $0.status == .book && !excluded.contains($0.date) }.map(\.date)
    }

    var body: some View {
        let plan = plan
        let dates = datesToBook
        NavigationStack {
            Form {
                Section {
                    DatePicker("Erster Tag", selection: LocalDate.binding($start), displayedComponents: .date)
                    Picker("Dauer", selection: $mode) {
                        Text("Bis Datum").tag(Mode.until)
                        Text("Anzahl Tage").tag(Mode.count)
                    }
                    .pickerStyle(.segmented)
                    switch mode {
                    case .until:
                        DatePicker("Letzter Tag", selection: LocalDate.binding($end), in: start.date()...,
                                   displayedComponents: .date)
                    case .count:
                        Stepper(value: $workdays, in: 1...60) {
                            LabeledContent("Urlaubstage", value: "\(workdays)")
                        }
                    }
                    TextField("Notiz, z. B. Reiseziel", text: $note)
                }

                Section {
                    ForEach(plan) { day in
                        PlannedDayRow(day: day, isOn: Binding(
                            get: { !excluded.contains(day.date) },
                            set: { on in if on { excluded.remove(day.date) } else { excluded.insert(day.date) } }
                        ))
                    }
                } header: {
                    Text("Vorschau")
                } footer: {
                    if let last = dates.last {
                        Text("Resturlaub nach dem \(last.display): \(HoursFormat.days(store.vacationBalance(on: last) - Double(dates.count))) Tage")
                    }
                }
            }
            .navigationTitle("Urlaub eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: start) { _, newStart in
                if end < newStart { end = newStart }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("\(dates.count) Tage eintragen") {
                        store.bookVacation(dates, note: note.trimmingCharacters(in: .whitespaces))
                        store.showToast(String(localized: "\(dates.count) Urlaubstage eingetragen"))
                        dismiss()
                    }
                    .disabled(dates.isEmpty)
                    .accessibilityIdentifier("bookVacation")
                }
            }
        }
    }
}

private struct PlannedDayRow: View {
    let day: PlannedDay
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(DateText.weekdayShort(day.date))
                .font(.caption.bold())
                .foregroundStyle(day.date.isWeekend ? Theme.weekend : Theme.secondaryText)
                .frame(width: 32, alignment: .leading)
            Text(day.date.display).font(.subheadline.monospacedDigit())
            Spacer()
            switch day.status {
            case .book:
                Toggle("Urlaub", isOn: $isOn).labelsHidden()
            case .weekend:
                Text("frei").font(.caption).foregroundStyle(Theme.secondaryText)
            case .holiday(let name):
                Text(name).font(.caption).foregroundStyle(Theme.weekend)
            case .hasEntries:
                Text("hat Einträge").font(.caption).foregroundStyle(Theme.negative)
            }
        }
    }
}
