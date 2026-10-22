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
        // Not tied to a view's task: a session cover would cancel it.
        Task { await DuoTour.shared.run() }
        #endif
        ConversionDiagnostics.recordAppOpen()
        ReviewPromptTracker.recordAppLaunch()
        #if DEBUG && HAS_REVENUECAT
        if RevenueCatProbe.isEnabled {
            SubscriptionService.shared.configure()
            // Same entry point the real paywall screens call, so what this
            // proves is the actual path and not a parallel one.
            SubscriptionService.shared.trackPaywallImpression(id: RevenueCatProbe.impressionID)
            if RevenueCatProbe.wantsPurchase {
                Task {
                    await SubscriptionService.shared.fetchProducts()
                    // Logged rather than asserted: when the Test Store sheet
                    // never appears, this separates "no packages came back"
                    // from "purchase threw".
                    NSLog("RCPROBE packages=%d", SubscriptionService.shared.products.count)
                    guard let package = SubscriptionService.shared.products.first else { return }
                    do {
                        let outcome = try await SubscriptionService.shared.purchase(package)
                        NSLog("RCPROBE purchase outcome=%@", String(describing: outcome))
                    } catch {
                        NSLog("RCPROBE purchase error=%@", String(describing: error))
                    }
                }
            }
        }
        #endif
    }

    #if DEBUG
    /// Marketing capture: a believable month of relief history for the
    /// History screenshot (varied causes, mostly-improved ratings).
    private static func seedDemoData() {
        let context = DataService.sharedModelContainer.mainContext
        try? context.delete(model: ReliefEpisode.self)
        let script: [(daysAgo: Int, cause: NauseaCause, mode: ReliefMode, before: Int, after: Int?, source: EpisodeSource)] = [
            (0, .motion, .pulse, 4, 2, .watch), (1, .motion, .breathe, 3, 1, .watch),
            (2, .anxiety, .breathe, 3, 2, .phone), (4, .motion, .pulse, 4, 2, .watch),
            (5, .vertigo, .tone, 3, 3, .phone), (7, .motion, .pulse, 5, 2, .watch),
            (8, .hangover, .press, 4, 2, .watch), (10, .motion, .pulse, 3, 1, .watch),
            (12, .general, .breathe, 4, 2, .watch), (13, .anxiety, .breathe, 3, 2, .watch),
            (15, .motion, .pulse, 4, 1, .watch), (17, .general, .tone, 3, 2, .phone),
            (19, .motion, .pulse, 4, 2, .watch), (21, .vertigo, .breathe, 4, 3, .watch),
            (22, .motion, .pulse, 3, 1, .watch), (25, .hangover, .press, 5, 3, .watch),
            (27, .motion, .pulse, 4, 2, .watch), (29, .motion, .pulse, 3, nil, .watch),
        ]
        for item in script {
            let start = Calendar.current.date(byAdding: .day, value: -item.daysAgo, to: .now)!
                .addingTimeInterval(-Double.random(in: 0...6) * 3600)
            context.insert(ReliefEpisode(
                startedAt: start,
                endedAt: start.addingTimeInterval(18 * 60),
                cause: item.cause,
                mode: item.mode,
                severityBefore: item.before,
                severityAfter: item.after,
                intensity: min(item.before * 2, 10),
                plannedMinutes: 18,
                source: item.source
            ))
        }
        try? context.save()
        AppSettings.shared.showHistoryHeatmap = true
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
    @State private var saveFailures = SaveFailureReporter.shared

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
        .alert(
            "Not saved",
            isPresented: Binding(
                get: { saveFailures.message != nil },
                set: { if !$0 { saveFailures.message = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveFailures.message ?? "")
        }
    }
}
