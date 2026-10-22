import SwiftUI
import TokiCore

struct ExportView: View {
    enum Period: Hashable { case month, year, custom }

    @Environment(AppStore.self) private var store
    @State private var period: Period = .month
    @State private var month = LocalDate.today().firstOfMonth
    @State private var customStart = LocalDate.today().firstOfMonth
    @State private var customEnd = LocalDate.today()
    /// nil = all entries; otherwise only this category.
    @State private var categoryID: UUID?
    @State private var file: URL?
    @State private var error: String?

    private var range: (start: LocalDate, end: LocalDate) {
        switch period {
        case .month: return (month.firstOfMonth, month.lastOfMonth)
        case .year: return (LocalDate(month.year, 1, 1), LocalDate(month.year, 12, 31))
        case .custom: return (min(customStart, customEnd), max(customStart, customEnd))
        }
    }

    private var title: String {
        switch period {
        case .month: return DateText.monthYear(month)
        case .year: return String(month.year)
        case .custom: return "\(range.start.display) – \(range.end.display)"
        }
    }

    private var days: [DayRecord] {
        store.sortedDays.filter { $0.date >= range.start && $0.date <= range.end && (!$0.entries.isEmpty || $0.credit != nil) }
    }

    private var report: CategoryReport? {
        categoryID.map { CategoryReport(days: store.sortedDays, categoryID: $0, from: range.start, to: range.end) }
    }

    var body: some View {
        NavigationStack {
            Form {
                if !store.settings.categories.isEmpty {
                    Section {
                        Picker("Inhalt", selection: $categoryID) {
                            Text("Alle Einträge").tag(UUID?.none)
                            ForEach(store.settings.categories) { category in
                                Text(category.name).tag(UUID?.some(category.id))
                            }
                        }
                        .accessibilityIdentifier("exportCategory")
                    } footer: {
                        if categoryID != nil {
                            Text("Nur die Einträge dieser Kategorie mit Datum, Zeit, Pause, Stunden, Notiz und Summe.")
                        }
                    }
                }
                Section("Zeitraum") {
                    Picker("Zeitraum", selection: $period) {
                        Text("Monat").tag(Period.month)
                        Text("Jahr").tag(Period.year)
                        Text("Von–bis").tag(Period.custom)
                    }
                    .pickerStyle(.segmented)
                    if period == .custom {
                        DatePicker("Von", selection: LocalDate.binding($customStart), displayedComponents: .date)
                        DatePicker("Bis", selection: LocalDate.binding($customEnd), displayedComponents: .date)
                    } else {
                        HStack {
                            Button { month = month.addingMonths(period == .month ? -1 : -12) } label: { Image(systemName: "chevron.left") }
                            Spacer()
                            Text(title).monospacedDigit()
                            Spacer()
                            Button { month = month.addingMonths(period == .month ? 1 : 12) } label: { Image(systemName: "chevron.right") }
                        }
                        .buttonStyle(.borderless)
                    }
                    if let report {
                        LabeledContent("Einträge", value: "\(report.rows.count)")
                        LabeledContent("Summe", value: HoursFormat.plain(report.totalSeconds))
                            .accessibilityIdentifier("exportCategoryTotal")
                    } else {
                        LabeledContent("Tage mit Einträgen", value: "\(days.count)")
                    }
                }
                Section {
                    Button { export(pdf: true) } label: { Label("PDF erstellen", systemImage: "doc.richtext") }
                        .accessibilityIdentifier("exportPDF")
                    Button { export(pdf: false) } label: { Label("CSV erstellen", systemImage: "tablecells") }
                    if let file {
                        ShareLink(item: file) { Label("\(file.lastPathComponent) teilen", systemImage: "square.and.arrow.up") }
                            .accessibilityIdentifier("shareExport")
                    }
                } footer: {
                    Text("CSV mit Semikolon und deutschem Dezimalkomma.")
                }
            }
            .navigationTitle("Export")
            .onChange(of: period) { file = nil }
            .onChange(of: month) { file = nil }
            .onChange(of: categoryID) { file = nil }
            .onChange(of: customStart) { file = nil }
            .onChange(of: customEnd) { file = nil }
            .alert("Export fehlgeschlagen", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(error ?? "") }
        }
    }

    private var fileName: String {
        let prefix = store.category(categoryID).map { "Toki-\($0.name.replacingOccurrences(of: "/", with: "-"))" } ?? "Toki"
        switch period {
        case .month: return String(format: "%@-%04d-%02d", prefix, month.year, month.month)
        case .year: return "\(prefix)-\(month.year)"
        case .custom: return "\(prefix)-\(range.start.iso)-bis-\(range.end.iso)"
        }
    }

    private func export(pdf: Bool) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName + (pdf ? ".pdf" : ".csv"))
        let data: Data
        if let report, let category = store.category(categoryID) {
            data = pdf ? CategoryPDFExporter.make(report: report, category: category, period: title, store: store)
                       : Data(report.csv.utf8)
        } else {
            data = pdf ? PDFExporter.make(title: title, days: days, store: store, periodEnd: range.end)
                       : Data(CSVExport.make(days: days).utf8)
        }
        do {
            try data.write(to: url, options: .atomic)
            file = url
            #if DEBUG
            if let dir = ProcessInfo.processInfo.environment["TOKI_EXPORT_DIR"] {
                try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent(url.lastPathComponent))
            }
            #endif
        } catch {
            self.error = error.localizedDescription
        }
    }
}
