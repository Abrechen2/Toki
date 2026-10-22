import SwiftUI
import UniformTypeIdentifiers
import TokiCore

struct MoreView: View {
    enum FilePurpose { case myTime, restore }

    @Environment(AppStore.self) private var store
    @Environment(AutoBackup.self) private var autoBackup
    @State private var pickFolder = false
    // One picker per purpose: a shared picker lost its purpose because SwiftUI resets the
    // presentation binding before the completion handler runs.
    @State private var pickMyTime = false
    @State private var pickRestore = false
    @State private var pendingImport: MyTimeImport?
    @State private var pendingRestore: Snapshot?
    @State private var backupFile: URL?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Job") {
                    NavigationLink { SettingsView() } label: {
                        Label(store.settings.jobName.isEmpty ? String(localized: "Job bearbeiten") : store.settings.jobName,
                              systemImage: "briefcase")
                    }
                    .accessibilityIdentifier("editJob")
                    NavigationLink { OfficeSettingsView() } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Automatisch per Ort")
                                if let office = store.settings.office {
                                    Text("An · \(office.name)").font(.caption).foregroundStyle(Theme.positive)
                                } else {
                                    Text("Aus").font(.caption).foregroundStyle(Theme.secondaryText)
                                }
                            }
                        } icon: {
                            Image(systemName: "location.circle")
                        }
                    }
                    .accessibilityIdentifier("officeSettings")
                }
                Section {
                    Button { pickMyTime = true } label: { Label("myTime-Backup importieren", systemImage: "square.and.arrow.down") }
                } header: {
                    Text("Import")
                } footer: {
                    Text("Liest eine .mytimebackup-Datei. Du siehst vorher eine Zusammenfassung; gleiche Tage werden ersetzt, Gutschriften bleiben erhalten.")
                }
                autoBackupSection
                Section("Datensicherung") {
                    Button { makeBackup() } label: { Label("Sicherung erstellen", systemImage: "externaldrive") }
                    if let backupFile {
                        ShareLink(item: backupFile) { Label("\(backupFile.lastPathComponent) teilen", systemImage: "square.and.arrow.up") }
                    }
                    Button(role: .destructive) { pickRestore = true } label: {
                        Label("Sicherung wiederherstellen", systemImage: "arrow.counterclockwise")
                    }
                    .accessibilityIdentifier("restoreBackup")
                }
            }
            .navigationTitle("Mehr")
            .background {
                // Separate host view: SwiftUI allows only one fileImporter per view.
                Color.clear.fileImporter(isPresented: $pickFolder, allowedContentTypes: [.folder]) { result in
                    switch result {
                    case .success(let url): autoBackup.setFolder(url, snapshot: store.snapshot)
                    case .failure(let error): message = error.localizedDescription
                    }
                }
            }
            .background {
                Color.clear.fileImporter(isPresented: $pickMyTime, allowedContentTypes: [.json, .data, .item]) { result in
                    handle(result, as: .myTime)
                }
            }
            .background {
                Color.clear.fileImporter(isPresented: $pickRestore, allowedContentTypes: [.json, .data, .item]) { result in
                    handle(result, as: .restore)
                }
            }
            .sheet(item: Binding(get: { pendingImport.map(ImportBox.init) }, set: { pendingImport = $0?.value })) { box in
                ImportPreviewView(imported: box.value)
            }
            .alert("Sicherung wiederherstellen?", isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } })) {
                Button("Abbrechen", role: .cancel) {}
                Button("Ersetzen", role: .destructive) {
                    if let snapshot = pendingRestore { store.restore(snapshot) }
                }
            } message: {
                Text("Alle Daten in der App werden durch die Sicherung ersetzt (\(pendingRestore?.days.count ?? 0) Tage).")
            }
            .alert("Hinweis", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(message ?? "") }
        }
    }

    private var autoBackupSection: some View {
        Section {
            if let folder = autoBackup.folderName {
                LabeledContent("Ordner", value: folder)
                if let last = autoBackup.lastBackup {
                    LabeledContent("Letzte Sicherung", value: last.formatted(date: .abbreviated, time: .shortened))
                } else {
                    LabeledContent("Letzte Sicherung", value: String(localized: "noch keine"))
                }
                if let error = autoBackup.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.negative)
                        .font(.footnote)
                }
                Button { autoBackup.backup(store.snapshot) } label: {
                    Label("Jetzt sichern", systemImage: "arrow.clockwise.icloud")
                }
                .disabled(autoBackup.isWriting)
                Button { pickFolder = true } label: { Label("Ordner ändern", systemImage: "folder") }
                Button("Automatische Sicherung ausschalten", role: .destructive) { autoBackup.disable() }
            } else {
                Button { pickFolder = true } label: {
                    Label("Ordner in iCloud Drive wählen", systemImage: "icloud")
                }
                .accessibilityIdentifier("pickBackupFolder")
            }
        } header: {
            Text("Automatische Sicherung")
        } footer: {
            Text("Nach jeder Änderung schreibt Toki „Toki-Sicherung.json“ und eine Datei pro Tag (30 Tage) in den Ordner. Eine leere App überschreibt nie eine vorhandene Sicherung.")
        }
    }

    private func handle(_ result: Result<URL, Error>, as purpose: FilePurpose) {
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            switch purpose {
            case .myTime:
                pendingImport = try MyTimeImporter.parse(data, base: store.settings)
            case .restore:
                pendingRestore = try Snapshot.decode(data)
            }
        } catch is MyTimeImportError {
            message = String(localized: "Die Datei ist kein myTime-Backup.")
        } catch SnapshotError.invalidDay(let date) {
            message = String(localized: "Die Sicherung enthält am \(date.display) unmögliche Werte und wurde nicht eingespielt.")
        } catch SnapshotError.invalidSettings {
            message = String(localized: "Die Einstellungen in der Sicherung enthalten unmögliche Werte. Die Sicherung wurde nicht eingespielt.")
        } catch {
            message = error.localizedDescription
        }
    }

    private func makeBackup() {
        let stamp = LocalDate.today().iso
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Toki-Sicherung-\(stamp).json")
        do {
            try store.snapshot.encoded().write(to: url, options: .atomic)
            backupFile = url
        } catch {
            message = error.localizedDescription
        }
    }
}

struct ImportBox: Identifiable {
    let value: MyTimeImport
    let id = UUID()
}

struct ImportPreviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let imported: MyTimeImport
    /// Called after a successful import (the first-launch assistant closes itself then).
    var onImported: (() -> Void)? = nil
    @State private var takeSettings = true

    var body: some View {
        let summary = imported.summary
        NavigationStack {
            Form {
                Section("Inhalt") {
                    if let first = summary.firstDate, let last = summary.lastDate {
                        LabeledContent("Zeitraum", value: "\(first.display) – \(last.display)")
                    }
                    LabeledContent("Tage", value: "\(summary.dayCount)")
                    LabeledContent("Einträge", value: "\(summary.entryCount)")
                    LabeledContent("Urlaubstage genommen", value: "\(summary.vacationDaysTaken)")
                }
                Section {
                    LabeledContent("Überstunden", value: HoursFormat.signed(summary.overtimeSeconds))
                    LabeledContent("Resturlaub", value: "\(HoursFormat.days(summary.vacationRemaining)) d")
                } header: {
                    Text("So rechnet myTime")
                } footer: {
                    Text("Diese Werte sollten mit der myTime-App übereinstimmen. Gutschriften kommen erst danach dazu.")
                }
                Section {
                    LabeledContent("Mögliche Gutschriften", value: "\(summary.creditCandidates)")
                    Toggle("Einstellungen übernehmen", isOn: $takeSettings)
                } footer: {
                    Text("Übernimmt Firmenname, Überstunden-Startwert, Urlaubsanspruch, Startwert Urlaub und Wochenplan aus myTime.")
                }
                if !summary.warnings.isEmpty {
                    Section("Hinweise") {
                        ForEach(summary.warnings, id: \.self) { Text($0).font(.caption) }
                    }
                }
            }
            .navigationTitle("myTime-Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importieren") {
                        store.applyImport(imported, takeSettings: takeSettings)
                        store.showToast(String(localized: "\(imported.summary.dayCount) Tage importiert"))
                        onImported?()
                        dismiss()
                    }
                }
            }
        }
    }
}
