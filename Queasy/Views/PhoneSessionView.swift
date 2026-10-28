import SwiftData
import SwiftUI

/// Full-screen phone session. What fills the middle depends on the mode: a
/// ripple for Pulse, a breathing bloom for Breathe, a waveform for Tone, a hold
/// timer for Press. Then the "how do you feel now?" step, which is the same
/// three choices the watch shows.
struct PhoneSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.closePane) private var closePane
    @Environment(SubscriptionService.self) private var subscriptions
    @State private var controller = PhoneSessionController.shared
    @State private var settings = AppSettings.shared

    #if DEBUG
    /// Marketing capture on the simulator: the sim has no Core Haptics, so
    /// suppress the "haptics unavailable" warning in raw screenshots.
    private var isScreenshotRun: Bool {
        ProcessInfo.processInfo.arguments.contains("-QueasyScreenshots")
    }
    #else
    private var isScreenshotRun: Bool { false }
    #endif

    private var mode: ReliefMode { controller.mode }

    var body: some View {
        // Unfolded, the session takes the pane before the fold and History
        // the pane after it: the routine beside how earlier ones went.
        UnfoldedSplitView { _ in
            switch controller.phase {
            case .running:
                runningView
            case .rating:
                ratingView.scrollsWhenTall()
            case .idle:
                Color.clear.onAppear { close() }
            }
        } secondary: {
            HistoryView()
        }
        .tideBackground()
    }

    // MARK: - Running

    /// Presented: dismiss. Shown in an unfolded pane: let the pane close it.
    private func close() {
        if let closePane { closePane() } else { dismiss() }
    }

    /// The full stage when it fits. Both Duo displays are short (669 to
    /// 678 pt), so the stage shrinks before anything scrolls.
    private var runningView: some View {
        ViewThatFits(in: .vertical) {
            runningLayout(stageSide: 240)
            runningLayout(stageSide: 170)
            ScrollView { runningLayout(stageSide: 170) }
                .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func runningLayout(stageSide: CGFloat) -> some View {
        VStack(spacing: 22) {
            HStack {
                Button {
                    controller.cancel()
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink2)
                        .frame(width: 30, height: 30)
                        .background(Theme.paper2, in: Circle())
                }
                .accessibilityLabel("Cancel session")
                Spacer()
                Text(timeString(controller.remainingSeconds))
                    .font(Theme.roundedNumeric(17))
                    .foregroundStyle(Theme.ink2)
                    .monospacedDigit()
                    .accessibilityIdentifier("session-timer")
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            stage(side: stageSide)

            VStack(spacing: 4) {
                Text(headline)
                    .font(Theme.displaySerif(28))
                    .foregroundStyle(Theme.ink)
                Text(guidance)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
                if needsHaptics, !controller.hapticsAvailable, !isScreenshotRun {
                    Text("This device has no haptic engine, so it cannot play a pattern you can feel. Tone still works here, and wrist sessions need an Apple Watch.")
                        .font(.caption)
                        .foregroundStyle(Theme.coral)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
            }

            if mode == .pulse {
                HStack(spacing: 26) {
                    intensityButton("minus", enabled: controller.intensity > PatternEngine.minIntensity) {
                        controller.adjustIntensity(by: -1)
                    }
                    intensityButton("plus", enabled: controller.intensity < PatternEngine.maxIntensity) {
                        controller.adjustIntensity(by: 1)
                    }
                }
            }

            if mode == .pulse || mode == .breathe {
                Toggle(isOn: Binding(
                    get: { controller.toneEnabled },
                    set: { controller.toneEnabled = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add the 100 Hz tone")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Headphones recommended")
                            .font(.caption)
                            .foregroundStyle(Theme.ink2)
                    }
                }
                .tint(Theme.aqua)
                .padding(16)
                .tideCard(cornerRadius: 16)
                .padding(.horizontal, 20)
            }

            Spacer()

            Button("I'm Done") {
                controller.finish()
            }
            .buttonStyle(.tideCTA)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .accessibilityIdentifier("end-session")
        }
    }

    private var needsHaptics: Bool { mode == .pulse || mode == .breathe }

    @ViewBuilder
    private func stage(side: CGFloat) -> some View {
        switch mode {
        case .pulse:
            RipplePulseView(
                interval: PulseSpec.forLevel(controller.intensity).interval,
                color: Theme.aqua
            )
            .frame(width: side, height: side)
        case .breathe:
            BreathingBloom(pattern: controller.plan.breathe, anchor: controller.startedAt)
                .frame(width: side, height: side)
        case .tone:
            ZStack {
                Circle()
                    .fill(Theme.aquaTint)
                    .frame(width: side * 0.83, height: side * 0.83)
                Image(systemName: "waveform")
                    .font(.system(size: 74, weight: .medium))
                    .foregroundStyle(Theme.aqua)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            }
            .frame(width: side, height: side)
        case .press:
            ZStack {
                Circle()
                    .stroke(Theme.paper3, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(Theme.aqua, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 58, weight: .medium))
                    .foregroundStyle(Theme.aqua)
            }
            .frame(width: side, height: side)
        }
    }

    private var holdProgress: CGFloat {
        guard controller.totalSeconds > 0 else { return 0 }
        let done = controller.totalSeconds - controller.remainingSeconds
        return CGFloat(done) / CGFloat(controller.totalSeconds)
    }

    private var headline: String {
        switch mode {
        case .pulse: return "Level \(controller.intensity)"
        case .breathe: return "Follow the breath"
        case .tone: return "100 Hz"
        case .press: return "Keep the pressure on"
        }
    }

    private var guidance: String {
        switch mode {
        case .pulse:
            return "Hold your iPhone against the inside of your wrist, or rest it where you can feel the taps."
        case .breathe:
            return "Long swell in, longer fade out. Rest the phone on you and shut your eyes if you like."
        case .tone:
            return "Keep the volume low. It should sit under the noise around you, not over it."
        case .press:
            return "Thumb or band on the spot, steady pressure, three finger-widths below the wrist crease."
        }
    }

    private func intensityButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(enabled ? Theme.aqua : Theme.ink3)
                .frame(width: 58, height: 58)
                .background(Theme.paper2, in: Circle())
                .overlay(Circle().stroke(Theme.ink.opacity(0.06), lineWidth: 1))
        }
        .disabled(!enabled)
        .accessibilityLabel(symbol == "plus" ? "Increase intensity" : "Decrease intensity")
    }

    // MARK: - Rating

    /// The same three-choice rating the watch shows, so the two surfaces read
    /// identically. Feeling → after-severity lives in `ReliefFeeling`.
    private var ratingView: some View {
        VStack(spacing: 22) {
            Spacer()
            Text("How do you feel now?")
                .font(Theme.displaySerif(28))
                .foregroundStyle(Theme.ink)
            Text("Compared to when you started.")
                .font(.subheadline)
                .foregroundStyle(Theme.ink2)

            VStack(spacing: 12) {
                feelingButton("Better", symbol: "face.smiling", tint: Theme.aqua, feeling: .better)
                feelingButton("The same", symbol: "face.dashed", tint: Theme.sand, feeling: .same)
                feelingButton("Worse", symbol: "cloud.rain", tint: Theme.coral, feeling: .worse)
            }
            .padding(.horizontal, 24)

            Button("Skip") {
                saveEpisode(severityAfter: nil)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.ink3)
            // The choices sit above where "I'm Done" was, so a second tap on
            // the way out cannot rate the session.
            Spacer()
            Spacer()
        }
    }

    private func feelingButton(_ label: String, symbol: String, tint: Color, feeling: ReliefFeeling) -> some View {
        Button {
            saveEpisode(severityAfter: feeling.severityAfter(before: controller.plan.severityBefore))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 30)
                Text(label)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(minHeight: 56)
            .background(Theme.paper2, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(tint.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("after-feeling-\(feeling.rawValue)")
    }

    private func saveEpisode(severityAfter: Int?) {
        // The session hit the free ceiling if it ran the whole way and the whole
        // way was shorter than the plan asked for.
        let wasCapped = FreeTier.isCapped(
            mode,
            requested: controller.plan.durationMinutes * 60,
            isPro: subscriptions.isProSubscriber
        )
        // complete() upserts the episode into the shared store itself.
        let episode = controller.complete(severityAfter: severityAfter)
        settings.completedSessionCount += 1

        if UpgradePromptTracker.shouldPrompt(
            isPro: subscriptions.isProSubscriber,
            sessionWasCapped: wasCapped,
            sessionCount: settings.completedSessionCount
        ) {
            UpgradePromptTracker.recordPrompt()
            UpgradePromptCoordinator.shared.request("queasy_after_session")
        } else if (episode.reliefDelta ?? 0) >= 0 {
            // A finished session the user didn't rate as worse. RootTabView
            // asks for a rating once this cover is gone.
            ReviewPromptCoordinator.shared.recordPositiveMoment()
        }
        close()
    }

    private func timeString(_ seconds: Int) -> String {
        let clamped = max(seconds, 0)
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }
}
