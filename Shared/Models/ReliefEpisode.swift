import Foundation
import SwiftData

enum EpisodeSource: String, Codable, Sendable {
    case watch
    case phone
}

/// One relief session: check-in severity going in, how the user felt coming out.
@Model
final class ReliefEpisode {
    /// Stable across the watch→phone sync so replayed transfers don't duplicate.
    @Attribute(.unique) var uuid: String
    var startedAt: Date
    var endedAt: Date?
    var causeRaw: String
    var severityBefore: Int
    var severityAfter: Int?
    var intensity: Int
    var plannedMinutes: Int
    var sourceRaw: String
    /// Optional so existing stores migrate without a schema version; episodes
    /// written before the four-mode rebuild were all Pulse.
    var modeRaw: String?

    init(
        uuid: String = UUID().uuidString,
        startedAt: Date,
        endedAt: Date? = nil,
        cause: NauseaCause,
        mode: ReliefMode = .pulse,
        severityBefore: Int,
        severityAfter: Int? = nil,
        intensity: Int,
        plannedMinutes: Int,
        source: EpisodeSource
    ) {
        self.uuid = uuid
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.causeRaw = cause.rawValue
        self.modeRaw = mode.rawValue
        self.severityBefore = severityBefore
        self.severityAfter = severityAfter
        self.intensity = intensity
        self.plannedMinutes = plannedMinutes
        self.sourceRaw = source.rawValue
    }

    var cause: NauseaCause { NauseaCause(rawValue: causeRaw) ?? .general }
    var source: EpisodeSource { EpisodeSource(rawValue: sourceRaw) ?? .phone }
    var mode: ReliefMode { modeRaw.flatMap(ReliefMode.init(rawValue:)) ?? .pulse }

    /// Positive when the user felt better after the session.
    var reliefDelta: Int? {
        guard let after = severityAfter else { return nil }
        return severityBefore - after
    }

    var actualMinutes: Int {
        guard let end = endedAt else { return 0 }
        return max(0, Int(end.timeIntervalSince(startedAt) / 60))
    }
}
