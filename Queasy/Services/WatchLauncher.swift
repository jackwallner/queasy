import Foundation

/// Sends the chosen plan to Queasy on Apple Watch. watchOS only allows the
/// Extended Runtime session to start once the watch app is active, so a phone
/// request either starts immediately when the watch app is reachable or waits
/// for the user to open Queasy on the watch.
@MainActor
final class WatchLauncher {
    static let shared = WatchLauncher()

    private init() {}

    enum Outcome {
        /// The watch app is reachable and will start the plan now.
        case started
        /// The plan is queued and starts when the user opens Queasy on the watch.
        case queued
    }

    func startOnWatch(plan: ReliefPlan) async -> Outcome {
        // Every phone-initiated start wants the remote controls to follow.
        WatchSessionMirror.shared.pendingAutoPresent = true
        // Send the plan first so it's waiting when the watch app wakes.
        QueasySyncService.shared.sendPlan(plan, autoStart: true)
        AnalyticsService.sentToWatch(intensity: plan.intensity)

        return QueasySyncService.shared.isWatchReachable ? .started : .queued
    }
}
