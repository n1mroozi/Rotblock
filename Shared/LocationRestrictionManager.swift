import CoreLocation
import FamilyControls
import Foundation
import Observation
import OSLog

private let logger = Logger(
    subsystem: "com.n1labs.rotblock",
    category: "LocationRestrictionManager"
)

/// Determines how proximity to a geofence region maps to app restrictions.
enum LocationZoneMode: String, Codable, CaseIterable {
    /// Apps are blocked when the user is **outside** this region (safe zone).
    ///
    /// Entering the region lifts restrictions; exiting reapplies them.
    case allowed
    /// Apps are blocked when the user is **inside** this region (forbidden zone).
    ///
    /// Entering the region applies restrictions; exiting lifts them.
    case blocked
}

/// Shared record of whether a preset's location block currently wants the user blocked.
/// Written by `LocationRestrictionManager` on every zone transition and read by the shield
/// extensions to gate open-grants for presets that combine location + open blocks.
enum LocationZoneState {
    static func key(for presetID: UUID) -> String {
        "rb.location.blocked.\(presetID.uuidString)"
    }

    static func setBlocked(_ blocked: Bool, presetID: UUID, defaults: UserDefaults?) {
        defaults?.set(blocked, forKey: key(for: presetID))
    }

    static func isBlocked(presetID: UUID, defaults: UserDefaults?) -> Bool {
        defaults?.bool(forKey: key(for: presetID)) ?? false
    }

    static func clear(presetID: UUID, defaults: UserDefaults?) {
        defaults?.removeObject(forKey: key(for: presetID))
    }
}

// Manages geofence-based app restrictions using Core Location region monitoring.
//
// When a preset's location limit is active, apps are blocked while the user is **outside**
// the defined circular region (in `.allowed` mode). Entering the region lifts restrictions;
// exiting reapplies them. `.blocked` mode inverts this — apps are blocked while inside.

@MainActor
@Observable
final class LocationRestrictionManager: NSObject {
    private let locationManager = CLLocationManager()
    private let manager: DeviceActivityManager

    private let userDefaults = UserDefaults(suiteName: "group.com.n1labs.rotblock")
    private let encoder = PropertyListEncoder()
    private let decoder = PropertyListDecoder()

    /// The preset ID whose geofence is currently registered, if any.
    var activeGeofencePresetID: UUID?

    /// A `startGeofence` call that arrived before `.authorizedAlways` was granted.
    /// Replayed from `locationManagerDidChangeAuthorization` once authorization lands.
    private struct PendingStart {
        let presetID: UUID
        let selection: FamilyActivitySelection
        let latitude: Double
        let longitude: Double
        let radius: Double
        let mode: LocationZoneMode
    }

    private var pendingStart: PendingStart?

    init(deviceActivityManager: DeviceActivityManager) {
        self.manager = deviceActivityManager
        super.init()
        locationManager.delegate = self

        // Reconcile from CoreLocation's persistent monitored regions — geofences survive relaunch
        // but `activeGeofencePresetID` does not, so without this the UI forgets the active preset.
        if activeGeofencePresetID == nil,
           let region = locationManager.monitoredRegions.first,
           let id = UUID(uuidString: region.identifier)
        {
            activeGeofencePresetID = id
        }

        // Re-evaluate inside/outside state for every restored region so shield state matches
        // current reality — any transition missed while the app was terminated is recovered
        // via `didDetermineState`.
        refreshState()
    }

    // MARK: - Public API

    /// Registers a geofence for `presetID` and applies shields based on the user's current position.
    ///
    /// If `.authorizedAlways` has not been granted yet, the call is queued and replayed once
    /// the user grants the required authorization. The initial inside/outside state is resolved
    /// immediately via `requestState(for:)` since iOS does not fire `didEnter`/`didExit` at
    /// registration time.
    ///
    /// - Parameters:
    ///   - presetID: The preset whose selection and mode should be associated with this region.
    ///   - selection: The apps, categories, and web domains to shield.
    ///   - latitude: The latitude of the region's center coordinate.
    ///   - longitude: The longitude of the region's center coordinate.
    ///   - radius: The radius in meters. Clamped to `maximumRegionMonitoringDistance`.
    ///   - mode: Whether the region acts as a safe zone (`.allowed`) or a forbidden zone (`.blocked`).
    func startGeofence(
        presetID: UUID,
        selection: FamilyActivitySelection,
        latitude: Double,
        longitude: Double,
        radius: Double,
        mode: LocationZoneMode = .allowed
    ) {
        // Region monitoring only delivers events under `.authorizedAlways`. Queue the request
        // and kick off the Always prompt; the delegate callback replays this once granted.
        let status = locationManager.authorizationStatus
        guard status == .authorizedAlways else {
            logger.info(
                "startGeofence queued — current auth status: \(String(describing: status), privacy: .public)"
            )
            pendingStart = PendingStart(
                presetID: presetID,
                selection: selection,
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                mode: mode
            )
            if status == .notDetermined {
                locationManager.requestAlwaysAuthorization()
            } else if status == .authorizedWhenInUse {
                // WhenInUse was previously granted; request promotion to Always.
                locationManager.requestAlwaysAuthorization()
            } else {
                // .denied / .restricted — nothing we can do until the user flips the switch in Settings.
                logger.error("startGeofence cannot proceed: location authorization denied/restricted")
            }
            return
        }

        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            logger.error(
                "startGeofence cannot proceed: CLCircularRegion monitoring unavailable on this device"
            )
            return
        }

        saveGeofenceSelection(selection, forPresetID: presetID)
        saveGeofenceMode(mode, forPresetID: presetID)

        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            radius: min(radius, locationManager.maximumRegionMonitoringDistance),
            identifier: presetID.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        locationManager.startMonitoring(for: region)
        activeGeofencePresetID = presetID

        // iOS never fires didEnter/didExit for the initial state — without this,
        // a user activating the preset while already outside an .allowed zone (or inside a
        // .blocked zone) would never see their apps shielded until they crossed the boundary.
        locationManager.requestState(for: region)
    }

    /// Stops monitoring the region associated with `presetID` and removes the persisted selection and mode.
    ///
    /// - Parameter presetID: The preset whose geofence should be deregistered.
    func stopGeofence(presetID: UUID) {
        let identifier = presetID.uuidString
        for region in locationManager.monitoredRegions where region.identifier == identifier {
            locationManager.stopMonitoring(for: region)
        }
        removeGeofenceSelection(forPresetID: presetID)
        removeGeofenceMode(forPresetID: presetID)
        LocationZoneState.clear(presetID: presetID, defaults: userDefaults)
        if activeGeofencePresetID == presetID {
            activeGeofencePresetID = nil
        }
        if pendingStart?.presetID == presetID {
            pendingStart = nil
        }
    }

    /// Re-evaluates inside/outside state for every currently monitored region.
    ///
    /// Safe to call at launch and whenever the app becomes active — covers transitions
    /// that fired while the process was terminated or suspended.
    func refreshState() {
        for region in locationManager.monitoredRegions {
            locationManager.requestState(for: region)
        }
    }

    // MARK: - Shield application

    /// Applies or removes the shield for a region based on the user's position and the region's `LocationZoneMode`.
    ///
    /// Shared by `didDetermineState`, `didEnterRegion`, and `didExitRegion` so all three paths
    /// converge on identical shield behavior.
    ///
    /// - Parameters:
    ///   - isInside: `true` when the user is currently inside the region.
    ///   - identifier: The region identifier, expected to be a UUID string matching a persisted preset.
    @MainActor
    private func applyShieldState(isInside: Bool, for identifier: String) {
        guard let presetID = UUID(uuidString: identifier) else { return }
        let mode = loadGeofenceMode(for: identifier)
        let shouldBlock: Bool
        switch mode {
        case .allowed:
            // Outside an "allowed" zone → block. Inside → clear.
            shouldBlock = !isInside
        case .blocked:
            // Inside a "blocked" zone → block. Outside → clear.
            shouldBlock = isInside
        }

        // Record zone state so the shield extensions can gate open-grants by location.
        LocationZoneState.setBlocked(shouldBlock, presetID: presetID, defaults: userDefaults)

        // Presets that also carry a counted open block keep their shield up at all times;
        // the zone state above only decides whether "Grant Open" works on the shield.
        let shieldAlwaysUp = PresetStore.shared.preset(id: presetID)?.hasCountedOpenBlock ?? false

        if shouldBlock || shieldAlwaysUp {
            guard let selection = loadGeofenceSelection(forPresetID: presetID) else {
                logger.error("applyShieldState: no persisted selection for \(identifier, privacy: .public)")
                return
            }
            manager.applyImmediateRestrictions(activitySelection: selection, forPreset: presetID)
        } else {
            manager.removeRestrictions(forPreset: presetID)
        }
    }

    // MARK: - Persistence

    /// The UserDefaults key used to store the geofence selection for `presetID`.
    private func locationKey(for presetID: UUID) -> String {
        "location.geofence.\(presetID.uuidString)"
    }

    /// Persists the `FamilyActivitySelection` for the given preset's geofence.
    private func saveGeofenceSelection(_ selection: FamilyActivitySelection, forPresetID id: UUID) {
        userDefaults!.set(try? encoder.encode(selection), forKey: locationKey(for: id))
    }

    /// Removes the persisted `FamilyActivitySelection` for the given preset's geofence.
    private func removeGeofenceSelection(forPresetID id: UUID) {
        userDefaults!.removeObject(forKey: locationKey(for: id))
    }

    /// Returns the persisted `FamilyActivitySelection` for the given preset's geofence.
    ///
    /// - Parameter id: The preset whose selection should be loaded.
    /// - Returns: The decoded selection, or `nil` if none has been saved or decoding fails.
    private func loadGeofenceSelection(forPresetID id: UUID) -> FamilyActivitySelection? {
        guard let data = userDefaults!.data(forKey: locationKey(for: id)) else { return nil }
        return try? decoder.decode(FamilyActivitySelection.self, from: data)
    }

    // MARK: - Mode Persistence

    /// The UserDefaults key used to store the `LocationZoneMode` for `presetID`.
    private func modeKey(for presetID: UUID) -> String {
        "location.geofence.mode.\(presetID.uuidString)"
    }

    /// Persists the `LocationZoneMode` for the given preset's geofence.
    private func saveGeofenceMode(_ mode: LocationZoneMode, forPresetID id: UUID) {
        userDefaults!.set(mode.rawValue, forKey: modeKey(for: id))
    }

    /// Removes the persisted `LocationZoneMode` for the given preset's geofence.
    private func removeGeofenceMode(forPresetID id: UUID) {
        userDefaults!.removeObject(forKey: modeKey(for: id))
    }

    /// Returns the persisted `LocationZoneMode` for the region identified by `identifier`.
    ///
    /// Defaults to `.allowed` when no mode has been saved or the identifier is not a valid UUID.
    private func loadGeofenceMode(for identifier: String) -> LocationZoneMode {
        guard let uuid = UUID(uuidString: identifier),
              let raw = userDefaults!.string(forKey: modeKey(for: uuid)),
              let mode = LocationZoneMode(rawValue: raw)
        else { return .allowed }
        return mode
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationRestrictionManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            self.applyShieldState(isInside: true, for: region.identifier)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            self.applyShieldState(isInside: false, for: region.identifier)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didDetermineState state: CLRegionState,
        for region: CLRegion
    ) {
        Task { @MainActor in
            switch state {
            case .inside: self.applyShieldState(isInside: true, for: region.identifier)
            case .outside: self.applyShieldState(isInside: false, for: region.identifier)
            case .unknown: break
            @unknown default: break
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            logger.info("authorization changed to \(String(describing: status), privacy: .public)")

            guard status == .authorizedAlways, let pending = pendingStart else { return }
            pendingStart = nil
            startGeofence(
                presetID: pending.presetID,
                selection: pending.selection,
                latitude: pending.latitude,
                longitude: pending.longitude,
                radius: pending.radius,
                mode: pending.mode
            )
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        monitoringDidFailFor region: CLRegion?,
        withError error: Error
    ) {
        logger.error(
            "monitoringDidFailFor \(region?.identifier ?? "<nil>", privacy: .public): \(error.localizedDescription, privacy: .public)"
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("location manager failed: \(error.localizedDescription, privacy: .public)")
    }
}
