import Foundation
import UserNotifications

/// Schedules the optional "come back tomorrow" reminder (come_back_tomorrow_spec.md §8).
///
/// The reminder is always user-initiated and non-blocking: if the user has not granted
/// notification permission we request it once, and a denial simply means no reminder —
/// the in-app return card still surfaces the step. No guilt copy, no streaks, no repeats.
enum DeferredReminder {
    /// Request authorization if needed, then schedule a single local notification for
    /// `availableOn`. Returns whether a reminder was actually scheduled.
    @discardableResult
    static func schedule(at availableOn: Date) async -> Bool {
        let center = UNUserNotificationCenter.current()

        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
        guard granted else { return false }

        // Never fire in the past; UNCalendarNotificationTrigger requires a future date.
        guard availableOn > Date() else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Clear Next Step"
        content.body = "Ready to pick this back up?"
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: availableOn
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "deferred-step-reminder",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }
}
