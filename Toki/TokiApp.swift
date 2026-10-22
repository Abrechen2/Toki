import SwiftData
import SwiftUI
import TokiCore

@main
struct TokiApp: App {
    private let container: ModelContainer
    @State private var store: AppStore
    @State private var autoBackup: AutoBackup
    @State private var location: LocationService

    init() {
        #if DEBUG
        // UI tests start from an empty in-memory store.
        let inMemory = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        #else
        let inMemory = false
        #endif
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: DayModel.self, EntryModel.self, SettingsModel.self, VisitModel.self,
                                           configurations: configuration)
        } catch {
            fatalError("SwiftData store could not be opened: \(error)")
        }
        #if DEBUG
        // UI tests skip the first-launch assistant unless they test it.
        let onboarding = !inMemory || ProcessInfo.processInfo.arguments.contains("-onboarding")
        if inMemory && onboarding { UserDefaults.standard.removeObject(forKey: AppStore.onboardingDoneKey) }
        #else
        let onboarding = true
        #endif
        let store = AppStore(context: container.mainContext, onboardingAllowed: onboarding)
        _store = State(initialValue: store)
        #if DEBUG
        // UI tests: a day with an automatic entry but no stored stays, like after restoring a backup.
        if inMemory, let iso = ProcessInfo.processInfo.environment["TOKI_RESTORED_AUTO_DAY"], let date = LocalDate(iso: iso) {
            store.save(DayRecord(date: date, targetSeconds: 8 * 3600, entries: [
                TimeEntry(kind: .work, startSeconds: 8 * 3600, endSeconds: 16 * 3600 + 1800, breakSeconds: 1800,
                          origin: EntryOrigin(source: .location, uncertain: [])),
            ]))
        }
        if inMemory, ProcessInfo.processInfo.environment["TOKI_DEMO"] == "1" {
            DemoData.seed(into: store)
        }
        if inMemory, let fake = ProcessInfo.processInfo.environment["TOKI_FAKE_VISITS"] {
            Self.injectVisits(fake, into: store)
        }
        // UI tests: office "lat,lon,radius" instead of the settings screen.
        if inMemory, let office = ProcessInfo.processInfo.environment["TOKI_OFFICE"]?.split(separator: ",").compactMap({ Double($0) }),
           office.count == 3 {
            var settings = store.settings
            settings.office = OfficeLocation(latitude: office[0], longitude: office[1], radius: office[2],
                                             name: "Test", notify: false)
            store.saveSettings(settings)
        }
        #endif
        _location = State(initialValue: LocationService(store: store))
        #if DEBUG
        if inMemory {
            // UI tests: own defaults, optional backup folder instead of the document picker.
            let defaults = UserDefaults(suiteName: "uiTesting")!
            defaults.removePersistentDomain(forName: "uiTesting")
            let backup = AutoBackup(defaults: defaults)
            if let path = ProcessInfo.processInfo.environment["TOKI_BACKUP_FOLDER"] {
                backup.setFolder(URL(fileURLWithPath: path, isDirectory: true), snapshot: store.snapshot)
            }
            _autoBackup = State(initialValue: backup)
            return
        }
        #endif
        _autoBackup = State(initialValue: AutoBackup())
    }

    #if DEBUG
    /// UI tests: "yyyy-MM-dd HH:mm>yyyy-MM-dd HH:mm" pairs separated by "|"; a missing departure is "-".
    private static func injectVisits(_ text: String, into store: AppStore) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        for pair in text.split(separator: "|") {
            let parts = pair.split(separator: ">").map(String.init)
            guard let arrival = formatter.date(from: parts[0]) else { continue }
            store.recordArrival(at: arrival)
            if parts.count > 1, let departure = formatter.date(from: parts[1]) {
                store.recordDeparture(at: departure)
            }
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(autoBackup)
                .environment(location)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(AutoBackup.self) private var autoBackup
    @Environment(LocationService.self) private var location
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var store = store
        TabView {
            MonthView()
                .tabItem { Label("Monat", systemImage: "calendar") }
            VacationView()
                .tabItem { Label("Urlaub", systemImage: "beach.umbrella") }
            OverviewView()
                .tabItem { Label("Übersicht", systemImage: "chart.bar") }
            ExportView()
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
            MoreView()
                .tabItem { Label("Mehr", systemImage: "ellipsis.circle") }
        }
        .overlay(alignment: .top) {
            if let toast = store.toast {
                Label(toast, systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: Capsule())
                    .foregroundStyle(Theme.positive)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(toast)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityIdentifier("toast")
            }
        }
        .animation(.spring(duration: 0.3), value: store.toast)
        .sensoryFeedback(.success, trigger: store.toast) { _, new in new != nil }
        // Debounced backup a few seconds after the last change, and right away when leaving the app.
        .task(id: store.revision) {
            guard store.revision > 0 else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            autoBackup.backup(store.snapshot)
        }
        // Any change of the office (editor, restore, switching off) reconfigures monitoring.
        .onChange(of: store.settings.office) { _, office in location.apply(office) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { autoBackup.backup(store.snapshot) }
            if phase == .active { location.verifyOpenStay() }
        }
        .fullScreenCover(isPresented: Binding(get: { store.needsOnboarding }, set: { _ in })) {
            OnboardingView()
        }
        .alert("Fehler", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.lastError ?? "")
        }
    }
}
