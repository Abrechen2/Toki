import CoreLocation
import Foundation
import Observation
import TokiCore
import UserNotifications

/// Office geofence: entering records an arrival, leaving a departure. Created at launch so iOS can
/// deliver region events after relaunching the app in the background. Needs "Always" access.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var authorization: CLAuthorizationStatus
    private(set) var lastError: String?
    /// Result of "use current location" while setting up the office (only that request sets it).
    private(set) var setupLocation: CLLocation?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private weak var store: AppStore?
    /// "Use current location" was tapped (possibly before access was granted).
    @ObservationIgnored private var locationRequestPending = false
    @ObservationIgnored private var setupRequested = false
    /// A location fix was requested to check whether an open stay is still real.
    @ObservationIgnored private var verificationPending = false
    static let regionID = "toki.office"

    init(store: AppStore) {
        self.store = store
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        apply(store.settings.office)
        store.refreshLocationDays()
        verifyOpenStay()
    }

    /// The region state at launch is unreliable (often "unknown" right after monitoring restarts),
    /// so an open stay is checked against a real location fix.
    func verifyOpenStay() {
        guard store?.isAtOffice == true, store?.settings.office != nil,
              authorization == .authorizedAlways || authorization == .authorizedWhenInUse else { return }
        verificationPending = true
        manager.requestLocation()
    }

    var hasAlwaysAccess: Bool { authorization == .authorizedAlways }

    /// Region monitoring only works with precise location.
    var hasPreciseLocation: Bool { manager.accuracyAuthorization == .fullAccuracy }

    /// Starts or stops monitoring for the configured office.
    func apply(_ office: OfficeLocation?) {
        for region in manager.monitoredRegions where region.identifier == Self.regionID {
            manager.stopMonitoring(for: region)
        }
        guard let office else { return }
        if authorization != .authorizedAlways { manager.requestAlwaysAuthorization() }
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            lastError = String(localized: "Ortsüberwachung ist auf diesem Gerät nicht verfügbar.")
            return
        }
        let center = CLLocationCoordinate2D(latitude: office.latitude, longitude: office.longitude)
        let radius = min(office.radius, manager.maximumRegionMonitoringDistance)
        let region = CLCircularRegion(center: center, radius: radius, identifier: Self.regionID)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
    }

    /// Asked while setting up (switching the feature or the notifications on), not on saving,
    /// so the system alert never covers the save confirmation.
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func report(_ message: String) { lastError = message }

    /// Asking for a location before access is granted fails with "denied", so wait for the answer.
    func requestCurrentLocation() {
        lastError = nil
        setupRequested = true
        switch authorization {
        case .notDetermined:
            locationRequestPending = true
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            setupRequested = false
            lastError = Self.message(for: CLError(.denied))
        default:
            manager.requestLocation()
        }
    }

    /// German text for CoreLocation errors instead of "kCLErrorDomain-Fehler 1".
    nonisolated static func message(for error: Error) -> String {
        guard let error = error as? CLError else { return error.localizedDescription }
        switch error.code {
        case .denied:
            return String(localized: "Kein Zugriff auf den Standort. Bitte in den Einstellungen für Toki „Immer“ und „Genauer Standort“ erlauben.")
        case .locationUnknown, .network:
            return String(localized: "Standort gerade nicht bestimmbar. Bitte gleich nochmal versuchen.")
        case .regionMonitoringDenied:
            return String(localized: "iOS erlaubt die Büro-Erkennung nicht. „Genauer Standort“ muss an sein.")
        case .regionMonitoringFailure, .regionMonitoringSetupDelayed:
            return String(localized: "Die Büro-Erkennung konnte nicht gestartet werden. Bitte später nochmal sichern.")
        default:
            return error.localizedDescription
        }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if self.locationRequestPending, status == .authorizedWhenInUse || status == .authorizedAlways {
                self.locationRequestPending = false
                manager.requestLocation()
            } else if self.locationRequestPending, status == .denied || status == .restricted {
                self.locationRequestPending = false
                self.lastError = Self.message(for: CLError(.denied))
            }
            if status == .authorizedWhenInUse, self.store?.settings.office != nil {
                manager.requestAlwaysAuthorization()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let center = Self.center(of: region) else { return }
        let now = Date()
        Task { @MainActor in
            if self.belongsToOffice(center) { self.arrived(at: now) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let center = Self.center(of: region) else { return }
        let now = Date()
        Task { @MainActor in
            if self.belongsToOffice(center) { self.left(at: now) }
        }
    }

    /// Answer to `requestState` (at launch and after saving). Inside without an open stay counts as
    /// arrival now. Outside with an open stay: a stay from an earlier office place is dropped, any
    /// other one is closed now (its exit event was missed).
    nonisolated func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState,
                                     for region: CLRegion) {
        guard let center = Self.center(of: region) else { return }
        let now = Date()
        Task { @MainActor in
            guard self.belongsToOffice(center), let store = self.store else { return }
            switch state {
            case .inside:
                if !store.isAtOffice { self.arrived(at: now) }
            case .outside:
                self.handleOutside(at: now)
            default:
                break
            }
        }
    }

    /// Ask for the state only once iOS really monitors the region; earlier answers are "unknown".
    nonisolated func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        guard region.identifier == Self.regionID else { return }
        manager.requestState(for: region)
    }

    nonisolated private static func center(of region: CLRegion) -> CLLocationCoordinate2D? {
        guard region.identifier == regionID, let circle = region as? CLCircularRegion else { return nil }
        return circle.center
    }

    /// Events for a replaced office region can still arrive; only the current place counts.
    private func belongsToOffice(_ center: CLLocationCoordinate2D) -> Bool {
        store?.settings.office?.matches(latitude: center.latitude, longitude: center.longitude) ?? false
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?,
                                     withError error: Error) {
        let message = Self.message(for: error)
        Task { @MainActor in self.lastError = message }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            if self.setupRequested {
                self.setupRequested = false
                self.setupLocation = location
                self.lastError = nil
            }
            if self.verificationPending {
                self.verificationPending = false
                self.verify(with: location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = Self.message(for: error)
        Task { @MainActor in
            self.verificationPending = false // silent background check; retried on next activation
            if self.setupRequested {
                self.setupRequested = false
                self.lastError = message
            }
        }
    }

    // MARK: Events

    /// Clearly outside the circle (radius plus measuring error) means the open stay is over.
    private func verify(with location: CLLocation) {
        guard let office = store?.settings.office, location.horizontalAccuracy >= 0 else { return }
        let distance = location.distance(from: CLLocation(latitude: office.latitude, longitude: office.longitude))
        if distance > office.radius + max(location.horizontalAccuracy, 50) {
            handleOutside(at: Date())
        }
    }

    /// An open stay while outside: one from an earlier office place is dropped, any other is closed now
    /// (its exit event was missed).
    private func handleOutside(at time: Date) {
        guard let store, let office = store.settings.office, let arrival = store.openVisitArrival else { return }
        if office.isStale(openArrival: arrival) {
            store.discardOpenVisit()
        } else {
            left(at: time)
        }
    }

    private func arrived(at time: Date) {
        guard let store else { return }
        store.recordArrival(at: time)
        notify(String(localized: "Ankunft erfasst: \(time.formatted(date: .omitted, time: .shortened))"))
    }

    private func left(at time: Date) {
        guard let store else { return }
        store.recordDeparture(at: time)
        let date = LocalDate(date: time, calendar: .current)
        let worked = Calculator.worked(store.day(date))
        notify(String(localized: "Verlassen erfasst: \(time.formatted(date: .omitted, time: .shortened)) · heute \(HoursFormat.plain(worked))"))
    }

    private func notify(_ text: String) {
        guard store?.settings.office?.notify == true else { return }
        let content = UNMutableNotificationContent()
        content.title = "Toki"
        content.body = text
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content,
                                                                     trigger: nil))
    }
}
