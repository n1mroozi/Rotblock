//
//  AppUnlockStore.swift
//  Rotblock
//

import FamilyControls
import Foundation
import ManagedSettings

// MARK: - Shield daily open limit (App Group)

enum ShieldOpenLimit {
    static let suiteName = "group.com.n1labs.rotblock"
    static let countKey = "rb.shield.openCount"
    static let maxKey = "rb.shield.openMax"
    static let dayKey = "rb.shield.openDay"
    static let allowedTimeKey = "rb.shield.allowedTimeMinutes"
    static let defaultMax = 3
    static let defaultAllowedTimeMinutes = 15

    static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    static func allowedTime(defaults: UserDefaults?) -> Int {
        let configured = defaults?.integer(forKey: allowedTimeKey) ?? 0
        return configured > 0 ? configured : defaultAllowedTimeMinutes
    }

    static func todayKey() -> String {
        DateFormatters.formatGregorianDayKey()
    }

    static func rolloverOpenCountIfNewDay(defaults: UserDefaults?) {
        guard let defaults else { return }
        let today = todayKey()
        let savedDay = defaults.string(forKey: dayKey)
        if savedDay != today {
            defaults.set(today, forKey: dayKey)
            defaults.set(0, forKey: countKey)
        }
    }

    static func currentOpenCount(defaults: UserDefaults?) -> Int {
        guard let defaults else { return 0 }
        rolloverOpenCountIfNewDay(defaults: defaults)
        return defaults.integer(forKey: countKey)
    }

    static func maxOpenCount(defaults: UserDefaults?) -> Int {
        let configured = defaults?.integer(forKey: maxKey) ?? 0
        return configured > 0 ? configured : defaultMax
    }

    /// Writes App Group keys from presets that are still active. Prefer `touchedPreset` when it is still
    /// an active open-limit preset so the shield matches the last user action.
    static func reconcileSharedKeys(
        allPresets: [PresetValues],
        activePresetIDs: Set<UUID>,
        touchedPreset: PresetValues?)
    {
        guard let defaults = sharedDefaults() else { return }
        let active = allPresets.filter { activePresetIDs.contains($0.id) }
        let openLimited = active.filter { $0.hasCountedOpenBlock }

        let preset: PresetValues?
        if let touched = touchedPreset,
           activePresetIDs.contains(touched.id),
           touched.hasBlock(.open),
           let maxOpens = touched.openLimitCount,
           maxOpens > 0
        {
            preset = touched
        } else {
            preset =
                openLimited
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    .first
        }

        guard let chosen = preset, let maxOpens = chosen.openLimitCount, maxOpens > 0 else {
            defaults.removeObject(forKey: maxKey)
            defaults.removeObject(forKey: allowedTimeKey)
            return
        }

        defaults.set(maxOpens, forKey: maxKey)

        if let secs = chosen.openSessionSeconds, secs > 0 {
            defaults.set(max(1, Int(secs / 60)), forKey: allowedTimeKey)
        } else {
            defaults.removeObject(forKey: allowedTimeKey)
        }

        let today = todayKey()
        if defaults.string(forKey: dayKey) != today {
            defaults.set(today, forKey: dayKey)
            defaults.set(0, forKey: countKey)
        }
    }

    @discardableResult
    static func tryConsumeOpenSlot(defaults: UserDefaults?) -> Bool {
        guard let defaults else { return false }
        rolloverOpenCountIfNewDay(defaults: defaults)
        let maximum = maxOpenCount(defaults: defaults)
        var count = defaults.integer(forKey: countKey)
        if count >= maximum { return false }
        count += 1
        defaults.set(count, forKey: countKey)
        return true
    }
}

/// For openlimits only lowk
struct AppUnlockProfile: Codable, Hashable {
    let id: UUID
    let appTokenData: Data

    init(id: UUID = UUID(), app: ApplicationToken) {
        self.id = id
        self.appTokenData = (try? JSONEncoder().encode(app)) ?? Data()
    }

    var appToken: ApplicationToken? {
        try? JSONDecoder().decode(ApplicationToken.self, from: appTokenData)
    }
}

struct CategoryUnlockProfile: Codable, Hashable {
    let id: UUID
    let categoryTokenData: Data

    init(id: UUID = UUID(), category: ActivityCategoryToken) {
        self.id = id
        self.categoryTokenData = (try? JSONEncoder().encode(category)) ?? Data()
    }

    var categoryToken: ActivityCategoryToken? {
        try? JSONDecoder().decode(ActivityCategoryToken.self, from: categoryTokenData)
    }
}

struct AppUnlockStore {
    private let defaults = ShieldOpenLimit.sharedDefaults()
    private let appUnlockProfileKey = "appUnlockProfiles"

    // MARK: - Profiles

    func getApplicationProfiles() -> [UUID: AppUnlockProfile] {
        guard let data = defaults?.data(forKey: appUnlockProfileKey) else { return [:] }
        guard let decoded = try? JSONDecoder().decode([UUID: AppUnlockProfile].self, from: data) else {
            return [:]
        }
        return decoded
    }

    func getApplicationProfile(id: UUID) -> AppUnlockProfile? {
        getApplicationProfiles()[id]
    }

    func addApplicationProfile(_ profile: AppUnlockProfile) {
        var profiles = getApplicationProfiles()
        profiles[profile.id] = profile
        saveApplicationProfiles(profiles)
    }

    func saveApplicationProfiles(_ profiles: [UUID: AppUnlockProfile]) {
        guard let encoded = try? JSONEncoder().encode(profiles) else { return }
        defaults?.set(encoded, forKey: appUnlockProfileKey)
    }

    func removeApplicationProfile(_ profile: AppUnlockProfile) {
        var profiles = getApplicationProfiles()
        profiles.removeValue(forKey: profile.id)
        saveApplicationProfiles(profiles)
    }

    func removeApplicationProfile(id: UUID) {
        var profiles = getApplicationProfiles()
        profiles.removeValue(forKey: id)
        saveApplicationProfiles(profiles)
    }

    // MARK: - Category Profiles

    private let categoryUnlockProfileKey = "categoryUnlockProfiles"

    func getCategoryProfiles() -> [UUID: CategoryUnlockProfile] {
        guard let data = defaults?.data(forKey: categoryUnlockProfileKey) else { return [:] }
        guard let decoded = try? JSONDecoder().decode([UUID: CategoryUnlockProfile].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    func addCategoryProfile(_ profile: CategoryUnlockProfile) {
        var profiles = getCategoryProfiles()
        profiles[profile.id] = profile
        guard let encoded = try? JSONEncoder().encode(profiles) else { return }
        defaults?.set(encoded, forKey: categoryUnlockProfileKey)
    }

    func removeCategoryProfile(id: UUID) {
        var profiles = getCategoryProfiles()
        profiles.removeValue(forKey: id)
        guard let encoded = try? JSONEncoder().encode(profiles) else { return }
        defaults?.set(encoded, forKey: categoryUnlockProfileKey)
    }
}
