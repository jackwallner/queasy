import SwiftUI
import Testing
import UIKit
@testable import Queasy

// Regression tests for the 2026-11-24 state machine audit
// (docs/audits/state-machines-2026-11-24*.md). The test bundle compiles
// Shared/ too, so app types are spelled `Queasy.`.

@MainActor
@Suite("State machine regressions 2026-11-24", .serialized)
struct StateMachineRegressionTests {
    private let reminderIDs = Set(PressReminderService.hours.map { "queasy.press.reminder.\($0)" })

    /// Records the identifiers the service removes instead of touching the
    /// real notification center, which a CI simulator will not let hold them.
    private final class Removals {
        var ids: [String] = []
    }

    private func recordingRemovals(_ body: (Removals) async throws -> Void) async rethrows {
        let service = PressReminderService.shared
        let subscriptions = Queasy.SubscriptionService.shared
        let original = service.removeRequests
        let wasPro = subscriptions.isProSubscriber
        let removals = Removals()
        service.removeRequests = { removals.ids += $0 }
        defer {
            service.removeRequests = original
            subscriptions.setLocalOverride(isPro: wasPro)
        }
        try await body(removals)
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

    /// `SettingsView`: "Reminders are a Pro feature, so a lapsed subscription
    /// stops them". Before the fix only Settings' one-time `.task` did.
    @Test func lapsingWhileTheAppRunsStopsThePressReminders() async throws {
        try await recordingRemovals { removals in
            let subscriptions = Queasy.SubscriptionService.shared
            subscriptions.setLocalOverride(isPro: true)
            let window = try host(RootView())
            defer { window.isHidden = true }
            await settle()
            #expect(subscriptions.isProSubscriber, "precondition: Pro while the app is up")
            removals.ids = []

            subscriptions.setLocalOverride(isPro: false)
            await settle()
            #expect(!subscriptions.isProSubscriber, "precondition: Pro has lapsed")
            #expect(
                reminderIDs.isSubset(of: Set(removals.ids)),
                "Pro lapsed with the app running, but the daily Press reminders were not cancelled"
            )
        }
    }

    /// Control: Settings appearing while not Pro cancels them, with or
    /// without the fix, so the harness sees a cancel when one happens.
    @Test func controlOpeningSettingsWhileNotProStopsThePressReminders() async throws {
        try await recordingRemovals { removals in
            Queasy.SubscriptionService.shared.setLocalOverride(isPro: false)
            await settle()
            removals.ids = []
            let window = try host(SettingsView())
            defer { window.isHidden = true }
            await settle()
            #expect(reminderIDs.isSubset(of: Set(removals.ids)), "Settings appearing while not Pro cancels the reminders")
        }
    }

    /// An existing user's stored "reminders on" survives a lapse, so a
    /// resubscribe brings the reminders back; only the requests stop.
    @Test func aLapseKeepsTheStoredReminderPreference() async throws {
        let defaults = try #require(UserDefaults(suiteName: queasyAppGroupID))
        let key = "pressRemindersEnabled"
        let stored = defaults.object(forKey: key)
        defer { defaults.set(stored, forKey: key) }
        defaults.set(true, forKey: key)

        try await recordingRemovals { removals in
            await PressReminderService.shared.reconcile(isPro: false)
            #expect(reminderIDs.isSubset(of: Set(removals.ids)), "a lapse cancels the requests")
        }
        #expect(defaults.bool(forKey: key), "the stored preference stays on")
    }
}
