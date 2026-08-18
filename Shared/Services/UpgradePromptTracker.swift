import Foundation
import Observation

/// Decides when to offer Pro after a session, now that there is no gate on the
/// way in. The rule is the paywall playbook's: pitch after demonstrated value,
/// never on a blind launch timer. So this only fires when the session actually
/// ran and actually hit the free ceiling, which is the one moment the upgrade
/// means something concrete to the person holding the phone.
enum UpgradePromptTracker {
    /// Completed-session counts that get the offer. Deliberately offset from
    /// `ReviewPromptTracker`'s 2/5/15 so the two sheets never contend.
    private static let milestones: Set<Int> = [3, 8, 20]
    private static let cooldown: TimeInterval = 5 * 24 * 3600
    private static let lastPromptKey = "lastUpgradePromptAt"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: queasyAppGroupID) ?? .standard
    }

    static func shouldPrompt(
        isPro: Bool,
        sessionWasCapped: Bool,
        sessionCount: Int,
        reviewPromptFiring: Bool,
        now: Date = Date()
    ) -> Bool {
        guard !isPro else { return false }
        // Only ask about length when length was the thing they just ran out of.
        guard sessionWasCapped else { return false }
        // One sheet at a time; the review ask is worth more than this one.
        guard !reviewPromptFiring else { return false }
        guard milestones.contains(sessionCount) else { return false }
        let last = defaults.double(forKey: lastPromptKey)
        if last > 0, now.timeIntervalSince1970 - last < cooldown { return false }
        return true
    }

    static func recordPrompt(now: Date = Date()) {
        defaults.set(now.timeIntervalSince1970, forKey: lastPromptKey)
    }
}

/// Presents the paywall from anywhere, the same way `ReviewPromptCoordinator`
/// does: the session cover sets this and dismisses, and `RootTabView` shows the
/// sheet once the cover is out of the way.
@MainActor
@Observable
final class UpgradePromptCoordinator {
    static let shared = UpgradePromptCoordinator()
    private init() {}

    /// The impression id to attribute the presentation to, or nil for none.
    var pendingImpressionId: String?

    func request(_ impressionId: String) {
        pendingImpressionId = impressionId
    }

    func clear() { pendingImpressionId = nil }
}
