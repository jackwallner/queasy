import Foundation

/// Decides when to surface the review funnel: only right after a session where
/// the user said they felt better (an "active + happy" moment), at the 2nd/5th/
/// 15th completed session, never more than once per 60 days, and never again
/// once they've rated or sent feedback. UserDefaults-backed and thread-safe.
enum ReviewPromptTracker {
    private static let milestones: Set<Int> = [2, 5, 15]
    private static let cooldown: TimeInterval = 60 * 24 * 3600
    private static let lastPromptKey = "lastReviewPromptAt"
    private static let resolvedKey = "reviewPromptResolved"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: queasyAppGroupID) ?? .standard
    }

    /// Whether the user has already rated or sent feedback through the funnel;
    /// once true we never ask again.
    static var hasResolved: Bool {
        get { defaults.bool(forKey: resolvedKey) }
        set { defaults.set(newValue, forKey: resolvedKey) }
    }

    static func shouldPrompt(afterReliefDelta delta: Int?, sessionCount: Int, now: Date = Date()) -> Bool {
        guard !hasResolved else { return false }
        guard let delta, delta > 0 else { return false }
        guard milestones.contains(sessionCount) else { return false }
        let last = defaults.double(forKey: lastPromptKey)
        if last > 0, now.timeIntervalSince1970 - last < cooldown { return false }
        return true
    }

    static func recordPrompt(now: Date = Date()) {
        defaults.set(now.timeIntervalSince1970, forKey: lastPromptKey)
    }

    /// The user rated on the App Store or sent feedback: stop asking for good.
    static func markResolved() {
        hasResolved = true
    }
}
