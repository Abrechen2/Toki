import SwiftUI
import TokiCore

struct DaySelection: Identifiable {
    let date: LocalDate
    var id: String { date.iso }
}

struct MonthView: View {
    @Environment(AppStore.self) private var store
    @State private var month = LocalDate.today().firstOfMonth
    @State private var selection: DaySelection?
    @State private var showQuickVacation = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(store.days(in: month)) { day in
                        Button { selection = DaySelection(date: day.date) } label: {
                            DayRow(day: day)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("day-\(day.date.iso)")
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if day.entries.isEmpty {
                                Button { store.addStandardWorkday(day.date) } label: {
                                    Label("Arbeit", systemImage: "clock.fill")
                                }
                                .tint(Theme.positive)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if day.entries.isEmpty {
                                Button { store.addDayType(.vacation, on: day.date) } label: {
                                    Label("Urlaub", systemImage: "beach.umbrella")
                                }
                                .tint(Theme.accent)
                            } else {
                                Button("Leeren", role: .destructive) {
                                    var cleared = day
                                    cleared.entries = []
                                    store.save(cleared)
                                }
                            }
                        }
                        .id(day.date.iso)
                        .listRowBackground(day.date == .today() ? Theme.accent.opacity(0.15) : Theme.card)
                    }
                }
                .listStyle(.plain)
                .onAppear { proxy.scrollTo(LocalDate.today().iso, anchor: .center) }
            }
            .safeAreaInset(edge: .bottom) { MonthSummaryCard(month: month) }
            .navigationTitle(DateText.monthYear(month))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button { month = month.addingMonths(-1) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Vorheriger Monat")
                    Button { month = month.addingMonths(1) } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("Nächster Monat")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Heute") { month = LocalDate.today().firstOfMonth }
                    Menu {
                        Button { selection = DaySelection(date: .today()) } label: {
                            Label("Eintrag für heute", systemImage: "clock")
                        }
                        Button { showQuickVacation = true } label: {
                            Label("Urlaub eintragen", systemImage: "beach.umbrella")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Hinzufügen")
                }
            }
            .sheet(item: $selection) { DayEditorView(date: $0.date) }
            .sheet(isPresented: $showQuickVacation) { QuickVacationView(start: month == LocalDate.today().firstOfMonth ? .today() : month) }
        }
    }
}

struct DayRow: View {
    @Environment(AppStore.self) private var store
    let day: DayRecord

    private var isStored: Bool { store.days[day.date] != nil }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(DateText.weekdayShort(day.date))
                    .font(.caption.bold())
                    .foregroundStyle(day.date.isWeekend ? Theme.weekend : Theme.secondaryText)
                Text(DateText.dayMonth(day.date)).font(.subheadline.monospacedDigit())
            }
            .frame(width: 52, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                if day.entries.isEmpty {
                    Text(day.credit == nil ? "–" : "Kein Eintrag").foregroundStyle(Theme.secondaryText)
                }
                ForEach(day.entries) { entry in
                    EntrySummary(entry: entry)
                }
                if let credit = day.credit {
                    Label(credit.note.isEmpty ? String(localized: "Urlaubstag-Gutschrift") : credit.note,
                          systemImage: "plus.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.positive)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isStored && (Calculator.worked(day) > 0 || Calculator.overtime(day) != 0) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(HoursFormat.plain(Calculator.worked(day))).font(.subheadline.monospacedDigit())
                    Text(HoursFormat.signed(Calculator.overtime(day)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.overtimeColor(Calculator.overtime(day)))
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct EntrySummary: View {
    let entry: TimeEntry

    var body: some View {
        if entry.kind == .work, let start = entry.startSeconds {
            HStack(spacing: 6) {
                if entry.origin != nil {
                    Image(systemName: "location.fill").font(.caption2).foregroundStyle(Theme.accent)
                        .accessibilityLabel("Automatisch per Ort")
                }
                if let end = entry.endSeconds {
                    Text("\(HoursFormat.clock(start))–\(HoursFormat.clock(end))").font(.subheadline.monospacedDigit())
                } else if entry.isRunning {
                    Text("läuft seit \(HoursFormat.clock(start))").font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.positive)
                } else {
                    Text("\(HoursFormat.clock(start))–?").font(.subheadline.monospacedDigit())
                }
                if entry.breakSeconds > 0 {
                    Text("Pause \(HoursFormat.plain(entry.breakSeconds))")
                        .font(.caption).foregroundStyle(Theme.secondaryText)
                }
            }
            if let reasons = entry.origin?.uncertain, !reasons.isEmpty {
                Label("Unsicher: \(reasons.map(\.localizedName).joined(separator: ", "))",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.weekend)
                    .accessibilityIdentifier("uncertain")
            }
            if !entry.note.isEmpty {
                Text(entry.note).font(.caption).foregroundStyle(Theme.secondaryText).lineLimit(1)
            }
        } else {
            Label(entry.note.isEmpty ? entry.kind.localizedName : "\(entry.kind.localizedName) · \(entry.note)",
                  systemImage: entry.kind.symbol)
                .font(.subheadline)
                .lineLimit(1)
        }
    }
}

struct MonthSummaryCard: View {
    @Environment(AppStore.self) private var store
    let month: LocalDate

    var body: some View {
        let days = store.days(in: month)
        let monthOvertime = OvertimeAccount.sum(days)
        let today = LocalDate.today()
        VStack(spacing: 8) {
            HStack {
                StatTile(title: "Ist Monat", value: HoursFormat.plain(days.reduce(0) { $0 + Calculator.worked($1) }))
                StatTile(title: "Überstunden Monat", value: HoursFormat.signed(monthOvertime),
                         color: Theme.overtimeColor(monthOvertime))
            }
            HStack {
                StatTile(title: "Überstundenkonto", value: HoursFormat.signed(store.overtimeTotal),
                         color: Theme.overtimeColor(store.overtimeTotal))
                StatTile(title: "Resturlaub heute", value: "\(HoursFormat.days(store.vacationBalance(on: today))) d")
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}
