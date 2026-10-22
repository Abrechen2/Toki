import Charts
import SwiftUI
import TokiCore

/// Year overview like myTime's "Übersicht": hours, overtime, counts per day type, monthly chart.
struct OverviewView: View {
    @Environment(AppStore.self) private var store
    @State private var year = LocalDate.today().year

    private struct MonthValue: Identifiable {
        let month: Int
        let overtime: Double
        var id: Int { month }
    }

    var body: some View {
        let days = store.storedDays(year: year)
        let overtime = OvertimeAccount.sum(days)
        let months = (1...12).map { month in
            MonthValue(month: month, overtime: Double(OvertimeAccount.sum(days.filter { $0.date.month == month })) / 3600)
        }
        NavigationStack {
            List {
                Section {
                    HStack {
                        StatTile(title: "Ist", value: HoursFormat.plain(days.reduce(0) { $0 + Calculator.worked($1) }))
                        StatTile(title: "Soll", value: HoursFormat.plain(days.reduce(0) { $0 + Calculator.effectiveTarget($1) }))
                        StatTile(title: "Überstunden", value: HoursFormat.signed(overtime), color: Theme.overtimeColor(overtime))
                    }
                }
                Section("Überstunden je Monat") {
                    Chart(months) { value in
                        BarMark(x: .value("Monat", value.month), y: .value("Stunden", value.overtime))
                            .foregroundStyle(value.overtime >= 0 ? Theme.positive : Theme.negative)
                    }
                    .chartXScale(domain: 0.5...12.5)
                    .chartXAxis {
                        AxisMarks(values: Array(1...12)) { value in
                            AxisValueLabel {
                                if let month = value.as(Int.self) {
                                    Text(LocalDate(year, month, 1).date().formatted(.dateTime.month(.narrow)))
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                }
                Section("Tage") {
                    countRow("Arbeitstage", days.filter { Calculator.worked($0) > 0 }.count)
                    countRow("Urlaub", Calculator.count(.vacation, in: days))
                    countRow("Gutschriften", days.filter { $0.credit != nil }.count)
                    countRow("Krankheit", Calculator.count(.sick, in: days))
                    countRow("Kind krank", Calculator.count(.childSick, in: days))
                    countRow("Feiertage", Calculator.count(.publicHoliday, in: days))
                    countRow("Sonderurlaub", Calculator.count(.specialLeave, in: days))
                    countRow("Überstundenabbau", Calculator.count(.overtimeReduction, in: days))
                }
            }
            .navigationTitle("Übersicht")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YearStepper(year: $year)
                }
            }
        }
    }

    private func countRow(_ title: LocalizedStringKey, _ count: Int) -> some View {
        LabeledContent(title, value: "\(count)")
    }
}

struct YearStepper: View {
    @Binding var year: Int

    var body: some View {
        HStack(spacing: 12) {
            Button { year -= 1 } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Vorheriges Jahr")
            Text(String(year)).monospacedDigit()
            Button { year += 1 } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("Nächstes Jahr")
        }
    }
}
