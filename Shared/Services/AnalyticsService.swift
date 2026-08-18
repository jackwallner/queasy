import Foundation
import os

/// Lightweight structured event logger (unified logging). Swap for a real SDK
/// if the portfolio ever standardizes on one.
enum AnalyticsService {
    private static let log = Logger(subsystem: "com.jackwallner.queasy", category: "analytics")

    static func track(_ event: String, properties: [String: LosslessStringConvertible] = [:]) {
        let props = properties.isEmpty ? "" : " " + properties.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        log.notice("[\(event, privacy: .public)]\(props, privacy: .public)")
    }

    static func checkInCompleted(cause: NauseaCause, severity: Int) {
        track("checkin_completed", properties: ["cause": cause.rawValue, "severity": severity])
    }

    static func sessionStarted(source: EpisodeSource, intensity: Int, cause: NauseaCause) {
        track("session_started", properties: ["source": source.rawValue, "intensity": intensity, "cause": cause.rawValue])
    }

    static func sessionCompleted(source: EpisodeSource, minutes: Int, reliefDelta: Int?) {
        var props: [String: LosslessStringConvertible] = ["source": source.rawValue, "minutes": minutes]
        if let delta = reliefDelta { props["relief"] = delta }
        track("session_completed", properties: props)
    }

    static func sentToWatch(intensity: Int) {
        track("plan_sent_to_watch", properties: ["intensity": intensity])
    }

    static func paywallShown() {
        track("paywall_shown")
    }

    static func purchaseAttempted(plan: String) {
        track("purchase_attempted", properties: ["plan": plan])
    }

    static func purchaseCompleted(plan: String) {
        track("purchase_completed", properties: ["plan": plan])
    }
}
