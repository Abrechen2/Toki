import SwiftUI
import TokiCore

/// "Job bearbeiten" like myTime: name, default values, overtime and vacation settings.
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Settings?

    var body: some View {
        Form {
            if draft != nil {
                Section("Name") {
                    TextField("Name", text: binding(\.jobName))
                }
                Section("Standardwerte") {
                    NavigationLink {
                        ScheduleView(schedule: binding(\.schedule))
                    } label: {
                        Text("Standardwerte für neue Einträge")
                    }
                    .accessibilityIdentifier("defaultValues")
                    Picker("Bundesland (Feiertage)", selection: binding(\.holidayRegion)) {
                        ForEach(HolidayRegion.allCases, id: \.self) { Text($0.germanName).tag($0) }
                    }
                }
                Section {
                    LabeledContent("Anfängliche Überstunden") {
                        TextField("0", value: hoursBinding, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Überstunden")
                } footer: {
                    Text("In Stunden, Stand vor dem ersten erfassten Tag.")
                }
                Section {
                    LabeledContent("Urlaubstage pro Jahr") {
                        TextField("30", value: bounded(\.entitlementPerYear, 0...366), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Anfängliche Urlaubstage") {
                        TextField("0", value: bounded(\.anchor.value, -10_000...10_000), format: .number)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                    DatePicker("Stand am Ende von", selection: LocalDate.binding(binding(\.anchor.date)),
                               displayedComponents: .date)
                    TextField("Notiz zum Startwert", text: binding(\.anchor.note))
                } header: {
                    Text("Urlaub")
                } footer: {
                    Text("Resturlaub = anfängliche Urlaubstage + Anspruch an jedem 1. Januar danach − Urlaubstage + Gutschriften. Nichts verfällt.")
                }
            }
        }
        .navigationTitle("Job bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Sichern") {
                    if let draft { store.saveSettings(draft) }
                    store.showToast(String(localized: "Gespeichert"))
                    dismiss()
                }
                .accessibilityIdentifier("saveSettings")
            }
        }
        .onAppear { if draft == nil { draft = store.settings } }
    }

    private func binding<Value>(_ path: WritableKeyPath<Settings, Value>) -> Binding<Value> {
        Binding(get: { (draft ?? store.settings)[keyPath: path] }, set: { draft?[keyPath: path] = $0 })
    }

    /// Accepts only finite values inside the range; anything else keeps the previous value.
    private func bounded(_ path: WritableKeyPath<Settings, Double>, _ range: ClosedRange<Double>) -> Binding<Double> {
        Binding(get: { (draft ?? store.settings)[keyPath: path] },
                set: { value in if value.isFinite && range.contains(value) { draft?[keyPath: path] = value } })
    }

    private var hoursBinding: Binding<Double> {
        Binding(get: { Double((draft ?? store.settings).initialOvertimeSeconds) / 3600 },
                set: { hours in
                    // Ignore impossible input instead of trapping in Int(Double).
                    if let seconds = Safe.seconds(hours: hours, limitHours: 100_000, allowNegative: true) {
                        draft?.initialOvertimeSeconds = seconds
                    }
                })
    }
}

/// "Standardwerte für neue Einträge": per weekday the default times and, independently, the target.
/// Only affects days created from now on; stored days keep their target.
struct ScheduleView: View {
    @Binding var schedule: WeekSchedule

    /// Monday first, Apple weekday numbers.
    private let order = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        Form {
            ForEach(order, id: \.self) { weekday in
                Section(Calendar.current.weekdaySymbols[weekday - 1]) {
                    Toggle("Arbeitstag", isOn: workdayBinding(weekday))
                    if let template = schedule.days[weekday] {
                        Stepper(value: field(weekday, \.targetSeconds), in: 0...(16 * 3600), step: 900) {
                            LabeledContent("Sollstunden", value: HoursFormat.plain(template.targetSeconds))
                        }
                        .accessibilityIdentifier("target-\(weekday)")
                        DatePicker("Beginn", selection: TimeOfDay.binding(field(weekday, \.startSeconds), on: .today()),
                                   displayedComponents: .hourAndMinute)
                        DatePicker("Ende", selection: TimeOfDay.binding(field(weekday, \.endSeconds), on: .today()),
                                   displayedComponents: .hourAndMinute)
                        Stepper(value: field(weekday, \.breakSeconds), in: 0...(4 * 3600), step: 300) {
                            LabeledContent("Pause", value: HoursFormat.plain(template.breakSeconds))
                        }
                        let fromTimes = TimeEntry.work(start: template.startSeconds, end: template.endSeconds,
                                                       breakSeconds: template.breakSeconds).workedSeconds
                        if fromTimes != template.targetSeconds {
                            Text("Zeiten ergeben \(HoursFormat.plain(fromTimes))")
                                .font(.caption).foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
            }
            Section {
                EmptyView()
            } footer: {
                Text("Sollstunden und Standardzeiten gelten für neue Tage; gespeicherte Tage behalten ihr Soll.")
            }
        }
        .navigationTitle("Standardwerte")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Switching a day on copies the first existing workday template (or 08:30–16:30, 8 h).
    private func workdayBinding(_ weekday: Int) -> Binding<Bool> {
        Binding(get: { schedule.days[weekday] != nil }, set: { on in
            guard on else {
                schedule.days[weekday] = nil
                return
            }
            let entry = schedule.workEntry(for: LocalDate(2026, 1, 5)) // a Monday
            let start = entry.startSeconds ?? 30600, end = entry.endSeconds ?? 59400
            schedule.days[weekday] = DayTemplate(targetSeconds: max(0, end - start - entry.breakSeconds),
                                                 startSeconds: start, endSeconds: end, breakSeconds: entry.breakSeconds)
        })
    }

    private func field(_ weekday: Int, _ path: WritableKeyPath<DayTemplate, Int>) -> Binding<Int> {
        Binding(get: { schedule.days[weekday]?[keyPath: path] ?? 0 },
                set: { schedule.days[weekday]?[keyPath: path] = $0 })
    }
}
