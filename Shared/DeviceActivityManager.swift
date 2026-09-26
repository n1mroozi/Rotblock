import DeviceActivity
import FamilyControls
import ManagedSettings
import OSLog
import SwiftUI

private let managerLog = Logger(subsystem: "com.n1labs.rotblock", category: "DeviceActivityManager")

extension DeviceActivityName {
    static let temporaryUnlock = Self("DeviceActivityManager.temp-unlock-app")
}

@MainActor
@Observable
class DeviceActivityManager {
    var activitySelection = FamilyActivitySelection()
    var monitoringActivities: [String] = []
    private let deviceActivityCenter: DeviceActivityCenter = .init()
    private let eventName: DeviceActivityEvent.Name = .init(
        rawValue: nameIdentifier
    )
    private let userDefaults: UserDefaults =
        .init(suiteName: "group.com.n1labs.rotblock")!

    private static let nameIdentifier = "DeviceActivityManager"
    private let activePresetIDsKey = "DeviceActivityManager.activePresetIDs.v1"
    private let legacyActivePresetIDKey = "DeviceActivityManager.activePresetID.v1"

    var activePresetIDs: Set<UUID> = []

    init() {
        monitoringActivities = deviceActivityCenter.activities.map { self.parseActivityName($0) }

        activePresetIDs = resolveActivePresetIDs(geofenceHint: nil)
    }

    func store(for presetID: UUID) -> ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue: presetID.uuidString))
    }

    func applyRestrictions(activitySelection: FamilyActivitySelection, forPreset id: UUID) {
        managerLog.info(
            "[DAM] applyRestrictions apps=\(activitySelection.applicationTokens.count) cats=\(activitySelection.categoryTokens.count) domains=\(activitySelection.webDomainTokens.count)"
        )
        let s = store(for: id)
        s.shield.applications = activitySelection.applicationTokens
        s.shield.applicationCategories = .specific(activitySelection.categoryTokens)
        s.shield.webDomains = activitySelection.webDomainTokens
    }

    func applyImmediateRestrictions(activitySelection: FamilyActivitySelection, forPreset id: UUID) {
        applyImmediateRestrictions(
            applicationTokens: activitySelection.applicationTokens,
            categoryTokens: activitySelection.categoryTokens,
            webDomainTokens: activitySelection.webDomainTokens,
            forPreset: id
        )
    }

    func applyImmediateRestrictions(
        applicationTokens: Set<ApplicationToken>, categoryTokens: Set<ActivityCategoryToken>,
        webDomainTokens: Set<WebDomainToken>, forPreset id: UUID
    ) {
        let s = store(for: id)
        s.shield.applications = applicationTokens
        s.shield.applicationCategories = .specific(categoryTokens)
        s.shield.webDomains = webDomainTokens
    }

    func removeRestrictions(forPreset id: UUID) {
        let s = store(for: id)
        s.shield.applications = nil
        s.shield.applicationCategories = nil
        s.shield.webDomains = nil
    }

    func startMonitor(
        activitySelection: FamilyActivitySelection, shieldThreshold: TimeInterval, start: Date,
        end: Date, repeatDaily: Bool, activityName: String
    ) throws {
        let (start, end) =
            repeatDaily
                ? createRepeatDailySchedule(start: start, end: end)
                : createOneTimeSchedule(start: start, end: end)
        let deviceActivityName = makeActivityName(activityName)
        try saveSelection(
            activitySelection, activityName: deviceActivityName, eventName: eventName
        )

        let schedule = DeviceActivitySchedule(
            intervalStart: start,
            intervalEnd: end,
            repeats: repeatDaily,
            warningTime: nil
        )

        let zeroThreshold = DateComponents(hour: 0, minute: 0, second: 0)
        let event = DeviceActivityEvent(
            applications: activitySelection.applicationTokens,
            categories: activitySelection.categoryTokens,
            webDomains: activitySelection.webDomainTokens,
            threshold: shieldThreshold > 0 ? createThreshold(shieldThreshold) : zeroThreshold,
            includesPastActivity: true
        )

        try deviceActivityCenter.startMonitoring(
            deviceActivityName,
            during: schedule,
            events: [
                eventName: event
            ]
        )

        monitoringActivities.append(activityName)
    }

    func stopMonitor(activityName: String) {
        return stopMonitor(activityName: makeActivityName(activityName))
    }

    func stopMonitor(activityName: DeviceActivityName) {
        // Remove saved selection data for each event before stopping, since
        // DeviceActivityCenter won't clean up UserDefaults entries on our behalf.
        let events = getEvents(activityName: activityName, details: false)
        for item in events.keys {
            let key = makeUserDefaultsKey(activityName: activityName, eventName: item)
            removeSavedSelection(key: key)
        }

        // If the array for the activity name is empty, ie: no activities are explicitly specified,
        // this method stops monitoring all activities.
        // Also, by calling this method, any shields (restrictions) applied for the activities (within the DeviceActivityMonitor extension) will be removed automatically
        deviceActivityCenter.stopMonitoring([activityName])
        monitoringActivities.removeAll(where: { $0 == parseActivityName(activityName) })
    }

    func getEvents(activityName: String, details: Bool) -> [DeviceActivityEvent.Name:
        DeviceActivityEvent]
    {
        return getEvents(activityName: makeActivityName(activityName), details: details)
    }

    func getEvents(activityName: DeviceActivityName, details: Bool) -> [DeviceActivityEvent.Name:
        DeviceActivityEvent]
    {
        var events = deviceActivityCenter.events(for: activityName)

        if !details {
            return events
        }

        for (key, value) in events {
            let userDefaultsKey = makeUserDefaultsKey(activityName: activityName, eventName: key)
            let tokens = getSavedSelection(key: userDefaultsKey)
            events[key] = DeviceActivityEvent(
                applications: tokens.applicationTokens,
                categories: tokens.categoryTokens,
                webDomains: tokens.webDomainTokens,
                threshold: value.threshold, includesPastActivity: value.includesPastActivity
            )
        }

        return events
    }

    func getSchedule(activityName: String) -> DeviceActivitySchedule? {
        return getSchedule(activityName: makeActivityName(activityName))
    }

    /// Returns the schedule for `activityName`, or `nil` if it is not currently monitored.
    ///
    /// - Parameter activityName: The fully-qualified `DeviceActivityName`.
    /// - Returns: The active `DeviceActivitySchedule`, or `nil` if the activity is not being monitored.
    func getSchedule(activityName: DeviceActivityName) -> DeviceActivitySchedule? {
        return deviceActivityCenter.schedule(for: activityName)
    }
}

// MARK: Permission

extension DeviceActivityManager {
    /// Requests `.individual` Family Controls authorization if the status is `.notDetermined`.
    ///
    /// Silently no-ops when authorization has already been granted or denied.
    func requestFamilyControlAuthorization() async {
        let center = AuthorizationCenter.shared
        if center.authorizationStatus == .notDetermined {
            do {
                // to request authorization parental controls for FamilyControlsMember.child, use .child instead.
                try await center.requestAuthorization(for: .individual)
            } catch {
                print(error)
            }
        }
    }
}

private let encoder = PropertyListEncoder()
private let decoder = PropertyListDecoder()

// MARK: UserDefaults

extension DeviceActivityManager {
    private func saveActivePresetIDs() {
        let strings = activePresetIDs.map(\.uuidString)
        if let data = try? JSONEncoder().encode(strings) {
            userDefaults.set(data, forKey: activePresetIDsKey)
        }
        // Remove legacy single-value key so old code doesn't resurrect a stale ID.
        userDefaults.removeObject(forKey: legacyActivePresetIDKey)
    }

    private func loadActivePresetIDs() -> Set<UUID> {
        if let data = userDefaults.data(forKey: activePresetIDsKey),
           let strings = try? JSONDecoder().decode([String].self, from: data)
        {
            return Set(strings.compactMap(UUID.init))
        }
        // Migrate legacy single-value key.
        if let raw = userDefaults.string(forKey: legacyActivePresetIDKey),
           let id = UUID(uuidString: raw)
        {
            return [id]
        }
        return []
    }

    private func getSavedSelection(key: String) -> FamilyActivitySelection {
        guard let data = userDefaults.data(forKey: key),
              let selection = try? decoder.decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }
        return selection
    }

    private var currentSelectionKey: String {
        "DeviceActivityManager.currentSelection"
    }

    /// Persists `selection` to standard `UserDefaults` under `currentSelectionKey`.
    ///
    /// - Parameter selection: The `FamilyActivitySelection` to persist.
    func saveCurrentSelection(_ selection: FamilyActivitySelection) {
        let defaults = UserDefaults.standard
        defaults.set(
            try? encoder.encode(selection), forKey: currentSelectionKey
        )
    }

    /// Returns the last selection saved via `saveCurrentSelection(_:)`, or `nil` if none exists.
    ///
    /// - Returns: The decoded `FamilyActivitySelection`, or `nil` if the key is absent or decoding fails.
    func loadCurrentSelection() -> FamilyActivitySelection? {
        guard let data = UserDefaults.standard.data(forKey: currentSelectionKey)
        else {
            return nil
        }
        return try? decoder.decode(FamilyActivitySelection.self, from: data)
    }

    // MARK: - SAVE SELECTION

    private func saveSelection(
        _ selection: FamilyActivitySelection, activityName: DeviceActivityName,
        eventName: DeviceActivityEvent.Name
    ) throws {
        let data = try encoder.encode(selection)
        userDefaults.set(
            data, forKey: makeUserDefaultsKey(activityName: activityName, eventName: eventName)
        )
    }

    private func removeSavedSelection(key: String) {
        userDefaults.removeObject(forKey: key)
    }

    func addActivePreset(_ id: UUID) {
        activePresetIDs.insert(id)
        saveActivePresetIDs()
    }

    func removeActivePreset(_ id: UUID) {
        activePresetIDs.remove(id)
        saveActivePresetIDs()
    }

    /// Builds a UserDefaults key that uniquely identifies a saved selection for a specific activity/event pair.
    private func makeUserDefaultsKey(
        activityName: DeviceActivityName, eventName: DeviceActivityEvent.Name
    ) -> String {
        return "\(activityName.rawValue).\(eventName.rawValue)"
    }
}

// MARK: Helpers

extension DeviceActivityManager {
    /// Prepends the namespace identifier so activity names don't collide across apps or extensions.
    private func makeActivityName(_ activityName: String) -> DeviceActivityName {
        return DeviceActivityName("\(DeviceActivityManager.nameIdentifier).\(activityName)")
    }

    /// Strips the namespace prefix to recover the original user-visible activity name.
    private func parseActivityName(_ activityName: DeviceActivityName) -> String {
        return activityName.rawValue.replacing("\(DeviceActivityManager.nameIdentifier).", with: "")
    }

    /// Converts a `TimeInterval` into `DateComponents` (hours + minutes) for use as a `DeviceActivityEvent` threshold.
    /// Seconds are intentionally dropped — the API works at minute granularity.
    private func createThreshold(_ threshold: TimeInterval) -> DateComponents {
        let (h, m, _) = threshold.hms
        var component = DateComponents()
        component.hour = h
        component.minute = m
        return component
    }

    /// Produces date components that include year/month/day, so the schedule fires once and does not repeat across days.
    private func createOneTimeSchedule(start: Date, end: Date) -> (DateComponents, DateComponents) {
        let startComponents = Calendar.current.dateComponents(
            [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second],
            from: start
        )
        let endComponents = Calendar.current.dateComponents(
            [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second],
            from: end
        )
        return (startComponents, endComponents)
    }

    /// Produces date components with only hour/minute, allowing `DeviceActivityCenter` to repeat the schedule every day.
    private func createRepeatDailySchedule(start: Date, end: Date) -> (DateComponents, DateComponents) {
        let startComponents = Calendar.current.dateComponents(
            [.calendar, .timeZone, .hour, .minute],
            from: start
        )
        let endComponents = Calendar.current.dateComponents(
            [.calendar, .timeZone, .hour, .minute],
            from: end
        )
        return (startComponents, endComponents)
    }
}

extension TimeInterval {
    /// Decomposes the receiver into `(hours, minutes, seconds)`.
    var hms: (Int, Int, Int) {
        let time = Int(self)
        let sec = time % 60
        let min = (time / 60) % 60
        let hour = (time / 3600)
        return (hour, min, sec)
    }
}

// MARK: - Preset-based Monitoring

extension DeviceActivityManager {
    /// Starts a daily time-limit monitor.
    /// Restrictions fire once the user's usage reaches `timeLimitSeconds`.
    ///
    /// - Parameters:
    ///   - activitySelection: The apps, categories, and web domains to monitor.
    ///   - timeLimitSeconds: Daily screen-time budget in seconds. No monitor is started when this is zero.
    ///   - activityName: User-facing name used as the monitoring key.
    /// - Throws: Any error thrown by `DeviceActivityCenter.startMonitoring(_:during:events:)`.
    func startTimerLimit(
        activitySelection: FamilyActivitySelection,
        timerLimitDurationSeconds: TimeInterval,
        activityName: String
    ) throws {
        guard timerLimitDurationSeconds > 0 else { return }
        let start = Date()
        let end = start.addingTimeInterval(timerLimitDurationSeconds)
        userDefaults.set(end.timeIntervalSince1970, forKey: "rb.timer.endEpoch")
        userDefaults.set("timer", forKey: "rb.activeLimitType")

        try startMonitor(
            activitySelection: activitySelection,
            shieldThreshold: 0,
            start: start,
            end: end,
            repeatDaily: false,
            activityName: activityName
        )
    }

    /// Starts monitoring for allowed-hours mode.
    /// Two daily schedules cover the blocked windows outside the allowed window:
    /// midnight → allowedStart and allowedEnd → 23:59.
    ///
    /// - Parameters:
    ///   - activitySelection: The apps, categories, and web domains to block outside the allowed window.
    ///   - allowedStartHour: Hour component of the allowed window's start time (24-hour clock, 0–23).
    ///   - allowedStartMinute: Minute component of the allowed window's start time (0–59).
    ///   - allowedEndHour: Hour component of the allowed window's end time (24-hour clock, 0–23).
    ///   - allowedEndMinute: Minute component of the allowed window's end time (0–59).
    ///   - activityName: Base name used to derive the morning (`-ah-morning`) and evening (`-ah-evening`) monitor keys.
    /// - Throws: Any error thrown by `DeviceActivityCenter.startMonitoring(_:during:events:)`.
    func startAllowedHoursMonitor(
        activitySelection: FamilyActivitySelection,
        allowedStartHour: Int,
        allowedStartMinute: Int,
        allowedEndHour: Int,
        allowedEndMinute: Int,
        activityName: String
    ) throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Morning block: 00:00 → allowedStart (skip if allowed window begins at midnight)
        if allowedStartHour > 0 || allowedStartMinute > 0 {
            let morningEnd = calendar.date(
                bySettingHour: allowedStartHour, minute: allowedStartMinute, second: 0, of: today
            )!
            try startMonitor(
                activitySelection: activitySelection,
                shieldThreshold: 0,
                start: today,
                end: morningEnd,
                repeatDaily: true,
                activityName: "\(activityName)-ah-morning"
            )
        }

        // Evening block: allowedEnd → 23:59 (skip if allowed window ends at midnight)
        if allowedEndHour < 23 || allowedEndMinute < 59 {
            let eveningStart = calendar.date(
                bySettingHour: allowedEndHour, minute: allowedEndMinute, second: 0, of: today
            )!
            let eveningEnd = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: today)!
            try startMonitor(
                activitySelection: activitySelection,
                shieldThreshold: 0,
                start: eveningStart,
                end: eveningEnd,
                repeatDaily: true,
                activityName: "\(activityName)-ah-evening"
            )
        }
    }

    /// Stops all monitoring activities tied to a preset ID
    /// (covers time-limit, allowed-hours morning/evening, open-session, and open-window variants).
    /// Also clears the preset's named ManagedSettingsStore — system auto-clear only works for the
    /// default store.
    func stopMonitor(forPresetID id: UUID) {
        let base = id.uuidString
        stopMonitor(activityName: base)
        stopMonitor(activityName: "\(base)-ah-morning")
        stopMonitor(activityName: "\(base)-ah-evening")
        stopMonitor(activityName: "\(base)-open-session")
        stopMonitor(activityName: "\(base)-open-window")
        removeRestrictions(forPreset: id)
        removeActivePreset(id)
    }

    /// Stops every monitored activity created through `makeActivityName(_:)` (preset schedules).
    ///
    /// Use this when switching presets or tearing down so orphaned monitors do not consume the
    /// system `DeviceActivity` slot budget (`excessiveActivities`).
    func stopAllNamespacedPresetMonitors() {
        let prefix = "\(Self.nameIdentifier)."
        let activities = deviceActivityCenter.activities
        managerLog.info("[DAM] stopAllNamespacedPresetMonitors count=\(activities.count)")
        for name in activities where name.rawValue.hasPrefix(prefix) {
            stopMonitor(activityName: name)
        }
        // Clear all named stores for any tracked active presets.
        for id in activePresetIDs {
            removeRestrictions(forPreset: id)
        }
        activePresetIDs.removeAll()
        saveActivePresetIDs()
    }

    /// Starts a daily time-budget monitor for the Open Limit preset type (session-only mode).
    /// Apps are blocked once cumulative screen time reaches `sessionSeconds` for the day.
    ///
    /// - Parameters:
    ///   - activitySelection: The apps, categories, and web domains to monitor.
    ///   - sessionSeconds: Daily screen-time budget in seconds. No monitor is started when this is zero.
    ///   - activityName: User-facing name used as the monitoring key.
    /// - Throws: Any error thrown by `DeviceActivityCenter.startMonitoring(_:during:events:)`.
    func startOpenSessionMonitor(
        activitySelection: FamilyActivitySelection,
        sessionSeconds: TimeInterval,
        activityName: String
    ) throws {
        guard sessionSeconds > 0 else { return }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        try startMonitor(
            activitySelection: activitySelection,
            shieldThreshold: sessionSeconds,
            start: startOfDay,
            end: endOfDay,
            repeatDaily: true,
            activityName: activityName
        )
    }
}

// MARK: - Active Preset Reconciliation

extension DeviceActivityManager {
    func refreshActivePresetIDs(geofenceHint: UUID? = nil) {
        monitoringActivities = deviceActivityCenter.activities.map { self.parseActivityName($0) }

        let resolved = resolveActivePresetIDs(geofenceHint: geofenceHint)
        if activePresetIDs != resolved {
            activePresetIDs = resolved
        }
        saveActivePresetIDs()
    }

    func resolveActivePresetIDs(geofenceHint: UUID?) -> Set<UUID> {
        var result = Set<UUID>()

        // Restore persisted IDs that still have matching presets.
        for id in loadActivePresetIDs() {
            if PresetStore.shared.preset(id: id) != nil {
                result.insert(id)
            }
        }

        // Add any IDs discovered from live monitors not yet persisted.
        for id in allMonitoredPresetIDs() {
            if PresetStore.shared.preset(id: id) != nil {
                result.insert(id)
            }
        }

        if let id = geofenceHint, PresetStore.shared.preset(id: id) != nil {
            result.insert(id)
        }

        return result
    }

    /// Extracts all preset UUIDs from currently monitored activity names.
    /// Handles the bare `{uuid}` case and all suffixed variants by taking the leading 36 characters.
    private func allMonitoredPresetIDs() -> Set<UUID> {
        var ids = Set<UUID>()
        for deviceActivityName in deviceActivityCenter.activities {
            let stripped = parseActivityName(deviceActivityName)
            guard stripped.count >= 36 else { continue }
            if let id = UUID(uuidString: String(stripped.prefix(36))) {
                ids.insert(id)
            }
        }
        return ids
    }
}
