import SwiftUI

/// The breathing pacer's visual: a circle that opens on the in-breath and
/// settles on the out-breath. Driven by wall-clock time rather than SwiftUI
/// animation so it stays in step with the haptics, which are scheduled against
/// the same clock.
struct BreathingBloom: View {
    var pattern: BreathePattern
    /// Where the cycle started. Pass the session's start date so the ring and
    /// the taps agree; defaults to now for static previews.
    var anchor: Date = .now
    var showsLabel: Bool = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let phase = BreathingBloom.phase(
                at: context.date,
                anchor: anchor,
                pattern: pattern
            )
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                ZStack {
                    Circle()
                        .stroke(Theme.paper3, lineWidth: 6)
                        .frame(width: side * 0.92, height: side * 0.92)
                    Circle()
                        .fill(Theme.aquaTint)
                        .frame(width: side * scale(phase), height: side * scale(phase))
                    Circle()
                        .stroke(Theme.aqua.opacity(0.8), lineWidth: 3)
                        .frame(width: side * scale(phase), height: side * scale(phase))
                    if showsLabel {
                        VStack(spacing: 2) {
                            Text(phase.isInhale ? "In" : "Out")
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text("\(phase.secondsLeft)")
                                .font(Theme.roundedNumeric(15, weight: .medium))
                                .foregroundStyle(Theme.ink3)
                                .monospacedDigit()
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .accessibilityHidden(true)
    }

    /// 0.42 at rest, 0.92 at the top of the in-breath, eased both ways.
    private func scale(_ phase: Phase) -> CGFloat {
        let eased = phase.progress * phase.progress * (3 - 2 * phase.progress)
        let openness = phase.isInhale ? eased : 1 - eased
        return 0.42 + 0.5 * openness
    }

    struct Phase {
        var isInhale: Bool
        /// 0…1 through the current half of the cycle.
        var progress: CGFloat
        var secondsLeft: Int
    }

    static func phase(at date: Date, anchor: Date, pattern: BreathePattern) -> Phase {
        let elapsed = max(date.timeIntervalSince(anchor), 0)
        let into = elapsed.truncatingRemainder(dividingBy: pattern.cycleSeconds)
        if into < pattern.inhaleSeconds {
            return Phase(
                isInhale: true,
                progress: CGFloat(into / pattern.inhaleSeconds),
                secondsLeft: Int((pattern.inhaleSeconds - into).rounded(.up))
            )
        }
        let out = into - pattern.inhaleSeconds
        return Phase(
            isInhale: false,
            progress: CGFloat(out / pattern.exhaleSeconds),
            secondsLeft: Int((pattern.exhaleSeconds - out).rounded(.up))
        )
    }
}
