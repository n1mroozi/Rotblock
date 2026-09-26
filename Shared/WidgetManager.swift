//
//  WidgetManager.swift
//  Rotblock
//
//  Created by n1 on 5/10/26

import Foundation
import WidgetKit

// MARK: - Executor (main app implements)

/// Implemented by `PresetActivationService` in the main app target.
@MainActor
protocol WidgetPresetCommandExecutor: AnyObject {
    /// Mirror of `PresetActivationService.activate` (same semantics + side effects).
    @discardableResult
    func activatePresetFromWidgetBridge(_ preset: PresetValues) -> String?
    /// Mirror of `PresetActivationService.deactivate`.
    func deactivatePresetFromWidgetBridge(_ preset: PresetValues)
}

// MARK: - WidgetManager

enum WidgetManager {
    enum Constants {
        static let appGroupSuite = "group.com.n1labs.rotblock"
        static let presetWidgetKind = "com.n1labs.rotblock.PresetWidget"
        static let activityWidgetKind = "com.n1labs.rotblock.ActivityWidget"
        /// Must match `PresetStore` storage key.
        static let savedSelectionPresetsKey = "saved_selection_presets"
        /// Must stay in sync with `DeviceActivityManager`’s `activePresetIDsKey`.
        static let activePresetIDsDataKey = "DeviceActivityManager.activePresetIDs.v1"
        static let pendingFreshnessSeconds: TimeInterval = 5

        enum PendingKey {
            static let presetID = "rb.widget.pendingPresetID"
            static let activate = "rb.widget.pendingActivate"
            static let queuedAtEpoch = "rb.widget.pendingAt"
        }

        enum ScreenTimeCache {
            static let totalMinutesToday = "rb.activity.totalMinutesToday"
            static let pickupsToday = "rb.activity.pickupsToday"
            static let notificationsToday = "rb.activity.notificationsToday"
            static let lastUpdatedAt = "rb.activity.lastUpdatedAt"
        }
    }

    /// Shared app group defaults used by widgets and the host app.
    static var appGroupUserDefaults: UserDefaults? {
        UserDefaults(suiteName: Constants.appGroupSuite)
    }

    /// Active presets as persisted by `DeviceActivityManager` (`[UUIDString]` JSON).
    static func activePresetUUIDStrings(from defaults: UserDefaults? = appGroupUserDefaults) -> Set<String> {
        guard let data = defaults?.data(forKey: Constants.activePresetIDsDataKey),
              let ids = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(ids)
    }

    /// Pending toggle written by `ActivatePresetIntent` (for transient “Starting…” UI).
    static func pendingUISnapshot(from defaults: UserDefaults? = appGroupUserDefaults) -> PendingUISnapshot? {
        guard let defaults else { return nil }
        guard let id = defaults.string(forKey: Constants.PendingKey.presetID) else { return nil }
        let activate =
            defaults.object(forKey: Constants.PendingKey.activate) != nil
            ? defaults.bool(forKey: Constants.PendingKey.activate)
            : true
        let epoch = defaults.double(forKey: Constants.PendingKey.queuedAtEpoch)
        let at = epoch > 0 ? Date(timeIntervalSince1970: epoch) : Date()
        return PendingUISnapshot(widgetPresetUUIDString: id, showingActivateState: activate, queuedAt: at)
    }

    struct PendingUISnapshot {
        let widgetPresetUUIDString: String
        let showingActivateState: Bool
        let queuedAt: Date
    }

    static func enqueuePendingPresetToggle(presetIDString: String, activate: Bool) {
        guard let d = appGroupUserDefaults else { return }
        d.set(presetIDString, forKey: Constants.PendingKey.presetID)
        d.set(activate, forKey: Constants.PendingKey.activate)
        d.set(Date().timeIntervalSince1970, forKey: Constants.PendingKey.queuedAtEpoch)
    }

    struct PendingPresetAction {
        let presetID: UUID
        let activate: Bool
        let queuedAt: Date
    }

    /// Reads pending action without clearing (optional diagnostics).
    static func peekPendingPresetAction() -> PendingPresetAction? {
        guard let d = appGroupUserDefaults,
              let idString = d.string(forKey: Constants.PendingKey.presetID),
              let uuid = UUID(uuidString: idString)
        else { return nil }
        let activate =
            d.object(forKey: Constants.PendingKey.activate) != nil
            ? d.bool(forKey: Constants.PendingKey.activate)
            : true
        let epoch = d.double(forKey: Constants.PendingKey.queuedAtEpoch)
        let at = epoch > 0 ? Date(timeIntervalSince1970: epoch) : Date()
        return PendingPresetAction(presetID: uuid, activate: activate, queuedAt: at)
    }

    static func clearPendingPresetAction() {
        guard let d = appGroupUserDefaults else { return }
        d.removeObject(forKey: Constants.PendingKey.presetID)
        d.removeObject(forKey: Constants.PendingKey.activate)
        d.removeObject(forKey: Constants.PendingKey.queuedAtEpoch)
    }

    /// Clears queued widget action and returns what was queued.
    static func takePendingPresetAction() -> PendingPresetAction? {
        guard let result = peekPendingPresetAction() else { return nil }
        clearPendingPresetAction()
        return result
    }

    static func isFreshPending(snapshot: PendingUISnapshot, now: Date = Date()) -> Bool {
        now.timeIntervalSince(snapshot.queuedAt) < Constants.pendingFreshnessSeconds
    }

    @MainActor
    static func reloadPresetWidgetTimelines() {
        WidgetCenter.shared.reloadTimelines(ofKind: Constants.presetWidgetKind)
    }

    /// Called on app launch / foreground: apply widget “Start/Stop” queue using the real activation service.
    @MainActor
    static func consumePendingPresetActionIfNeeded(
        executor: WidgetPresetCommandExecutor,
        presetNotFoundHandler: ((UUID) -> Void)? = nil
    ) {
        guard let pending = takePendingPresetAction() else { return }
        guard let preset = PresetStore.shared.preset(id: pending.presetID) else {
            presetNotFoundHandler?(pending.presetID)
            return
        }
        if pending.activate {
            _ = executor.activatePresetFromWidgetBridge(preset)
        } else {
            executor.deactivatePresetFromWidgetBridge(preset)
        }
    }
}
