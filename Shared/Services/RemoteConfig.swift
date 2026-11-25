import Foundation

/// What RevenueCat can change without a release, read from the current
/// offering's metadata (a running Experiment's variant included). Every variant
/// ships in the binary; a missing or unknown value is the control, which is
/// exactly what shipped before the reader existed. Keys that a switch reads
/// must be set the same on every offering, or an Experiment arm would flip them
/// as a side effect.
///
/// DEBUG builds can pin any key for captures: `-queasy.rc.<key> <value>`.
enum RemoteConfig {
    /// The value for `key`, or `fallback` when it is missing, not a string, or
    /// not one of the shipped variants.
    static func value<T: RawRepresentable>(_ key: String, in metadata: [String: Any]?, default fallback: T) -> T
    where T.RawValue == String {
        #if DEBUG
        if let pinned = launchOverride(key).flatMap(T.init(rawValue:)) { return pinned }
        #endif
        guard let raw = metadata?[key] as? String else { return fallback }
        return T(rawValue: raw) ?? fallback
    }

    /// On unless the metadata says "off".
    static func isOn(_ remoteSwitch: RemoteSwitch, in metadata: [String: Any]?) -> Bool {
        #if DEBUG
        if let pinned = launchOverride(remoteSwitch.rawValue) { return pinned != "off" }
        #endif
        return (metadata?[remoteSwitch.rawValue] as? String) != "off"
    }

    #if DEBUG
    private static func launchOverride(_ key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-queasy.rc.\(key)"), index + 1 < args.count else { return nil }
        return args[index + 1]
    }
    #endif
}

/// Remote off switches, for what is worth pausing without a release.
enum RemoteSwitch: String, CaseIterable, Sendable {
    /// Apple's rating prompt after a session that helped.
    case ratingPrompt = "rating_prompt"
}

/// The paywall's trial button wording. The paywall is the only trial button:
/// there is no trial page in onboarding.
enum TrialCTA: String, CaseIterable, Sendable {
    static let metadataKey = "trial_cta"

    /// Control: the length-bearing title shipped since 1.0, "Start My 7-Day
    /// Free Trial", built from the package's own trial period.
    case sevenDay = "seven_day"
    case my
    case your

    static func from(metadata: [String: Any]?) -> TrialCTA {
        RemoteConfig.value(metadataKey, in: metadata, default: .sevenDay)
    }

    /// The trial button's title. `controlTitle` is today's copy for the
    /// selected package, so the control arm is exactly what shipped.
    func paywallTitle(controlTitle: String) -> String {
        switch self {
        case .sevenDay: return controlTitle
        case .my: return String(localized: "Start My Free Trial")
        case .your: return String(localized: "Start Your Free Trial")
        }
    }

    /// The paywall's purchase button. `trialTitle` is nil when the selection
    /// has no trial this Apple Account can use: such an account is charged on
    /// day one, so its button promises no trial (3.1.2).
    func paywallButtonTitle(isLifetime: Bool, trialTitle: String?) -> String {
        if isLifetime { return String(localized: "Unlock Lifetime") }
        if let trialTitle { return paywallTitle(controlTitle: trialTitle) }
        return String(localized: "Start Queasy Pro")
    }
}
