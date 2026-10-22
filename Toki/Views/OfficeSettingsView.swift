import CoreLocation
import MapKit
import SwiftUI
import TokiCore

/// "Automatisch per Ort": pick the office (current location or address), radius and notifications.
struct OfficeSettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(LocationService.self) private var location
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    @State private var draft: OfficeLocation?
    @State private var search = AddressSearch()
    /// False until a real place was chosen; prevents saving the placeholder coordinate.
    @State private var positionSet = false

    var body: some View {
        Form {
            Section {
                Toggle("Automatisch per Ort", isOn: enabledBinding)
                    .accessibilityIdentifier("officeEnabled")
            } footer: {
                Text("Erstes Ankommen = Beginn, letztes Verlassen = Ende, auf 5 Minuten gerundet. Aufenthalte unter 1 Stunde zählen nicht. Tage, die du von Hand einträgst, bleiben unangetastet.")
            }

            if draft != nil {
                placeSection
                if let office = draft, positionSet { officeSection(office) }
                statusSection
            }
        }
        .navigationTitle("Automatisch per Ort")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Sichern") { save() }
                    .disabled(draft != nil && !positionSet)
                    .accessibilityIdentifier("saveOffice")
            }
        }
        .onAppear {
            if draft == nil {
                draft = store.settings.office
                positionSet = draft != nil
            }
        }
        .onChange(of: location.setupLocation) { _, newLocation in
            if let coordinate = newLocation?.coordinate { move(to: coordinate, name: nil) }
        }
        .onChange(of: search.query) { _, text in search.update(text, near: draft?.coordinate) }
    }

    /// Placed first so the suggestions stay above the keyboard.
    private var placeSection: some View {
        Section {
            Button { location.requestCurrentLocation() } label: {
                Label("Aktuellen Standort übernehmen", systemImage: "location.fill")
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.secondaryText)
                TextField("Adresse oder Firma suchen", text: $search.query)
                    .textContentType(.fullStreetAddress)
                    .submitLabel(.search)
                    .onSubmit { pick(search.suggestions.first) }
                    .accessibilityIdentifier("addressSearch")
                if search.isResolving { ProgressView() }
            }
            ForEach(search.suggestions, id: \.self) { suggestion in
                Button { pick(suggestion) } label: {
                    VStack(alignment: .leading) {
                        Text(suggestion.title).foregroundStyle(.primary)
                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle).font(.caption).foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
                .accessibilityIdentifier("addressSuggestion")
            }
            if let error = search.error {
                Text(error).font(.footnote).foregroundStyle(Theme.negative)
            }
        } header: {
            Text("Ort festlegen")
        } footer: {
            if !positionSet {
                Text("Übernimm deinen aktuellen Standort oder suche die Adresse.")
            }
        }
    }

    private func officeSection(_ office: OfficeLocation) -> some View {
        Section("Büro") {
            Map(initialPosition: .region(MKCoordinateRegion(center: office.coordinate, latitudinalMeters: office.radius * 5,
                                                            longitudinalMeters: office.radius * 5))) {
                MapCircle(center: office.coordinate, radius: office.radius)
                    .foregroundStyle(Theme.accent.opacity(0.25))
                    .stroke(Theme.accent, lineWidth: 2)
                Marker(office.name, coordinate: office.coordinate)
            }
            .id("\(office.latitude),\(office.longitude),\(office.radius)")
            .frame(height: 200)
            .listRowInsets(EdgeInsets())
            .accessibilityIdentifier("officeMap")
            TextField("Name", text: Binding(get: { draft?.name ?? "" }, set: { draft?.name = $0 }))
            VStack(alignment: .leading) {
                Text("Radius: \(Int(office.radius)) m")
                Slider(value: Binding(get: { draft?.radius ?? 150 }, set: { draft?.radius = $0.rounded() }),
                       in: 100...500, step: 25)
            }
            Toggle("Mitteilung bei Ankunft/Verlassen", isOn: Binding(get: { draft?.notify ?? true }, set: { on in
                draft?.notify = on
                if on { location.requestNotificationPermission() }
            }))
        }
    }

    private var statusSection: some View {
        Section("Status") {
            LabeledContent("Standortzugriff", value: accessText)
            LabeledContent("Genauer Standort", value: location.hasPreciseLocation ? String(localized: "an") : String(localized: "aus"))
            if !location.hasAlwaysAccess || !location.hasPreciseLocation {
                Text("Für die Erfassung im Hintergrund muss der Standortzugriff auf „Immer“ stehen und „Genauer Standort“ an sein.")
                    .font(.footnote).foregroundStyle(Theme.negative)
                Button("Einstellungen öffnen") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
            LabeledContent("Gerade im Büro", value: store.isAtOffice ? String(localized: "ja") : String(localized: "nein"))
            if let error = location.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundStyle(Theme.negative)
            }
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { draft != nil }, set: { on in
            if on {
                draft = OfficeLocation(latitude: 0, longitude: 0, radius: 150, name: String(localized: "Büro"), notify: true)
                location.requestCurrentLocation()
                location.requestNotificationPermission()
            } else {
                draft = nil
                positionSet = false
            }
        })
    }

    private var accessText: String {
        switch location.authorization {
        case .authorizedAlways: return String(localized: "Immer")
        case .authorizedWhenInUse: return String(localized: "Beim Verwenden")
        case .denied, .restricted: return String(localized: "Abgelehnt")
        default: return String(localized: "Noch nicht gefragt")
        }
    }

    private func pick(_ suggestion: MKLocalSearchCompletion?) {
        guard let suggestion else { return }
        Task {
            if let item = await search.resolve(suggestion) {
                move(to: item.placemark.coordinate, name: item.name)
                search.clear()
            }
        }
    }

    private func move(to coordinate: CLLocationCoordinate2D, name: String?) {
        draft?.latitude = coordinate.latitude
        draft?.longitude = coordinate.longitude
        positionSet = true
        if let name, !name.isEmpty { draft?.name = name }
    }

    private func save() {
        let previous = store.settings.office
        if draft?.isSamePlace(as: previous) == true {
            draft?.since = previous?.since
        } else {
            // New place (or off): an open stay belongs to the old one.
            draft?.since = Date()
            store.discardOpenVisit()
        }
        var settings = store.settings
        settings.office = draft
        store.saveSettings(settings)
        location.apply(draft)
        store.showToast(String(localized: "Gespeichert"))
        dismiss()
    }
}

/// Suggestions while typing (like Apple Maps) and resolving a suggestion to a coordinate.
@MainActor
@Observable
final class AddressSearch: NSObject, MKLocalSearchCompleterDelegate {
    var query = ""
    private(set) var suggestions: [MKLocalSearchCompletion] = []
    private(set) var isResolving = false
    private(set) var error: String?

    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(_ text: String, near coordinate: CLLocationCoordinate2D?) {
        error = nil
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else {
            suggestions = []
            return
        }
        if let coordinate, coordinate.latitude != 0 || coordinate.longitude != 0 {
            completer.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 50_000, longitudinalMeters: 50_000)
        }
        completer.queryFragment = trimmed
    }

    func resolve(_ suggestion: MKLocalSearchCompletion) async -> MKMapItem? {
        isResolving = true
        defer { isResolving = false }
        do {
            let response = try await MKLocalSearch(request: MKLocalSearch.Request(completion: suggestion)).start()
            if let item = response.mapItems.first { return item }
            error = String(localized: "Keine Adresse gefunden.")
        } catch {
            self.error = String(localized: "Suche fehlgeschlagen: \(error.localizedDescription)")
        }
        return nil
    }

    func clear() {
        query = ""
        suggestions = []
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = Array(completer.results.prefix(6))
        Task { @MainActor in self.suggestions = results }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.suggestions = []
            self.error = String(localized: "Suche fehlgeschlagen: \(message)")
        }
    }
}

extension OfficeLocation {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}
