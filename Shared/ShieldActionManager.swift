import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import ManagedSettingsUI
import OSLog

private let log = Logger(subsystem: "com.n1labs.rotblock", category: "ShieldAction")

enum ShieldActionTarget {
    case application(ApplicationToken)
    case category(ActivityCategoryToken)
}

final class ShieldActionManager {
    private let defaults = UserDefaults(suiteName: "group.com.n1labs.rotblock")

    func handle(action: ShieldAction, target: ShieldActionTarget) -> ShieldActionResponse {
        log.info(
            """
            SA01 manager handle ENTER action=\(String(describing: action), privacy: .public) \
            pid=\(ProcessInfo.processInfo.processIdentifier, privacy: .public)
            """
        )

        switch action {
        case .primaryButtonPressed:
            return handlePrimary(for: target)

        case .secondaryButtonPressed:
            log.info("SA30 manager secondary CLOSE")
            return .close

        default:
            log.info("SA31 manager default CLOSE")
            return .close
        }
    }

    private func handlePrimary(for target: ShieldActionTarget) -> ShieldActionResponse {
        switch target {
        case .application(let token):
            log.info("SA02 manager primary ENTER (application)")
            guard isOpenAllowed(for: token) else {
                log.info("SA02a manager BLOCKED non-open preset (application)")
                return .close
            }
            guard ShieldOpenLimit.tryConsumeOpenSlot(defaults: defaults) else {
                log.info("SA02b manager BLOCKED limit reached (application)")
                return .close
            }

            let profile = createApplicationProfile(for: token)
            startOpenLimitMonitor(for: profile)
            unlockApp(token)
            log.info("SA07 manager primary EXIT defer (application)")
            return .defer

        case .category(let token):
            log.info("SA02 manager primary ENTER (category)")
            guard isOpenAllowed(for: token) else {
                log.info("SA02a manager BLOCKED non-open preset (category)")
                return .close
            }
            guard ShieldOpenLimit.tryConsumeOpenSlot(defaults: defaults) else {
                log.info("SA02b manager BLOCKED limit reached (category)")
                return .close
            }

            let profile = createCategoryProfile(for: token)
            startCategoryOpenLimitMonitor(for: profile)
            unlockCategory(token)
            log.info("SA07 manager primary EXIT defer (category)")
            return .defer
        }
    }

    // MARK: - Open-allowed checks (no ShieldConfigManager dependency)

    private func isOpenAllowed(for application: ApplicationToken) -> Bool {
        let activePresetsByID = loadActivePresetsByID()
        guard !activePresetsByID.isEmpty else { return false }

        for (id, preset) in activePresetsByID {
            let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue: id.uuidString))
            guard let apps = store.shield.applications, apps.contains(application) else { continue }

            if allowsOpenGrant(preset) {
                return true
            }
        }

        return false
    }

    private func isOpenAllowed(for category: ActivityCategoryToken) -> Bool {
        let activePresetsByID = loadActivePresetsByID()
        guard !activePresetsByID.isEmpty else { return false }

        for (id, preset) in activePresetsByID {
            let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue: id.uuidString))

            let matchesCategory: Bool = {
                guard let policy = store.shield.applicationCategories else { return false }
                switch policy {
                case .specific(let categories, except: _):
                    return categories.contains(category)
                case .all:
                    return true
                default:
                    return false
                }
            }()

            guard matchesCategory else { continue }

            if allowsOpenGrant(preset) {
                return true
            }
        }

        return false
    }

    /// A grant is only possible when the preset carries an open block, and — if it also carries
    /// a location block — the user is currently on the allowed side of the geofence.
    private func allowsOpenGrant(_ preset: PresetValues) -> Bool {
        guard preset.hasBlock(.open) else { return false }
        if preset.hasBlock(.location),
           LocationZoneState.isBlocked(presetID: preset.id, defaults: defaults)
        {
            return false
        }
        return true
    }

    private func loadActivePresetsByID() -> [UUID: PresetValues] {
        guard
            let defaults,
            let data = defaults.data(forKey: "saved_selection_presets"),
            let presets = try? JSONDecoder().decode([PresetValues].self, from: data)
        else { return [:] }

        let active = loadActivePresetIDs()
        var out: [UUID: PresetValues] = [:]
        for preset in presets where active.contains(preset.id) {
            out[preset.id] = preset
        }
        return out
    }

    private func loadActivePresetIDs() -> Set<UUID> {
        guard
            let defaults,
            let data = defaults.data(forKey: "DeviceActivityManager.activePresetIDs.v1"),
            let strings = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }

        return Set(strings.compactMap(UUID.init))
    }

    // MARK: - Profiles

    private func createApplicationProfile(for application: ApplicationToken) -> AppUnlockProfile {
        let profile = AppUnlockProfile(app: application)
        AppUnlockStore().addApplicationProfile(profile)
        return profile
    }

    private func createCategoryProfile(for category: ActivityCategoryToken) -> CategoryUnlockProfile {
        let profile = CategoryUnlockProfile(category: category)
        AppUnlockStore().addCategoryProfile(profile)
        return profile
    }

    // MARK: - Monitoring

    private func startOpenLimitMonitor(for profile: AppUnlockProfile) {
        log.info("SA10 manager monitor START (application)")
        let unlockMinutes = max(1, ShieldOpenLimit.allowedTime(defaults: defaults))
        let warningLeadMinutes = 15

        guard let token = profile.appToken else {
            log.error("[ShieldActionManager] Missing app token for unlock profile")
            return
        }

        let event: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            DeviceActivityEvent.Name(profile.id.uuidString): DeviceActivityEvent(
                applications: Set([token]),
                threshold: DateComponents(minute: unlockMinutes)
            )
        ]

        let totalIntervalMinutes = unlockMinutes + warningLeadMinutes
        let intervalEnd = Calendar.current.dateComponents(
            [.hour, .minute, .second],
            from: Calendar.current.date(byAdding: .minute, value: totalIntervalMinutes, to: Date.now) ?? Date.now
        )

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: intervalEnd,
            repeats: false,
            warningTime: DateComponents(hour: 0, minute: warningLeadMinutes)
        )

        do {
            try DeviceActivityCenter().startMonitoring(
                DeviceActivityName(profile.id.uuidString),
                during: schedule,
                events: event
            )
            log.info("SA14 manager monitor OK (application)")
        } catch {
            log.error("SA13 manager monitor FAILED \(String(describing: error), privacy: .public) (application)")
        }
    }

    private func startCategoryOpenLimitMonitor(for profile: CategoryUnlockProfile) {
        log.info("SA10 manager monitor START (category)")
        let unlockMinutes = max(1, ShieldOpenLimit.allowedTime(defaults: defaults))
        let warningLeadMinutes = 15

        guard let token = profile.categoryToken else {
            log.error("[ShieldActionManager] Missing category token for unlock profile")
            return
        }

        let event: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            DeviceActivityEvent.Name(profile.id.uuidString): DeviceActivityEvent(
                categories: Set([token]),
                threshold: DateComponents(minute: unlockMinutes)
            )
        ]

        let totalIntervalMinutes = unlockMinutes + warningLeadMinutes
        let intervalEnd = Calendar.current.dateComponents(
            [.hour, .minute, .second],
            from: Calendar.current.date(byAdding: .minute, value: totalIntervalMinutes, to: Date.now) ?? Date.now
        )

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: intervalEnd,
            repeats: false,
            warningTime: DateComponents(hour: 0, minute: warningLeadMinutes)
        )

        do {
            try DeviceActivityCenter().startMonitoring(
                DeviceActivityName(profile.id.uuidString),
                during: schedule,
                events: event
            )
            log.info("SA14 manager monitor OK (category)")
        } catch {
            log.error("SA13 manager monitor FAILED \(String(describing: error), privacy: .public) (category)")
        }
    }

    // MARK: - Unlocking

    private func unlockApp(_ token: ApplicationToken) {
        log.info("SA20 manager unlock START (application)")
        for id in loadActivePresetIDs() {
            let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue: id.uuidString))
            if var apps = store.shield.applications {
                apps.remove(token)
                store.shield.applications = apps
            }
        }

        let defaultStore = ManagedSettingsStore()
        if var apps = defaultStore.shield.applications {
            apps.remove(token)
            defaultStore.shield.applications = apps
        }

        log.info("SA22 manager unlock END (application)")
    }

    private func unlockCategory(_ token: ActivityCategoryToken) {
        log.info("SA20 manager unlock START (category)")
        for id in loadActivePresetIDs() {
            let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue: id.uuidString))
            removeUnlockedCategory(token, from: store)
        }

        let defaultStore = ManagedSettingsStore()
        removeUnlockedCategory(token, from: defaultStore)

        log.info("SA22 manager unlock END (category)")
    }

    private func removeUnlockedCategory(_ token: ActivityCategoryToken, from store: ManagedSettingsStore) {
        if case .specific(var categories, except: let exceptions) = store.shield.applicationCategories {
            categories.remove(token)
            store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories, except: exceptions)
        }
    }
}
