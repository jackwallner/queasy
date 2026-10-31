import Foundation
import Testing
@testable import Queasy

/// A free Pulse or Breathe session is capped at `FreeTier.sessionSeconds` on every
/// screen that starts one. The watch has no purchase state of its own, so the
/// length it is handed is the only place the cap can apply: every plan has to
/// leave the phone already capped, whichever screen asked for it.
///
/// The test bundle compiles `Shared` as well, so a bare `ReliefPlan` here would be
/// the test bundle's own copy. Whatever crosses into `WatchLauncher` is spelled
/// `Queasy.` so it is the app's type, and the app's `SubscriptionService`.
@MainActor
@Suite("Watch handoff", .serialized)
struct WatchLauncherTests {
    /// Runs one handoff as a free or a Pro user and returns what would have gone to the watch.
    private func handoff(_ plan: Queasy.ReliefPlan, isPro: Bool) async -> [Queasy.ReliefPlan] {
        let subscriptions = Queasy.SubscriptionService.shared
        let launcher = WatchLauncher.shared
        let wasPro = subscriptions.isProSubscriber
        let originalSend = launcher.send
        defer {
            subscriptions.setLocalOverride(isPro: wasPro)
            launcher.send = originalSend
            Queasy.WatchSessionMirror.shared.pendingAutoPresent = false
        }
        subscriptions.setLocalOverride(isPro: isPro)
        var sent: [Queasy.ReliefPlan] = []
        launcher.send = { plan, _ in sent.append(plan) }
        _ = await launcher.startOnWatch(plan: plan)
        return sent
    }

    private func checkInPlan(_ mode: Queasy.ReliefMode) -> Queasy.ReliefPlan {
        Queasy.PatternEngine.recommend(
            for: Queasy.CheckIn(cause: .motion, severity: 4, stillExposed: false, recentlyAte: false, mode: mode)
        )
    }

    /// The check-in's "Start on Apple Watch" hands over the plan as the engine made it.
    @Test func aFreePulseOrBreatheReachesTheWatchAtTheFreeLength() async {
        for mode in [Queasy.ReliefMode.pulse, .breathe] {
            let plan = checkInPlan(mode)
            #expect(plan.durationMinutes * 60 > Queasy.FreeTier.sessionSeconds)
            let sent = await handoff(plan, isPro: false)
            #expect(sent.map(\.durationMinutes) == [Queasy.FreeTier.sessionSeconds / 60], "\(mode.title) was not capped")
        }
    }

    @Test func proKeepsTheFullLength() async {
        for mode in [Queasy.ReliefMode.pulse, .breathe] {
            let plan = checkInPlan(mode)
            let sent = await handoff(plan, isPro: true)
            #expect(sent.map(\.durationMinutes) == [plan.durationMinutes], "\(mode.title) was shortened for Pro")
        }
    }

    /// Press is a protocol, not a length anyone chose, so it is never shortened.
    @Test func pressKeepsItsHoldForFreeUsers() async {
        let plan = Queasy.ReliefPlan.quickStart(mode: .press)
        let sent = await handoff(plan, isPro: false)
        #expect(sent.map(\.durationMinutes) == [Queasy.PressProtocol.holdSeconds / 60])
    }

    @Test func everythingElseInThePlanTravelsUnchanged() async {
        let plan = checkInPlan(.pulse)
        var expected = plan
        expected.durationMinutes = Queasy.FreeTier.sessionSeconds / 60
        let sent = await handoff(plan, isPro: false)
        #expect(sent == [expected])
    }
}
