import SwiftUI

/// One mode, explained and started. Reached by tapping a mode on the home
/// screen, so it carries the detail the home cards leave out: what the thing
/// actually is, how long it runs, and what it leans on.
struct ModeStartView: View {
    let mode: ReliefMode
    /// Where to start from, so the caller can record it as the last plan.
    var onStart: (ReliefPlan) -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(SubscriptionService.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var watch = WatchAvailability.shared
    @State private var watchFeedback: String?
    @State private var showPaywall = false

    private var plan: ReliefPlan {
        // resolvedPlan applies the Settings overrides for length and breathing
        // rhythm, so starting from a mode card honours them the same way the
        // check-in does.
        var base = settings.resolvedPlan(from: settings.lastPlan ?? .quickStart)
        base.mode = mode
        if base.durationMinutes < PatternEngine.minDuration {
            base.durationMinutes = PatternEngine.minDuration
        }
        // Tone and Press are fixed protocols, not a length anyone chose.
        if mode == .press { base.durationMinutes = PressProtocol.holdSeconds / 60 }
        if mode == .tone { base.durationMinutes = 1 }
        return base
    }

    private var effectiveSeconds: Int {
        switch mode {
        case .tone: return 60
        case .press: return PressProtocol.holdSeconds
        case .pulse, .breathe:
            return FreeTier.cappedSeconds(
                for: mode,
                requested: plan.durationMinutes * 60,
                isPro: subscriptions.isProSubscriber
            )
        }
    }

    private var isCapped: Bool {
        FreeTier.isCapped(mode, requested: plan.durationMinutes * 60, isPro: subscriptions.isProSubscriber)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    if mode == .press { pressSteps }
                    startButtons
                    if isCapped { unlockNote }
                    if let note = mode.evidenceNote { evidenceCard(note) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .tideBackground()
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.ink2)
                }
            }
        }
        .onAppear { watch.refresh() }
        .sheet(isPresented: $showPaywall) {
            PaywallView(displayCloseButton: true, paywallImpressionId: "queasy_mode_length")
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            if mode == .breathe {
                BreathingBloom(pattern: plan.breathe)
                    .frame(height: 140)
            } else {
                ZStack {
                    Circle().fill(Theme.aquaTint).frame(width: 132, height: 132)
                    Image(systemName: mode.symbolName)
                        .font(.system(size: 52, weight: .medium))
                        .foregroundStyle(Theme.aqua)
                }
            }
            Text(mode.blurb)
                .font(.callout)
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
            Text(lengthLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.cardPadding)
        .tideCard()
    }

    private var lengthLabel: String {
        switch mode {
        case .tone: return "One minute, then it stops on its own"
        case .press: return "\(PressProtocol.holdSeconds / 60) minutes, timed for you"
        case .pulse, .breathe: return "\(effectiveSeconds / 60) minutes"
        }
    }

    private var pressSteps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Finding the spot")
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.ink3)
                .textCase(.uppercase)
            ForEach(Array(PressProtocol.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(Theme.roundedNumeric(13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Theme.aqua, in: Circle())
                    Text(step)
                        .font(.footnote)
                        .foregroundStyle(Theme.ink2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .tideCard()
    }

    @ViewBuilder
    private var startButtons: some View {
        VStack(spacing: 10) {
            if mode.runsOnWatch, watch.isPaired {
                Button {
                    startOnWatch()
                } label: {
                    Label(watchFeedback ?? "Start on Apple Watch",
                          systemImage: watchFeedback == nil ? "applewatch" : "checkmark")
                }
                .buttonStyle(.tideCTA)
                .accessibilityIdentifier("mode-start-watch")

                Button {
                    startOnPhone()
                } label: {
                    Label("Use iPhone instead", systemImage: "iphone.radiowaves.left.and.right")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.aqua)
                }
                .accessibilityIdentifier("mode-start-phone")
            } else {
                Button {
                    startOnPhone()
                } label: {
                    Label(startLabel, systemImage: mode.symbolName)
                }
                .buttonStyle(.tideCTA)
                .accessibilityIdentifier("mode-start-phone")
            }

            if mode.needsHeadphones {
                Text("Headphones in, volume low. It is meant to be quiet.")
                    .font(.caption2)
                    .foregroundStyle(Theme.ink3)
            }
        }
    }

    private var startLabel: String {
        switch mode {
        case .pulse: return "Start the Pulse"
        case .breathe: return "Start Breathing"
        case .tone: return "Play the Tone"
        case .press: return "Start the Hold"
        }
    }

    private func startOnPhone() {
        let plan = self.plan
        onStart(plan)
        PhoneSessionController.shared.start(plan: plan, seconds: effectiveSeconds)
        dismiss()
    }

    private func startOnWatch() {
        var plan = self.plan
        plan.durationMinutes = max(effectiveSeconds / 60, 1)
        onStart(plan)
        Task {
            let outcome = await WatchLauncher.shared.startOnWatch(plan: plan)
            watchFeedback = outcome == .started
                ? "Starting on your watch…"
                : "Sent. Open Queasy on your watch."
            try? await Task.sleep(for: .seconds(1.8))
            dismiss()
        }
    }

    private var unlockNote: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "timer")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.aqua)
                Text("Free sessions run \(FreeTier.sessionSeconds / 60) minutes. Pro goes up to \(PatternEngine.maxDuration).")
                    .font(.caption)
                    .foregroundStyle(Theme.ink2)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.ink3)
            }
            .padding(14)
            .tideCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mode-unlock-length")
    }

    private func evidenceCard(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What this leans on")
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.ink3)
                .textCase(.uppercase)
            Text(note)
                .font(.caption)
                .foregroundStyle(Theme.ink2)
            if let url = mode.sourceURL {
                Button {
                    openURL(url)
                } label: {
                    Label("Read the source", systemImage: "arrow.up.right.square")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.aqua)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .tideCard()
    }
}
