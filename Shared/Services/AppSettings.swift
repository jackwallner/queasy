import Foundation
import Observation

/// UserDefaults-backed preferences. App Group suite so a future widget can read
/// them; note App Group defaults do NOT sync across the phone/watch boundary —
/// each device keeps its own copy (plans travel via QueasySyncService).
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults: UserDefaults

    private init() {
        defaults = UserDefaults(suiteName: queasyAppGroupID) ?? .standard
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        defaultDurationMinutes = defaults.object(forKey: Keys.defaultDuration) as? Int
        watchStrengthCapRaw = defaults.string(forKey: Keys.watchStrengthCap) ?? PulseStrength.strong.rawValue
        lastPlanData = defaults.data(forKey: Keys.lastPlan)
        completedSessionCount = defaults.integer(forKey: Keys.completedSessionCount)
        phoneOnlyAcknowledged = defaults.bool(forKey: Keys.phoneOnlyAcknowledged)
        showHistoryHeatmap = defaults.bool(forKey: Keys.showHistoryHeatmap)
        hasConfirmedWatchSession = defaults.bool(forKey: Keys.hasConfirmedWatchSession)
        defaultBreatheIndex = defaults.object(forKey: Keys.defaultBreatheIndex) as? Int
    }

    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let defaultDuration = "defaultDurationMinutes"
        static let watchStrengthCap = "watchStrengthCap"
        static let lastPlan = "lastPlanJSON"
        static let completedSessionCount = "completedSessionCount"
        static let phoneOnlyAcknowledged = "phoneOnlyAcknowledged"
        static let showHistoryHeatmap = "showHistoryHeatmap"
        static let defaultBreatheIndex = "defaultBreatheIndex"
        static let hasConfirmedWatchSession = "hasConfirmedWatchSession"
    }

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    /// User confirmed in onboarding that they understand Queasy is built for
    /// Apple Watch and chose to continue with iPhone haptics only.
    var phoneOnlyAcknowledged: Bool {
        didSet { defaults.set(phoneOnlyAcknowledged, forKey: Keys.phoneOnlyAcknowledged) }
    }

    /// nil = let the engine pick per check-in.
    var defaultDurationMinutes: Int? {
        didSet { defaults.set(defaultDurationMinutes, forKey: Keys.defaultDuration) }
    }

    /// Users who find "strong" too much can cap the watch at medium/soft.
    private var watchStrengthCapRaw: String {
        didSet { defaults.set(watchStrengthCapRaw, forKey: Keys.watchStrengthCap) }
    }

    var watchStrengthCap: PulseStrength {
        get { PulseStrength(rawValue: watchStrengthCapRaw) ?? .strong }
        set { watchStrengthCapRaw = newValue.rawValue }
    }

    private var lastPlanData: Data? {
        didSet { defaults.set(lastPlanData, forKey: Keys.lastPlan) }
    }

    var lastPlan: ReliefPlan? {
        get {
            guard let data = lastPlanData else { return nil }
            return try? JSONDecoder().decode(ReliefPlan.self, from: data)
        }
        set {
            lastPlanData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }

    /// Calendar heatmap on the History tab; opt-in.
    var showHistoryHeatmap: Bool {
        didSet { defaults.set(showHistoryHeatmap, forKey: Keys.showHistoryHeatmap) }
    }

    /// Phone's own copy: true once a watch session has actually reported back
    /// as running. Until then, send-to-watch nudges the user to open the watch app.
    var hasConfirmedWatchSession: Bool {
        didSet { defaults.set(hasConfirmedWatchSession, forKey: Keys.hasConfirmedWatchSession) }
    }

    /// Feeds the review-prompt funnel.
    var completedSessionCount: Int {
        didSet { defaults.set(completedSessionCount, forKey: Keys.completedSessionCount) }
    }

    /// Index into `BreathePattern.all`, or nil to let the check-in pick from
    /// how bad the wave is.
    var defaultBreatheIndex: Int? {
        didSet { defaults.set(defaultBreatheIndex, forKey: Keys.defaultBreatheIndex) }
    }

    var defaultBreathePattern: BreathePattern? {
        guard let index = defaultBreatheIndex, BreathePattern.all.indices.contains(index) else { return nil }
        return BreathePattern.all[index]
    }

    /// Applies the user's overrides on top of an engine plan.
    func resolvedPlan(from plan: ReliefPlan) -> ReliefPlan {
        var resolved = plan
        if let override = defaultDurationMinutes {
            resolved.durationMinutes = override
        }
        if let breathe = defaultBreathePattern {
            resolved.breathe = breathe
        }
        return resolved
    }
}
