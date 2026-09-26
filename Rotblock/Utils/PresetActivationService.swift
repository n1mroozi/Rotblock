//
//  PresetActivationService.swift
//  Rotblock
//
//  Created by n1 on 5/6/26.
//

import FamilyControls
import Foundation
import OSLog

private let log = Logger(subsystem: "com.n1labs.rotblock", category: "PresetActivationService")

/// Single coordinator for preset activation/deactivation.
/// Owns the three shared managers so every code path — widget, UI, app-launch — mutates the same objects.
@MainActor
@Observable
final class PresetActivationService {
    private let defaults = UserDefaults(suiteName: "group.com.n1labs.rotblock")

    let deviceActivity: DeviceActivityManager
    let locationRestriction: LocationRestrictionManager

    init() {
        let dam = DeviceActivityManager()
        self.deviceActivity = dam
        self.locationRestriction = LocationRestrictionManager(deviceActivityManager: dam)
    }

    // MARK: - Public API

    @discardableResult
    func activate(_ preset: PresetValues) -> String? {
        guard !deviceActivity.activePresetIDs.contains(preset.id) else { return nil }

        let selection = decodedSelection(for: preset)
        let activityName = preset.id.uuidString

        // Validate up front so a half-configured preset doesn't leave partial monitors running.
        if preset.hasBlock(.location),
           preset.locationLatitude == nil || preset.locationLongitude == nil
               || preset.locationRadius == nil {
            return "This preset's location block is missing a pinned location."
        }

        do {
            // Each block contributes its own enforcement. When several blocks want to drive
            // the same shield, the priority is: counted open block keeps the shield always up
            // (opens are granted through the shield itself), then the location geofence, then
            // the allowed-hours window.
            let hasCountedOpen = preset.hasCountedOpenBlock
            let hasLocation = preset.hasBlock(.location)

            if preset.hasBlock(.timer) {
                try deviceActivity.startTimerLimit(
                    activitySelection: selection,
                    timerLimitDurationSeconds: preset.timerLimitDurationSeconds ?? 0,
                    activityName: activityName
                )
            }

            if preset.hasBlock(.allowedHour) {
                try deviceActivity.startAllowedHoursMonitor(
                    activitySelection: selection,
                    allowedStartHour: preset.allowedStartHour ?? 9,
                    allowedStartMinute: preset.allowedStartMinute ?? 0,
                    allowedEndHour: preset.allowedEndHour ?? 17,
                    allowedEndMinute: preset.allowedEndMinute ?? 0,
                    activityName: activityName
                )
                let sh = preset.allowedStartHour ?? 9
                let sm = preset.allowedStartMinute ?? 0
                let eh = preset.allowedEndHour ?? 17
                let em = preset.allowedEndMinute ?? 0
                if !hasCountedOpen, !hasLocation {
                    if isNowInsideAllowedWindow(startHour: sh, startMinute: sm, endHour: eh, endMinute: em) {
                        deviceActivity.removeRestrictions(forPreset: preset.id)
                    } else {
                        deviceActivity.applyRestrictions(activitySelection: selection, forPreset: preset.id)
                    }
                }
                defaults?.set(sh, forKey: "rb.allowed.startHour")
                defaults?.set(sm, forKey: "rb.allowed.startMinute")
                defaults?.set(eh, forKey: "rb.allowed.endHour")
                defaults?.set(em, forKey: "rb.allowed.endMinute")
            }

            if preset.hasBlock(.open) {
                if !hasCountedOpen, let secs = preset.openSessionSeconds, secs > 0 {
                    // Session-only opens: block once the daily time budget is used up.
                    try deviceActivity.startOpenSessionMonitor(
                        activitySelection: selection,
                        sessionSeconds: secs,
                        activityName: "\(activityName)-open-session"
                    )
                } else {
                    // Counted opens need the shield up at all times — opens are granted
                    // through the shield's primary button.
                    deviceActivity.applyRestrictions(activitySelection: selection, forPreset: preset.id)
                }
            }

            if hasLocation {
                let mode: LocationZoneMode = (preset.locationMode == "allowed") ? .allowed : .blocked
                locationRestriction.startGeofence(
                    presetID: preset.id,
                    selection: selection,
                    latitude: preset.locationLatitude ?? 0,
                    longitude: preset.locationLongitude ?? 0,
                    radius: preset.locationRadius ?? 200,
                    mode: mode
                )
            }

            if preset.hasBlock(.timer) {
                scheduleTimerEndedLocalNotification(for: preset)
            }

            defaults?.set(preset.primaryBlockKind.rawValue, forKey: "rb.activeLimitType")
            deviceActivity.addActivePreset(preset.id)
            ShieldOpenLimit.reconcileSharedKeys(
                allPresets: PresetStore.shared.allPresets(),
                activePresetIDs: deviceActivity.activePresetIDs,
                touchedPreset: preset
            )
            log.info("Activated preset '\(preset.name)' blocks=\(preset.blocksLabel)")
            return nil
        } catch {
            deviceActivity.stopMonitor(forPresetID: preset.id)
            locationRestriction.stopGeofence(presetID: preset.id)
            deviceActivity.removeRestrictions(forPreset: preset.id)
            if preset.hasBlock(.timer) {
                LocalNotificationManager.cancelTimerPresetEnded(presetID: preset.id)
            }
            return error.localizedDescription
        }
    }

    func deactivate(_ preset: PresetValues) {
        if preset.hasBlock(.timer) {
            LocalNotificationManager.cancelTimerPresetEnded(presetID: preset.id)
        }
        deviceActivity.stopMonitor(forPresetID: preset.id)
        locationRestriction.stopGeofence(presetID: preset.id)
        deviceActivity.removeRestrictions(forPreset: preset.id)
        deviceActivity.removeActivePreset(preset.id)
        clearShieldContextIfNeeded()
        ShieldOpenLimit.reconcileSharedKeys(
            allPresets: PresetStore.shared.allPresets(),
            activePresetIDs: deviceActivity.activePresetIDs,
            touchedPreset: nil
        )
        log.info("Deactivated preset '\(preset.name)'")
    }

    // MARK: - Helpers

    /// Schedules timer-ended notification from `rb.timer.endEpoch` (`DeviceActivityManager.startTimerLimit`).
    private func scheduleTimerEndedLocalNotification(for preset: PresetValues) {
        guard (preset.timerLimitDurationSeconds ?? 0) > 0 else { return }
        let epoch = defaults?.double(forKey: "rb.timer.endEpoch") ?? 0
        guard epoch > 0 else { return }
        let endDate = Date(timeIntervalSince1970: epoch)
        Task {
            await LocalNotificationManager.scheduleTimerPresetEnded(
                presetID: preset.id,
                presetName: preset.name,
                endDate: endDate
            )
        }
    }

    private func decodedSelection(for preset: PresetValues) -> FamilyActivitySelection {
        (try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: preset.selectionData))
            ?? FamilyActivitySelection()
    }

    /// Removes type-specific UserDefaults keys for limit types that no longer have any active preset.
    private func clearShieldContextIfNeeded() {
        guard let defaults else { return }
        let remainingPresets = PresetStore.shared.allPresets().filter {
            deviceActivity.activePresetIDs.contains($0.id)
        }
        let hasAllowedHour = remainingPresets.contains { $0.hasBlock(.allowedHour) }
        let hasTimer = remainingPresets.contains { $0.hasBlock(.timer) }
        let hasOpen = remainingPresets.contains { $0.hasBlock(.open) }
        let hasLocation = remainingPresets.contains { $0.hasBlock(.location) }

        if !hasAllowedHour {
            defaults.removeObject(forKey: "rb.allowed.startHour")
            defaults.removeObject(forKey: "rb.allowed.startMinute")
            defaults.removeObject(forKey: "rb.allowed.endHour")
            defaults.removeObject(forKey: "rb.allowed.endMinute")
        }
        if !hasTimer {
            defaults.removeObject(forKey: "rb.timer.endEpoch")
        }
        if !hasOpen {
            defaults.removeObject(forKey: ShieldOpenLimit.allowedTimeKey)
        }
        if !hasAllowedHour, !hasTimer, !hasOpen, !hasLocation {
            defaults.removeObject(forKey: "rb.activeLimitType")
        }
    }

    private func isNowInsideAllowedWindow(
        startHour: Int, startMinute: Int, endHour: Int, endMinute: Int
    ) -> Bool {
        let now = Date()
        let cal = Calendar.current
        let nowMin = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let startMin = startHour * 60 + startMinute
        let endMin = endHour * 60 + endMinute
        if startMin == endMin { return true }
        if startMin < endMin { return nowMin >= startMin && nowMin < endMin }
        return nowMin >= startMin || nowMin < endMin
    }
}
