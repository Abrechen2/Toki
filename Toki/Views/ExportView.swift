import SwiftUI
import TokiCore

struct ExportView: View {
    enum Period: Hashable { case month, year }

    @Environment(AppStore.self) private var store
    @State private var period: Period = .month
    @State private var month = LocalDate.today().firstOfMonth
    @State private var file: URL?
    @State private var error: String?

    private var range: (start: LocalDate, end: LocalDate) {
        switch period {
        case .month: return (month.firstOfMonth, month.lastOfMonth)
        case .year: return (LocalDate(month.year, 1, 1), LocalDate(month.year, 12, 31))
        }
    }

    private var title: String {
        switch period {
        case .month: return DateText.monthYear(month)
        case .year: return String(month.year)
        }
    }

    private var days: [DayRecord] {
        store.sortedDays.filter { $0.date >= range.start && $0.date <= range.end && (!$0.entries.isEmpty || $0.credit != nil) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Zeitraum") {
                    Picker("Zeitraum", selection: $period) {
                        Text("Monat").tag(Period.month)
                        Text("Jahr").tag(Period.year)
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Button { month = month.addingMonths(period == .month ? -1 : -12) } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        Text(title).monospacedDigit()
                        Spacer()
                        Button { month = month.addingMonths(period == .month ? 1 : 12) } label: { Image(systemName: "chevron.right") }
                    }
                    .buttonStyle(.borderless)
                    LabeledContent("Tage mit Einträgen", value: "\(days.count)")
                }
                Section {
                    Button { export(pdf: true) } label: { Label("PDF erstellen", systemImage: "doc.richtext") }
                    Button { export(pdf: false) } label: { Label("CSV erstellen", systemImage: "tablecells") }
                    if let file {
                        ShareLink(item: file) { Label("\(file.lastPathComponent) teilen", systemImage: "square.and.arrow.up") }
                    }
                } footer: {
                    Text("CSV mit Semikolon und deutschem Dezimalkomma.")
                }
            }
            .navigationTitle("Export")
            .onChange(of: period) { file = nil }
            .onChange(of: month) { file = nil }
            .alert("Export fehlgeschlagen", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(error ?? "") }
        }
    }

    private func export(pdf: Bool) {
        let name = period == .month ? String(format: "Toki-%04d-%02d", month.year, month.month) : "Toki-\(month.year)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name + (pdf ? ".pdf" : ".csv"))
        let data = pdf
            ? PDFExporter.make(title: title, days: days, store: store, periodEnd: range.end)
            : Data(CSVExport.make(days: days).utf8)
        do {
            try data.write(to: url, options: .atomic)
            file = url
        } catch {
            self.error = error.localizedDescription
        }
    }
}
