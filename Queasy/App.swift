import SwiftData
import SwiftUI

@main
struct QueasyApp: App {
    @State private var settings = AppSettings.shared
    @State private var subscriptions = SubscriptionService.shared

    init() {
        #if DEBUG
        // Simulator/screenshot hooks: `-QueasyResetOnboarding`, `-QueasyProOverride`,
        // `-QueasySeedDemoData` (replaces history with a month of demo episodes).
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-QueasyResetOnboarding") {
            AppSettings.shared.hasCompletedOnboarding = false
        }
        if args.contains("-QueasyProOverride") {
            SubscriptionService.shared.setLocalOverride(isPro: true)
        }
        // Marketing capture jumps straight to the app; skip onboarding + paywall.
        if args.contains("-QueasyScreenshots") {
            AppSettings.shared.hasCompletedOnboarding = true
        }
        if args.contains("-QueasySeedDemoData") {
            Self.seedDemoData()
        }
        #endif
    }

    #if DEBUG
    /// Marketing capture: a believable month of relief history for the
    /// History screenshot (varied causes, mostly-improved ratings).
    private static func seedDemoData() {
        let context = DataService.sharedModelContainer.mainContext
        try? context.delete(model: ReliefEpisode.self)
        let script: [(daysAgo: Int, cause: NauseaCause, before: Int, after: Int?, source: EpisodeSource)] = [
            (0, .motion, 4, 2, .watch), (1, .motion, 3, 1, .watch),
            (2, .anxiety, 3, 2, .phone), (4, .motion, 4, 2, .watch),
            (5, .vertigo, 3, 3, .watch), (7, .motion, 5, 2, .watch),
            (8, .hangover, 4, 2, .phone), (10, .motion, 3, 1, .watch),
            (12, .general, 4, 2, .watch), (13, .anxiety, 3, 2, .watch),
            (15, .motion, 4, 1, .watch), (17, .general, 3, 2, .phone),
            (19, .motion, 4, 2, .watch), (21, .vertigo, 4, 3, .watch),
            (22, .motion, 3, 1, .watch), (25, .hangover, 5, 3, .watch),
            (27, .motion, 4, 2, .watch), (29, .motion, 3, nil, .watch),
        ]
        for item in script {
            let start = Calendar.current.date(byAdding: .day, value: -item.daysAgo, to: .now)!
                .addingTimeInterval(-Double.random(in: 0...6) * 3600)
            context.insert(ReliefEpisode(
                startedAt: start,
                endedAt: start.addingTimeInterval(18 * 60),
                cause: item.cause,
                severityBefore: item.before,
                severityAfter: item.after,
                intensity: min(item.before * 2, 10),
                plannedMinutes: 18,
                source: item.source
            ))
        }
        try? context.save()
    }
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(subscriptions)
        }
        .modelContainer(DataService.sharedModelContainer)
    }
}

struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(SubscriptionService.self) private var subscriptions

    #if DEBUG
    private var forcePaywall: Bool {
        ProcessInfo.processInfo.arguments.contains("-QueasyPaywallScreenshot")
    }
    #else
    private var forcePaywall: Bool { false }
    #endif

    var body: some View {
        // No paywall gate. Onboarding hands straight to the app: every mode
        // works free, forever, and Pro is offered after a session has actually
        // done something. See docs/positioning.md and FreeTier.
        Group {
            if forcePaywall {
                PaywallView(displayCloseButton: false, paywallImpressionId: "queasy_screenshot")
            } else if !settings.hasCompletedOnboarding {
                OnboardingView()
            } else {
                RootTabView()
            }
        }
        .task {
            subscriptions.configure()
            QueasySyncService.shared.activate()
        }
    }
}
