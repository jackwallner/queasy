import Foundation
import Observation
import UserNotifications

/// Daily nudges to run a Press hold.
///
/// The wristband trials did not test one long hold; they spaced holds through
/// the day, which is the part people forget. So this schedules a small number
/// of repeating local notifications rather than one, and says what to do rather
/// than what will happen.
@MainActor
@Observable
final class PressReminderService {
    static let shared = PressReminderService()

    /// Hours of the day, matching how the trials spaced their holds and when
    /// pregnancy sickness tends to bite: first thing, mid-afternoon, evening.
    static let hours = [8, 14, 20]

    private static let identifierPrefix = "queasy.press.reminder."
    private static let enabledKey = "pressRemindersEnabled"

    private let defaults: UserDefaults

    private init() {
        defaults = UserDefaults(suiteName: queasyAppGroupID) ?? .standard
        isEnabled = defaults.bool(forKey: Self.enabledKey)
    }

    private(set) var isEnabled: Bool
    private(set) var authorizationDenied = false

    /// Turns reminders on (asking for permission the first time) or off.
    /// Returns the state it ended up in, which is not always the one asked for:
    /// permission can be refused.
    @discardableResult
    func setEnabled(_ enabled: Bool) async -> Bool {
        guard enabled else {
            cancelAll()
            store(false)
            return false
        }
        let granted = await requestAuthorization()
        guard granted else {
            authorizationDenied = true
            store(false)
            return false
        }
        authorizationDenied = false
        await schedule()
        store(true)
        return true
    }

    /// Re-lays the schedule. Called on launch so a reinstall or a system-level
    /// cleanup does not silently leave someone with reminders they enabled.
    func refresh() async {
        guard isEnabled else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            // Turned off in system Settings: reflect that rather than lying.
            store(false)
            return
        }
        await schedule()
    }

    /// Pro lapsed: reminders are a Pro feature, so they stop, but the stored
    /// preference stays so resubscribing brings them back.
    func suspendForNonSubscriber() {
        cancelAll()
    }

    private func store(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
    }

    private func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    private func schedule() async {
        let center = UNUserNotificationCenter.current()
        cancelAll()
        for hour in Self.hours {
            let content = UNMutableNotificationContent()
            content.title = "Time for a hold"
            content.body = "Three minutes of steady pressure on the inside of your wrist."
            content.sound = .default

            var components = DateComponents()
            components.hour = hour
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: Self.identifierPrefix + String(hour),
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private func cancelAll() {
        let ids = Self.hours.map { Self.identifierPrefix + String($0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    var scheduleLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "h a"
        let calendar = Calendar.current
        let times = Self.hours.compactMap { hour -> String? in
            guard let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: .now) else { return nil }
            return formatter.string(from: date)
        }
        return times.joined(separator: ", ")
    }
}
