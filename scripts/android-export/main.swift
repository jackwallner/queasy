// Exports the iOS app's pure logic as JSON so the Android port's JVM tests can
// assert parity against the real Swift, not a transcription of it.
// Run through scripts/sync-android-parity.sh.
import Foundation

func planJSON(_ p: ReliefPlan) -> [String: Any] {
    [
        "cause": p.cause.rawValue,
        "mode": p.mode.rawValue,
        "intensity": p.intensity,
        "inhale": p.breathe.inhaleSeconds,
        "exhale": p.breathe.exhaleSeconds,
        "durationMinutes": p.durationMinutes,
        "severityBefore": p.severityBefore,
        "tips": p.tips,
    ]
}

var plans: [[String: Any]] = []
for cause in NauseaCause.allCases {
    for severity in -1...7 {
        for exposed in [false, true] {
            for ate in [false, true] {
                for mode in [nil] + ReliefMode.allCases.map(Optional.some) {
                    let checkIn = CheckIn(cause: cause, severity: severity, stillExposed: exposed, recentlyAte: ate, mode: mode)
                    plans.append([
                        "input": [
                            "cause": cause.rawValue, "severity": severity, "stillExposed": exposed,
                            "recentlyAte": ate, "mode": mode?.rawValue ?? NSNull(),
                        ] as [String: Any],
                        "plan": planJSON(PatternEngine.recommend(for: checkIn)),
                    ])
                }
            }
        }
    }
}

var caps: [[String: Any]] = []
for mode in ReliefMode.allCases {
    for requested in [30, 60, 119, 120, 121, 180, 600, 2700] {
        for isPro in [false, true] {
            caps.append([
                "mode": mode.rawValue, "requested": requested, "isPro": isPro,
                "seconds": FreeTier.cappedSeconds(for: mode, requested: requested, isPro: isPro),
                "capped": FreeTier.isCapped(mode, requested: requested, isPro: isPro),
            ])
        }
    }
}

let modes: [[String: Any]] = ReliefMode.allCases.map { m in
    [
        "raw": m.rawValue, "title": m.title, "tagline": m.tagline, "blurb": m.blurb,
        "evidenceNote": m.evidenceNote ?? NSNull(), "sourceURL": m.sourceURL?.absoluteString ?? NSNull(),
        "needsHeadphones": m.needsHeadphones, "hasVariableDuration": m.hasVariableDuration,
    ]
}

let causes: [[String: Any]] = NauseaCause.allCases.map { c in
    [
        "raw": c.rawValue, "label": c.label, "shortLabel": c.shortLabel,
        "safetyNote": c.safetyNote ?? NSNull(),
        "suggestedModes": PatternEngine.suggestedModes(for: c).map(\.rawValue),
    ]
}

let feelings: [[String: Any]] = ReliefFeeling.allCases.flatMap { f in
    (1...5).map { before in ["feeling": f.rawValue, "before": before, "after": f.severityAfter(before: before)] as [String: Any] }
}

let output: [String: Any] = [
    "plans": plans,
    "caps": caps,
    "modes": modes,
    "causes": causes,
    "feelings": feelings,
    "pulseLevels": PulseSpec.levels.map { ["interval": $0.interval, "burstCount": $0.burstCount, "strength": $0.strength.rawValue] },
    "intraBurstGap": PulseSpec.intraBurstGap,
    "breathePatterns": BreathePattern.all.map { ["inhale": $0.inhaleSeconds, "exhale": $0.exhaleSeconds, "label": $0.label, "breathsPerMinute": $0.breathsPerMinute] },
    "breatheForSeverity": (-1...7).map { ["severity": $0, "inhale": PatternEngine.breathePattern(for: $0).inhaleSeconds, "exhale": PatternEngine.breathePattern(for: $0).exhaleSeconds] },
    "pressSteps": PressProtocol.steps,
    "pressHoldSeconds": PressProtocol.holdSeconds,
    "freeSessionSeconds": FreeTier.sessionSeconds,
    "freeHistoryDays": FreeTier.historyDays,
    "proFeatures": ProFeature.allCases.map { ["raw": $0.rawValue, "title": $0.title, "detail": $0.detail] },
    "quickStart": planJSON(.quickStart),
    "quickStartByMode": ReliefMode.allCases.map { planJSON(.quickStart(mode: $0)) },
]

let data = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
FileManager.default.createFile(atPath: CommandLine.arguments[1], contents: data)
print("wrote \(plans.count) plans, \(caps.count) caps to \(CommandLine.arguments[1])")
