//
//  LocalNotificationManager.swift
//  Rotblock
//
//  Created by n1 on 5/10/26.
//
import Foundation
import UserNotifications

enum LocalNotificationManager {
    private static let timerEndedPrefix = "rb.timer.ended."

    // MARK: - Public API

    /// Schedules a one-shot local notification for when a timer preset ends.
    static func scheduleTimerPresetEnded(
        presetID: UUID,
        presetName: String,
        endDate: Date
    ) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        guard isNotificationsEnabled(settings.authorizationStatus) else { return }

        let secondsUntilEnd = endDate.timeIntervalSinceNow
        // UNTimeIntervalNotificationTrigger requires >= 1 second.
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, secondsUntilEnd),
            repeats: false
        )

        let content = UNMutableNotificationContent()
        content.title = "Session ended"
        content.body = "\"\(presetName)\" timer preset has ended."
        content.sound = .default
        content.threadIdentifier = "rb.timer"
        content.categoryIdentifier = "rb.timer.ended"

        let request = UNNotificationRequest(
            identifier: timerEndedIdentifier(for: presetID),
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            // Non-fatal: app logic should continue even if notification scheduling fails.
            #if DEBUG
            print("Failed to schedule timer-ended notification: \(error.localizedDescription)")
            #endif
        }
    }

    /// Cancels the pending timer-ended notification for a specific preset.
    static func cancelTimerPresetEnded(presetID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [timerEndedIdentifier(for: presetID)])
    }

    /// Cancels all pending timer-ended notifications created by this manager.
    static func cancelAllTimerPresetEnded() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(timerEndedPrefix) }

        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Registers the timer-ended notification category.
    static func registerCategoriesIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: "rb.timer.ended",
                actions: [],
                intentIdentifiers: [],
                options: []
            )
        ])
    }

    // MARK: - Helpers

    private static func timerEndedIdentifier(for presetID: UUID) -> String {
        "\(timerEndedPrefix)\(presetID.uuidString)"
    }

    private static func isNotificationsEnabled(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }
}
