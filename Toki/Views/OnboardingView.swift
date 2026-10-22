import SwiftUI
import TokiCore
import UniformTypeIdentifiers

/// First launch: asks for the few values Toki cannot guess, or imports a myTime backup instead.
struct OnboardingView: View {
    @Environment(AppStore.self) private var store

    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var targetSeconds = 8 * 3600
    @State private var startSeconds = 8 * 3600
    @State private var entitlement = 30.0
    @State private var remaining = 30.0
    @State private var overtimeHours = 0.0
    @State private var region: HolidayRegion = .nationwide
    @State private var importing = false
    @State private var pendingImport: MyTimeImport?
    @State private var importError: String?

    /// Monday first, Apple weekday numbers.
    private let order = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Ein paar Angaben, dann rechnet Toki Überstunden und Resturlaub für dich. Alles lässt sich später unter Mehr → Job bearbeiten ändern.")
                        .foregroundStyle(Theme.secondaryText)
                }

                Section {
                    HStack(spacing: 6) {
                        ForEach(order, id: \.self) { weekday in
                            dayButton(weekday)
                        }
                    }
                    .accessibilityIdentifier("onboardingWeekdays")
                    Stepper(value: $targetSeconds, in: 3600...(12 * 3600), step: 900) {
                        LabeledContent("Soll pro Tag", value: HoursFormat.plain(targetSeconds))
                    }
                    DatePicker("Beginn", selection: TimeOfDay.binding($startSeconds, on: .today()), displayedComponents: .hourAndMinute)
                } header: {
                    Text("Arbeitszeit")
                } footer: {
                    Text("Pause nach Arbeitszeitgesetz: \(HoursFormat.plain(WeekSchedule.legalBreakSeconds(forTarget: targetSeconds))). Unterschiedliche Tage stellst du später unter Standardwerte ein.")
                }

                Section("Urlaub") {
                    Stepper(value: $entitlement, in: 0...60, step: 1) {
                        LabeledContent("Urlaubstage pro Jahr", value: HoursFormat.days(entitlement))
                    }
                    Stepper(value: $remaining, in: -60...200, step: 0.5) {
                        LabeledContent("Resturlaub heute", value: HoursFormat.days(remaining))
                    }
                }

                Section {
                    LabeledContent("Überstunden heute") {
                        HStack(spacing: 4) {
                            TextField("0", value: $overtimeHours, format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.numbersAndPunctuation)
                                .multilineTextAlignment(.trailing)
                            Text("h").foregroundStyle(Theme.secondaryText)
                        }
                    }
                    Picker("Bundesland (Feiertage)", selection: $region) {
                        ForEach(HolidayRegion.allCases, id: \.self) { Text($0.germanName).tag($0) }
                    }
                } header: {
                    Text("Startwerte")
                }

                Section {
                    Button { finish() } label: {
                        Text("Los geht's").font(.headline).frame(maxWidth: .infinity)
                    }
                    .disabled(weekdays.isEmpty)
                    .accessibilityIdentifier("onboardingDone")
                    Button { importing = true } label: {
                        Label("Aus myTime importieren", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
                    }
                } footer: {
                    Text("Der Import übernimmt deine Einträge und Einstellungen aus einem myTime-Backup.")
                }
            }
            .navigationTitle("Willkommen bei Toki")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .data, .item]) { result in
                load(result)
            }
            .sheet(item: Binding(get: { pendingImport.map(ImportBox.init) }, set: { pendingImport = $0?.value })) { box in
                ImportPreviewView(imported: box.value) { store.completeOnboarding() }
            }
            .alert("Import nicht möglich", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(importError ?? "") }
        }
        .interactiveDismissDisabled()
    }

    private func dayButton(_ weekday: Int) -> some View {
        let on = weekdays.contains(weekday)
        return Button {
            if on { weekdays.remove(weekday) } else { weekdays.insert(weekday) }
        } label: {
            Text(Calendar.current.veryShortWeekdaySymbols[weekday - 1])
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(on ? Theme.accent : Theme.card, in: Circle())
                .foregroundStyle(on ? .white : Theme.secondaryText)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func finish() {
        var settings = store.settings
        settings.schedule = .uniform(weekdays: weekdays, targetSeconds: targetSeconds, startSeconds: startSeconds)
        settings.entitlementPerYear = entitlement
        settings.anchor = .remaining(remaining, today: .today())
        settings.initialOvertimeSeconds = Safe.seconds(hours: overtimeHours, limitHours: 10_000, allowNegative: true) ?? 0
        settings.holidayRegion = region
        store.saveSettings(settings)
        store.completeOnboarding()
    }

    private func load(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            pendingImport = try MyTimeImporter.parse(Data(contentsOf: url), base: store.settings)
        } catch is MyTimeImportError {
            importError = String(localized: "Die Datei ist kein myTime-Backup.")
        } catch {
            importError = error.localizedDescription
        }
    }
}
