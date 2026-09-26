import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import OSLog

private let monitorLog = Logger(subsystem: "com.n1labs.rotblock", category: "RBMonitor")

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
  private let defaults = UserDefaults(suiteName: "group.com.n1labs.rotblock")
  private let decoder = PropertyListDecoder()
  /// Must match DeviceActivityManager.makeActivityName namespace.
  private let activityPrefix = "DeviceActivityManager."

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)

    guard activity.rawValue.hasPrefix(activityPrefix) else { return }

    if isAllowedHourBlockActivity(activity) {
      // End of blocked segment => allow usage again.
      clearShield(for: activity)
      monitorLog.info("Allowed-hour shield OFF \(activity.rawValue, privacy: .public)")
      return
    }

    guard let selection = loadSelectionForActivity(activity) else {
      monitorLog.error(
        "No saved selection found for activity \(activity.rawValue, privacy: .public)")
      return
    }
    applyShield(selection, for: activity)
    monitorLog.info("Timer shield applied for activity \(activity.rawValue, privacy: .public)")
  }

  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)

    guard activity.rawValue.hasPrefix(activityPrefix) else { return }
    guard isAllowedHourBlockActivity(activity) else { return }

    guard let selection = loadSelectionForActivity(activity) else {
      monitorLog.error("No selection for allowed-hour start \(activity.rawValue, privacy: .public)")
      return
    }

    applyShield(selection, for: activity)
    monitorLog.info("Allowed-hour shield ON \(activity.rawValue, privacy: .public)")
  }

  private func loadSelection(
    activity: DeviceActivityName,
    event: DeviceActivityEvent.Name
  ) -> FamilyActivitySelection? {
    guard let defaults else { return nil }
    let key = "\(activity.rawValue).\(event.rawValue)"
    guard let data = defaults.data(forKey: key) else { return nil }
    return try? decoder.decode(FamilyActivitySelection.self, from: data)
  }

  private func isAllowedHourBlockActivity(_ activity: DeviceActivityName) -> Bool {
    let raw = activity.rawValue
    return raw.hasSuffix("-ah-morning") || raw.hasSuffix("-ah-evening")
  }

  private func store(for activity: DeviceActivityName) -> ManagedSettingsStore {
    let stripped = activity.rawValue.replacingOccurrences(of: activityPrefix, with: "")
    if let id = UUID(uuidString: String(stripped.prefix(36))) {
      return ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue: id.uuidString))
    }
    return ManagedSettingsStore()
  }

  private func clearShield(for activity: DeviceActivityName) {
    let s = store(for: activity)
    s.shield.applications = nil
    s.shield.applicationCategories = nil
    s.shield.webDomains = nil
  }

  private func applyShield(_ selection: FamilyActivitySelection, for activity: DeviceActivityName) {
    let s = store(for: activity)
    s.shield.applications = selection.applicationTokens
    s.shield.applicationCategories = .specific(selection.categoryTokens)
    s.shield.webDomains = selection.webDomainTokens
  }

  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    if isAllowedHourBlockActivity(activity) { return }
    super.eventDidReachThreshold(event, activity: activity)
    guard activity.rawValue.hasPrefix(activityPrefix) else { return }
    guard let selection = loadSelection(activity: activity, event: event) else { return }
    applyShield(selection, for: activity)
    monitorLog.info("Threshold shield applied for activity \(activity.rawValue, privacy: .public)")
  }

  // MARK: - Helpers

  private func loadSelectionForActivity(_ activity: DeviceActivityName) -> FamilyActivitySelection? {
    guard let defaults else { return nil }
    let prefix = "\(activity.rawValue)."
    // DeviceActivityManager stores keys as "\(activity.rawValue).\(event.rawValue)".
    for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
      guard let data = defaults.data(forKey: key) else { continue }
      if let selection = try? decoder.decode(FamilyActivitySelection.self, from: data) {
        return selection
      }
    }
    return nil
  }

  override func intervalWillEndWarning(for activity: DeviceActivityName) {
    super.intervalWillEndWarning(for: activity)

    let appUnlockStore = AppUnlockStore()
    guard let activityId = UUID(uuidString: activity.rawValue) else { return }
    guard let application = appUnlockStore.getApplicationProfile(id: activityId) else { return }

    guard let token = application.appToken else {
      monitorLog.error("Application \(application.id) has no token")
      return
    }

    let activeIDs = loadActivePresetIDs()
    if activeIDs.isEmpty {
      let s = ManagedSettingsStore()
      if var apps = s.shield.applications {
        apps.insert(token)
        s.shield.applications = apps
      }
    } else {
      for id in activeIDs {
        let s = ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue: id.uuidString))
        if var apps = s.shield.applications {
          apps.insert(token)
          s.shield.applications = apps
        }
      }
    }
    appUnlockStore.removeApplicationProfile(application)
  }

  private func loadActivePresetIDs() -> Set<UUID> {
    guard let defaults,
      let data = defaults.data(forKey: "DeviceActivityManager.activePresetIDs.v1"),
      let strings = try? JSONDecoder().decode([String].self, from: data)
    else { return [] }
    return Set(strings.compactMap(UUID.init))
  }
}
