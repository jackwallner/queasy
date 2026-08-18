import SwiftUI

struct WatchHomeView: View {
    @Binding var pendingPlan: ReliefPlan?

    /// Nil until the wearer picks something here, so a plan pushed from the
    /// phone keeps its own mode.
    @State private var overrideMode: ReliefMode?

    /// The three modes with a wrist form. Tone needs headphones and a speaker,
    /// so it stays on the phone.
    private var wristModes: [ReliefMode] {
        ReliefMode.allCases.filter(\.runsOnWatch)
    }

    private var basePlan: ReliefPlan {
        pendingPlan ?? AppSettings.shared.lastPlan ?? .quickStart
    }

    private var plan: ReliefPlan {
        var plan = basePlan
        if let overrideMode { plan.mode = overrideMode }
        if plan.mode == .tone { plan.mode = .pulse }
        if plan.mode == .press { plan.durationMinutes = PressProtocol.holdSeconds / 60 }
        return plan
    }

    private var isFromPhone: Bool { pendingPlan != nil }

    var body: some View {
        let plan = self.plan
        ScrollView {
            VStack(spacing: 10) {
                Text(isFromPhone ? "From your iPhone" : "Quick start")
                    .font(.caption2)
                    .foregroundStyle(Theme.ink3)

                HStack(spacing: 8) {
                    Image(systemName: plan.mode.symbolName)
                        .font(.body)
                        .foregroundStyle(Theme.aqua)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(plan.mode.title)
                            .font(.headline)
                        Text(detail(for: plan))
                            .font(.caption2)
                            .foregroundStyle(Theme.ink2)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Theme.paper2, in: RoundedRectangle(cornerRadius: 12))

                Button {
                    WatchHapticEngine.shared.start(plan: plan)
                    pendingPlan = nil
                } label: {
                    Label(startLabel(for: plan.mode), systemImage: plan.mode.symbolName)
                        .font(.headline)
                }
                .tint(Theme.aqua)
                .buttonStyle(.borderedProminent)

                HStack(spacing: 6) {
                    ForEach(wristModes) { candidate in
                        Button {
                            overrideMode = candidate
                        } label: {
                            Image(systemName: candidate.symbolName)
                                .font(.footnote)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(candidate == plan.mode ? Theme.aqua : Theme.ink3)
                        .accessibilityLabel(candidate.title)
                    }
                }

                Text(hint(for: plan.mode))
                    .font(.caption2)
                    .foregroundStyle(Theme.ink3)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Queasy")
    }

    private func detail(for plan: ReliefPlan) -> String {
        switch plan.mode {
        case .press: return "\(PressProtocol.holdSeconds / 60) min hold"
        case .breathe: return "\(plan.breathe.label) · \(min(plan.durationMinutes, 45)) min"
        case .pulse, .tone: return "Level \(plan.intensity) · \(min(plan.durationMinutes, 45)) min"
        }
    }

    private func startLabel(for mode: ReliefMode) -> String {
        switch mode {
        case .breathe: return "Breathe"
        case .press: return "Hold"
        case .pulse, .tone: return "Pulse"
        }
    }

    private func hint(for mode: ReliefMode) -> String {
        switch mode {
        case .pulse, .tone: return "Turn your watch to the inside of your wrist."
        case .breathe: return "Long tap in, longer fade out. Eyes can stay shut."
        case .press: return "Thumb on the spot, three fingers below the crease."
        }
    }
}
