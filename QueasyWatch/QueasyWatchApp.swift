import SwiftUI
import WatchKit

@main
struct QueasyWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}

struct WatchRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var engine = WatchHapticEngine.shared
    @State private var pendingPlan: ReliefPlan?
    /// Plan that asked to auto-start while the app wasn't frontmost; extended
    /// runtime sessions can only start in the foreground, so it waits here.
    @State private var deferredAutoStart: ReliefPlan?

    var body: some View {
        Group {
            switch engine.phase {
            case .idle:
                WatchHomeView(pendingPlan: $pendingPlan)
            case .running:
                WatchSessionView()
            case .rating:
                WatchRatingView()
            }
        }
        .onAppear {
            applyScreenshotArgumentIfPresent()
            QueasySyncService.shared.activate()
            QueasySyncService.shared.onPlanReceived = { plan, autoStart in
                AppSettings.shared.lastPlan = plan
                guard autoStart else {
                    pendingPlan = plan
                    return
                }
                if engine.phase == .running {
                    // Remote launch already started with the previous plan;
                    // retune to the fresh one instead of restarting.
                    engine.adopt(plan: plan)
                } else if WKApplication.shared().applicationState == .active {
                    engine.start(plan: plan)
                } else {
                    deferredAutoStart = plan
                    pendingPlan = plan
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let plan = deferredAutoStart else { return }
            deferredAutoStart = nil
            // A fresh session request overrides a lingering rating screen too,
            // not just an idle home screen.
            if engine.phase != .running {
                engine.start(plan: plan)
                pendingPlan = nil
            }
        }
    }

    /// `-QueasyWatchScreen home-<mode>|session-<mode>|rating`. A headless watch
    /// simulator can be launched but not tapped, so App Store capture needs a
    /// way in to each screen. DEBUG only, so it cannot reach a Release build.
    private func applyScreenshotArgumentIfPresent() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "-QueasyWatchScreen"),
              args.index(after: flag) < args.endIndex else { return }
        let value = args[args.index(after: flag)]

        func mode(_ suffix: String) -> ReliefMode {
            ReliefMode.allCases.first { $0.rawValue == suffix } ?? .pulse
        }

        if value.hasPrefix("home-") {
            AppSettings.shared.lastPlan = .quickStart(mode: mode(String(value.dropFirst(5))))
        } else if value.hasPrefix("session-") {
            engine.start(plan: .quickStart(mode: mode(String(value.dropFirst(8)))))
        } else if value == "rating" {
            engine.start(plan: .quickStart(mode: .pulse))
            engine.finish()
        }
        #endif
    }
}
