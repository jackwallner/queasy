import Foundation

/// Pure check-in → plan mapping. This is the product's "algorithm"; keep it
/// deterministic and unit-tested, no side effects.
enum PatternEngine {
    static let minIntensity = 1
    static let maxIntensity = 10
    static let minDuration = 10
    static let maxDuration = 45

    /// Morning sickness sessions start gentler and run longer. A firm buzz is
    /// the last thing anyone wants on a queasy stomach, and the wave lasts.
    static let morningSicknessIntensityCap = 6

    static func recommend(for checkIn: CheckIn) -> ReliefPlan {
        let severity = min(max(checkIn.severity, 1), 5)

        var intensity = severity * 2
        if checkIn.stillExposed { intensity += 1 }
        // Full stomach: start one level gentler, ramp up manually if needed.
        if checkIn.recentlyAte { intensity -= 1 }
        intensity = min(max(intensity, minIntensity), maxIntensity)
        if checkIn.cause == .morningSickness {
            intensity = min(intensity, morningSicknessIntensityCap)
        }

        var duration = 8 + severity * 3
        if checkIn.cause == .hangover { duration += 5 }
        if checkIn.cause == .morningSickness { duration += 5 }
        duration = min(max(duration, minDuration), maxDuration)

        return ReliefPlan(
            cause: checkIn.cause,
            mode: checkIn.mode ?? suggestedModes(for: checkIn.cause)[0],
            intensity: intensity,
            breathe: breathePattern(for: severity),
            durationMinutes: duration,
            severityBefore: severity,
            tips: tips(for: checkIn)
        )
    }

    /// The modes worth offering for an occasion, best first. "Best" here means
    /// the one with the most directly relevant published work, not the one most
    /// likely to help this person, which nobody can know.
    static func suggestedModes(for cause: NauseaCause) -> [ReliefMode] {
        switch cause {
        case .motion:
            // The 100 Hz work was done on motion sickness specifically.
            return [.tone, .breathe, .pulse, .press]
        case .morningSickness:
            // The wristband trials, including the pregnancy ones, tested pressure.
            return [.press, .breathe, .pulse, .tone]
        case .vertigo:
            return [.breathe, .tone, .pulse, .press]
        case .hangover, .anxiety, .general:
            return [.breathe, .pulse, .press, .tone]
        }
    }

    /// Worse waves get a longer exhale, which is the only dial paced breathing
    /// really has.
    static func breathePattern(for severity: Int) -> BreathePattern {
        switch severity {
        case ...2: return .gentle
        case 3, 4: return .relaxed
        default: return .slower
        }
    }

    static func tips(for checkIn: CheckIn) -> [String] {
        var tips: [String]
        switch checkIn.cause {
        case .motion:
            tips = [
                "Look at the horizon or a stable point far away.",
                "Crack a window. Cool moving air helps.",
                "Skip reading or scrolling until the wave passes.",
            ]
        case .morningSickness:
            tips = [
                "An empty stomach is the usual trigger. Small and often beats three meals.",
                "Plain crackers before you sit up in the morning, if you can face them.",
                "Cold food carries less smell than hot food.",
                "Sip fluids between meals rather than with them.",
            ]
        case .hangover:
            tips = [
                "Rehydrate slowly, small sips beat big gulps.",
                "Bland carbs (toast, crackers) settle faster than grease.",
                "Dim screens and bright lights while the session runs.",
            ]
        case .vertigo:
            tips = [
                "Sit down and fix your eyes on one still object.",
                "Move your head slowly, no quick turns.",
            ]
        case .anxiety:
            tips = [
                "Breathe out longer than you breathe in: 4 in, 6 out.",
                "Drop your shoulders and unclench your jaw.",
                "Match your exhale to the pulse rhythm.",
            ]
        case .general:
            tips = [
                "Slow, steady breaths through your nose.",
                "Cool air and loose clothing help more than you'd think.",
                "Small sips of water, and avoid strong smells.",
            ]
        }
        if checkIn.stillExposed, checkIn.cause == .motion {
            tips.insert("If you're a passenger, face forward and sit up front if you can.", at: 0)
        }
        return tips
    }
}
