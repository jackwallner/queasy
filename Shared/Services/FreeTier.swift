import Foundation

/// What Queasy does without Pro.
///
/// The 1.0 hard paywall was the wrong shape twice over: it asked a nauseated
/// person for card details at the worst possible moment, and in a niche this
/// small the binding constraint is ratings and word of mouth, not conversion.
/// So the free tier is not a trial. Every mode works, forever, unlimited times.
/// Pro buys length, tailoring and memory.
enum FreeTier {
    /// Free Pulse and Breathe sessions run this long. Two minutes rather than a
    /// token thirty seconds: long enough to actually settle into, and it sits
    /// between the 1-minute tone protocol and Sense Relief's 3-minute session.
    static let sessionSeconds = 120

    /// Free history goes back this far. Enough to see yesterday, not enough to
    /// see a pattern, which is what Pro is for.
    static let historyDays = 7

    static var sessionMinutesLabel: String { "2-minute" }

    /// Modes with a fixed protocol (Tone's minute, Press's three) are never
    /// shortened. Capping a timer that counts the user's own thumb would be
    /// petty, and Tone is the mode with the citation, so it should be the one
    /// people can try without friction.
    static func cappedSeconds(for mode: ReliefMode, requested: Int, isPro: Bool) -> Int {
        guard !isPro, mode.hasVariableDuration else { return requested }
        return min(requested, sessionSeconds)
    }

    static func isCapped(_ mode: ReliefMode, requested: Int, isPro: Bool) -> Bool {
        cappedSeconds(for: mode, requested: requested, isPro: isPro) < requested
    }
}

/// The things Pro unlocks, in the order they are worth paying for. Used by the
/// paywall so the bullets and the gates can never drift apart.
/// What Pro unlocks, in the order it is worth paying for. The paywall reads
/// this list, so the bullets and the gates cannot drift apart.
///
/// Note what is deliberately *not* here. The check-in is free: it is the thing
/// that makes Queasy feel like more than a buzzer, and it should be the first
/// thing anyone sees work. Live intensity control is free too, because if a
/// session feels too strong you must always be able to turn it down.
enum ProFeature: String, CaseIterable, Identifiable {
    case fullLengthSessions
    case fullHistory
    case ownRhythm
    case pressReminders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullLengthSessions: return "Sessions as long as you need"
        case .fullHistory: return "Your whole history, and what helps"
        case .ownRhythm: return "Pick your own rhythm and level"
        case .pressReminders: return "Press reminders through the day"
        }
    }

    var detail: String {
        switch self {
        case .fullLengthSessions:
            return "Pulse and Breathe run up to \(PatternEngine.maxDuration) minutes instead of \(FreeTier.sessionMinutesLabel) sessions, and keep going on your wrist with the screen off."
        case .fullHistory:
            return "Every session kept, not just the last \(FreeTier.historyDays) days, with which mode you tend to come out of feeling better."
        case .ownRhythm:
            return "Set the breathing rhythm and the pulse level yourself, and save the one that suits you as your default."
        case .pressReminders:
            return "A nudge to run a hold a few times a day, the way the wristband trials spaced them."
        }
    }

    var symbolName: String {
        switch self {
        case .fullLengthSessions: return "timer"
        case .fullHistory: return "chart.line.uptrend.xyaxis"
        case .ownRhythm: return "slider.horizontal.3"
        case .pressReminders: return "bell.badge"
        }
    }
}
