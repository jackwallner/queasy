import SwiftUI
import Testing
import UIKit
import UserNotifications
@testable import Queasy

// State machine audit repro suite, 2026-11-24. Kept out of the test target:
// copy it into QueasyTests/ to run it. A failing test is the claim; each one
// asserts its preconditions first and has a passing control beside it.
// The test bundle compiles Shared/ too, so app types are spelled `Queasy.`.

@MainActor
@Suite("State machine audit repro 2026-11-24", .serialized)
struct StateMachineAuditRepro {
    private var reminderIDs: Set<String> {
        Set(PressReminderService.hours.map { "queasy.press.reminder.\($0)" })
    }

    private func pendingReminderIDs() async -> Set<String> {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return Set(requests.map(\.identifier)).intersection(reminderIDs)
    }

    /// Lays the three daily requests with the identifiers `schedule()` uses.
    /// A headless simulator cannot answer the permission prompt, so the test
    /// adds them directly instead of through `setEnabled(true)`.
    private func layReminders() async throws {
        for hour in PressReminderService.hours {
            var components = DateComponents()
            components.hour = hour
            components.minute = 0
            let content = UNMutableNotificationContent()
            content.title = "repro"
            let request = UNNotificationRequest(
                identifier: "queasy.press.reminder.\(hour)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
            try await UNUserNotificationCenter.current().add(request)
        }
    }

    private func host<V: View>(_ view: V) throws -> UIWindow {
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "precondition: the test host has a window scene"
        )
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(
            rootView: view
                .environment(Queasy.AppSettings.shared)
                .environment(Queasy.SubscriptionService.shared)
                .modelContainer(Queasy.DataService.sharedModelContainer)
        )
        window.makeKeyAndVisible()
        return window
    }

    private func settle() async {
        try? await Task.sleep(for: .seconds(1.5))
    }

    // MARK: - B1: Press reminders outlive Pro

    /// `SettingsView.swift:160-161`: "Reminders are a Pro feature, so a lapsed
    /// subscription stops them". The only code that stops them is Settings'
    /// `.task`, which runs once, when the Settings tab first appears.
    @Test func lapsingWhileTheAppRunsStopsThePressReminders() async throws {
        let subscriptions = Queasy.SubscriptionService.shared
        let wasPro = subscriptions.isProSubscriber
        defer { subscriptions.setLocalOverride(isPro: wasPro) }

        subscriptions.setLocalOverride(isPro: true)
        try await layReminders()
        let window = try host(RootView())
        defer { window.isHidden = true }
        await settle()
        let whilePro = await pendingReminderIDs()
        #expect(whilePro == reminderIDs, "precondition: a Pro user's three reminders are scheduled")

        subscriptions.setLocalOverride(isPro: false)
        await settle()
        #expect(!subscriptions.isProSubscriber, "precondition: Pro has lapsed")
        let afterLapse = await pendingReminderIDs()
        #expect(afterLapse.isEmpty, "Pro lapsed with the app running, but the daily Press reminders are still scheduled")
    }

    /// Control: opening Settings while not Pro does stop them, so the harness
    /// can see a suspension when one happens.
    @Test func controlOpeningSettingsWhileNotProStopsThePressReminders() async throws {
        let subscriptions = Queasy.SubscriptionService.shared
        let wasPro = subscriptions.isProSubscriber
        defer { subscriptions.setLocalOverride(isPro: wasPro) }

        subscriptions.setLocalOverride(isPro: false)
        try await layReminders()
        let before = await pendingReminderIDs()
        #expect(before == reminderIDs, "precondition: the three reminders are scheduled")

        let window = try host(SettingsView())
        defer { window.isHidden = true }
        await settle()
        let after = await pendingReminderIDs()
        #expect(after.isEmpty, "Settings appearing while not Pro suspends the reminders")
    }
}
