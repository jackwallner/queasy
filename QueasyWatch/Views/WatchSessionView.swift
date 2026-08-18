import SwiftUI

struct WatchSessionView: View {
    @State private var engine = WatchHapticEngine.shared

    private var mode: ReliefMode { engine.mode }

    var body: some View {
        VStack(spacing: 8) {
            Text(timeString(engine.remainingSeconds))
                .font(.system(.title3, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.ink2)

            switch mode {
            case .pulse, .tone:
                pulseControls
            case .breathe:
                breatheStage
            case .press:
                pressStage
            }

            Button("I'm Done") {
                engine.finish()
            }
            .tint(Theme.aqua)
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle(mode.title)
    }

    private var pulseControls: some View {
        HStack(spacing: 14) {
            Button {
                engine.adjustIntensity(by: -1)
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.bordered)
            .disabled(engine.intensity <= PatternEngine.minIntensity)

            VStack(spacing: 0) {
                Text("\(engine.intensity)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.aqua)
                    .contentTransition(.numericText())
                Text("LEVEL")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Theme.ink3)
            }

            Button {
                engine.adjustIntensity(by: 1)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.bordered)
            .disabled(engine.intensity >= PatternEngine.maxIntensity)
        }
    }

    private var breatheStage: some View {
        VStack(spacing: 4) {
            BreathingBloom(pattern: engine.plan.breathe, anchor: engine.startedAt)
                .frame(width: 84, height: 84)
            Text(engine.plan.breathe.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.ink3)
        }
    }

    private var pressStage: some View {
        VStack(spacing: 4) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Theme.aqua)
            Text("Keep the pressure on")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let clamped = max(seconds, 0)
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }
}

struct WatchRatingView: View {
    @State private var engine = WatchHapticEngine.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Feeling…")
                    .font(.headline)

                ratingButton("Better", symbol: "face.smiling", tint: Theme.aqua, feeling: .better)
                ratingButton("The same", symbol: "face.dashed", tint: Theme.sand, feeling: .same)
                ratingButton("Worse", symbol: "cloud.rain", tint: Theme.coral, feeling: .worse)

                Button("Skip") {
                    engine.complete(feeling: nil)
                }
                .font(.caption2)
                .buttonStyle(.plain)
                .foregroundStyle(Theme.ink3)
            }
        }
    }

    private func ratingButton(_ label: String, symbol: String, tint: Color, feeling: ReliefFeeling) -> some View {
        Button {
            engine.complete(feeling: feeling)
        } label: {
            Label(label, systemImage: symbol)
                .font(.system(.body, design: .rounded, weight: .semibold))
        }
        .tint(tint)
        .buttonStyle(.borderedProminent)
    }
}
