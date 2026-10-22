import SwiftUI
import TokiCore

/// Vacation account: balance today and ahead, planned blocks, credits, reconciliation and history.
struct VacationView: View {
    @Environment(AppStore.self) private var store
    @State private var showQuickVacation = false
    @State private var selection: DaySelection?
    @State private var creditDate: LocalDate?
    @State private var creditNote = ""

    var body: some View {
        let today = LocalDate.today()
        let ledger = store.ledger
        let horizon = LocalDate(today.year + 1, 12, 31)
        let blocks = ledger.vacationBlocks(through: horizon)
        let planned = blocks.filter { $0.end > today }
        let credits = ledger.lines(through: horizon).filter { $0.kind == .credit }.reversed()
        let candidates = CreditCandidates.find(in: store.sortedDays)

        NavigationStack {
            List {
                Section {
                    HStack {
                        StatTile(title: "Rest heute", value: "\(HoursFormat.days(ledger.balance(on: today))) d")
                        StatTile(title: "Ende \(String(today.year))",
                                 value: "\(HoursFormat.days(ledger.balance(on: LocalDate(today.year, 12, 31)))) d")
                        if let last = planned.last {
                            StatTile(title: "Nach Planung", value: "\(HoursFormat.days(last.balanceAfter)) d",
                                     color: Theme.accent)
                        }
                    }
                    Button { showQuickVacation = true } label: {
                        Label("Urlaub eintragen", systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("quickVacation")
                }

                if !planned.isEmpty {
                    Section("Geplant") {
                        ForEach(planned, id: \.start) { block in
                            BlockRow(block: block)
                                .swipeActions {
                                    Button("Löschen", role: .destructive) {
                                        store.removeVacation(from: block.start, to: block.end)
                                    }
                                }
                        }
                    }
                }

                Section {
                    if credits.isEmpty {
                        Text("Noch keine Gutschriften").foregroundStyle(Theme.secondaryText)
                    }
                    ForEach(Array(credits), id: \.date) { line in
                        Button { selection = DaySelection(date: line.date) } label: {
                            HStack {
                                Text(line.date.german).monospacedDigit()
                                Text(line.note).foregroundStyle(Theme.secondaryText).lineLimit(1)
                                Spacer()
                                Text("+1").foregroundStyle(Theme.positive)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Gutschriften")
                }

                if !candidates.isEmpty {
                    Section {
                        ForEach(candidates.reversed()) { candidate in
                            HStack {
                                Button { selection = DaySelection(date: candidate.date) } label: {
                                    VStack(alignment: .leading) {
                                        Text("\(DateText.weekdayShort(candidate.date)) \(candidate.date.german)").monospacedDigit()
                                        Text(candidate.reason == .weekendWork ? "Arbeit am Wochenende" : "Notiz erwähnt Urlaub")
                                            .font(.caption).foregroundStyle(Theme.secondaryText)
                                    }
                                }
                                .buttonStyle(.plain)
                                Spacer()
                                Button("+1 T") {
                                    creditNote = ""
                                    creditDate = candidate.date
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    } header: {
                        Text("Abgleich: Wochenende & Notizen")
                    } footer: {
                        Text("Tage, die eine Gutschrift verdienen könnten. Du entscheidest pro Tag.")
                    }
                }

                Section("Verlauf") {
                    ForEach(historyLines(ledger: ledger, horizon: horizon), id: \.self) { item in
                        HistoryRow(item: item)
                    }
                }
            }
            .navigationTitle("Urlaubskonto")
            .sheet(isPresented: $showQuickVacation) { QuickVacationView(start: .today()) }
            .sheet(item: $selection) { DayEditorView(date: $0.date) }
            .alert("Gutschrift +1 Tag", isPresented: Binding(get: { creditDate != nil }, set: { if !$0 { creditDate = nil } })) {
                TextField("Grund", text: $creditNote)
                Button("Abbrechen", role: .cancel) {}
                Button("Gutschreiben") {
                    if let date = creditDate, !creditNote.trimmingCharacters(in: .whitespaces).isEmpty {
                        store.setCredit(date, note: creditNote)
                    }
                }
            } message: {
                Text("Der Tag zählt danach 0 Überstunden.")
            }
        }
    }

    /// Newest first; vacation days folded into blocks.
    private func historyLines(ledger: VacationLedger, horizon: LocalDate) -> [HistoryItem] {
        var items: [HistoryItem] = ledger.vacationBlocks(through: horizon).map {
            HistoryItem(date: $0.start, end: $0.end, change: -$0.days, title: $0.note, balance: $0.balanceAfter, kind: .vacation)
        }
        for line in ledger.lines(through: horizon) where line.kind != .vacation {
            items.append(HistoryItem(date: line.date, end: nil, change: line.change, title: line.note,
                                     balance: line.balance, kind: line.kind))
        }
        return items.sorted { ($0.date, $0.kind == .credit ? 1 : 0) > ($1.date, $1.kind == .credit ? 1 : 0) }
    }
}

struct HistoryItem: Hashable {
    let date: LocalDate
    let end: LocalDate?
    let change: Double
    let title: String
    let balance: Double
    let kind: LedgerLine.Kind
}

private struct HistoryRow: View {
    let item: HistoryItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let end = item.end, end != item.date {
                    Text("\(item.date.german) – \(end.german)").monospacedDigit()
                } else {
                    Text(item.date.german).monospacedDigit()
                }
                Text(subtitle).font(.caption).foregroundStyle(Theme.secondaryText).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.kind == .anchor ? "=" : (item.change > 0 ? "+" : "") + HoursFormat.days(item.change))
                    .foregroundStyle(item.change > 0 && item.kind != .anchor ? Theme.positive : .primary)
                Text("\(HoursFormat.days(item.balance)) d").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            .monospacedDigit()
        }
    }

    private var subtitle: String {
        switch item.kind {
        case .anchor: return String(localized: "Startwert") + (item.title.isEmpty ? "" : " · \(item.title)")
        case .entitlement: return String(localized: "Jahresanspruch")
        case .vacation: return item.title.isEmpty ? String(localized: "Urlaub") : item.title
        case .credit: return String(localized: "Gutschrift") + (item.title.isEmpty ? "" : " · \(item.title)")
        }
    }
}

private struct BlockRow: View {
    let block: VacationBlock

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(block.start.german) – \(block.end.german)").monospacedDigit()
                if !block.note.isEmpty {
                    Text(block.note).font(.caption).foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("−\(HoursFormat.days(block.days)) d")
                Text("danach \(HoursFormat.days(block.balanceAfter)) d").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            .monospacedDigit()
        }
    }
}
