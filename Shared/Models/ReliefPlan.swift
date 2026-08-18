import Foundation

/// The occasion, not a diagnosis. Drives intensity caps, duration, and tips.
///
/// `morningSickness` came out in 2026-07 during the 1.1.6 fallout and comes back
/// in the 2026-08 rebuild. Naming when someone might use the app was never the
/// problem; promising what it would do to them was. See `docs/positioning.md`.
enum NauseaCause: String, Codable, CaseIterable, Identifiable, Sendable {
    case motion
    case morningSickness
    case hangover
    case vertigo
    case anxiety
    case general

    var id: String { rawValue }

    var label: String {
        switch self {
        case .motion: return "Motion sickness"
        case .morningSickness: return "Morning sickness"
        case .hangover: return "Hangover"
        case .vertigo: return "Vertigo / dizziness"
        case .anxiety: return "Nervous stomach"
        case .general: return "Illness / other"
        }
    }

    var shortLabel: String {
        switch self {
        case .motion: return "Motion"
        case .morningSickness: return "Morning"
        case .hangover: return "Hangover"
        case .vertigo: return "Vertigo"
        case .anxiety: return "Nerves"
        case .general: return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .motion: return "car.fill"
        case .morningSickness: return "sunrise.fill"
        case .hangover: return "wineglass"
        case .vertigo: return "tornado"
        case .anxiety: return "brain.head.profile"
        case .general: return "cross.case"
        }
    }

    /// Shown under the occasion when there is a reason to involve a clinician.
    /// Not a diagnosis, and not conditional on anything the app measures.
    var safetyNote: String? {
        switch self {
        case .morningSickness:
            return "If you cannot keep fluids down for a day, are losing weight, or feel faint, call your midwife or doctor. Sickness in pregnancy can get serious and there is treatment for it."
        case .vertigo:
            return "New, severe or one-sided spinning is worth a doctor's opinion rather than an app's."
        case .motion, .hangover, .anxiety, .general:
            return nil
        }
    }
}

/// The three-question symptom check-in.
struct CheckIn: Codable, Sendable, Equatable {
    var cause: NauseaCause
    /// 1 (barely) … 5 (about to be sick)
    var severity: Int
    /// Still in the car / still smelling it / wave still building.
    var stillExposed: Bool
    /// Ate within the last hour — start gentler on a full stomach.
    var recentlyAte: Bool
    /// Set once the user picks a mode on the recommendation screen; nil means
    /// "whatever the engine suggests for this occasion".
    var mode: ReliefMode? = nil
}

enum PulseStrength: String, Codable, Sendable {
    case soft
    case medium
    case strong
}

/// The after-session rating: three simple choices, shared by the watch and the
/// iPhone so both map a feeling to the same after-severity (single source of
/// truth, no drift between the two surfaces).
enum ReliefFeeling: String, Sendable, CaseIterable {
    case better
    case same
    case worse

    /// Turn the feeling into a 1…5 after-severity, relative to how bad it was
    /// before. Kept intentionally coarse: the user picked a mood, not a number.
    func severityAfter(before: Int) -> Int {
        switch self {
        case .better: return max(before - 2, 1)
        case .same: return before
        case .worse: return min(before + 1, 5)
        }
    }
}

/// One period of the vibration pattern: play `burstCount` taps of `strength`,
/// then wait so consecutive periods start `interval` seconds apart.
struct PulseSpec: Codable, Sendable, Equatable {
    var interval: TimeInterval
    var burstCount: Int
    var strength: PulseStrength

    /// Gap between taps inside a burst.
    static let intraBurstGap: TimeInterval = 0.14

    /// The 10-level intensity table. Level 1 is a slow soft tick; level 10 is
    /// a rapid strong triple-tap. Indexed by `level - 1`.
    static let levels: [PulseSpec] = [
        PulseSpec(interval: 2.4, burstCount: 1, strength: .soft),
        PulseSpec(interval: 2.0, burstCount: 1, strength: .soft),
        PulseSpec(interval: 1.8, burstCount: 1, strength: .medium),
        PulseSpec(interval: 1.5, burstCount: 1, strength: .medium),
        PulseSpec(interval: 1.3, burstCount: 2, strength: .medium),
        PulseSpec(interval: 1.1, burstCount: 2, strength: .medium),
        PulseSpec(interval: 0.9, burstCount: 2, strength: .strong),
        PulseSpec(interval: 0.75, burstCount: 3, strength: .strong),
        PulseSpec(interval: 0.6, burstCount: 3, strength: .strong),
        PulseSpec(interval: 0.5, burstCount: 3, strength: .strong),
    ]

    static func forLevel(_ level: Int) -> PulseSpec {
        let clamped = min(max(level, 1), levels.count)
        return levels[clamped - 1]
    }
}

/// The engine's output: what to run and for how long.
struct ReliefPlan: Codable, Sendable, Equatable {
    var cause: NauseaCause
    /// Which of the four modes this plan runs.
    var mode: ReliefMode
    /// 1…10, indexes into `PulseSpec.levels`. Only meaningful for `.pulse`.
    var intensity: Int
    /// Only meaningful for `.breathe`.
    var breathe: BreathePattern
    var durationMinutes: Int
    var severityBefore: Int
    var tips: [String]

    var spec: PulseSpec { PulseSpec.forLevel(intensity) }

    init(
        cause: NauseaCause,
        mode: ReliefMode = .pulse,
        intensity: Int,
        breathe: BreathePattern = .relaxed,
        durationMinutes: Int,
        severityBefore: Int,
        tips: [String]
    ) {
        self.cause = cause
        self.mode = mode
        self.intensity = intensity
        self.breathe = breathe
        self.durationMinutes = durationMinutes
        self.severityBefore = severityBefore
        self.tips = tips
    }

    /// Hand-rolled so plans written by an older build (stored in the App Group,
    /// or in flight from a watch that has not updated yet) still decode. The
    /// synthesized initializer would throw on the missing `mode` key.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cause = try c.decode(NauseaCause.self, forKey: .cause)
        mode = try c.decodeIfPresent(ReliefMode.self, forKey: .mode) ?? .pulse
        intensity = try c.decode(Int.self, forKey: .intensity)
        breathe = try c.decodeIfPresent(BreathePattern.self, forKey: .breathe) ?? .relaxed
        durationMinutes = try c.decode(Int.self, forKey: .durationMinutes)
        severityBefore = try c.decode(Int.self, forKey: .severityBefore)
        tips = try c.decodeIfPresent([String].self, forKey: .tips) ?? []
    }

    /// Default plan for quick-start when no check-in was run.
    static let quickStart = ReliefPlan(
        cause: .general,
        mode: .pulse,
        intensity: 5,
        durationMinutes: 15,
        severityBefore: 3,
        tips: []
    )

    /// The free-tier default for a mode: no check-in, no tailoring, just go.
    static func quickStart(mode: ReliefMode) -> ReliefPlan {
        ReliefPlan(
            cause: .general,
            mode: mode,
            intensity: 5,
            durationMinutes: mode == .press ? PressProtocol.holdSeconds / 60 : 15,
            severityBefore: 3,
            tips: []
        )
    }
}
