import SwiftData
import SwiftUI

/// Full-screen control surface for a session running ON THE WATCH: live
/// countdown and intensity mirrored from the wrist, end it from here, then
/// rate it here. The vibration never leaves the watch; only the controls do.
struct WatchRemoteSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mirror = WatchSessionMirror.shared
    @State private var settings = AppSettings.shared

    private enum Step {
        case running
        case rating
    }

    @State private var step: Step = .running
    /// Frozen copy of the session facts at the moment it ends, so the rating
    /// step survives the mirror moving on.
    @State private var snapshot: Snapshot?

    private struct Snapshot {
        var uuid: String
        var cause: NauseaCause
        var mode: ReliefMode
        var severityBefore: Int
        var intensity: Int
        var startedAt: Date
        var plannedMinutes: Int
    }

    var body: some View {
        ZStack {
            Theme.tideWash.ignoresSafeArea()
            switch step {
            case .running:
                runningView
            case .rating:
                ratingView
            }
        }
        .onChange(of: mirror.phase) { _, phase in
            // The watch ended it (timer ran out, or "I'm Done" on the wrist).
            if phase == .ended, step == .running {
                moveToRating()
            }
        }
    }

    // MARK: - Running

    private var runningView: some View {
        VStack(spacing: 22) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink2)
                        .frame(width: 30, height: 30)
                        .background(Theme.paper2, in: Circle())
                }
                .accessibilityLabel("Hide session controls")
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(timeString(Int(mirror.endsAt.timeIntervalSince(context.date))))
                        .font(Theme.roundedNumeric(17))
                        .foregroundStyle(Theme.ink2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            stage
                .frame(width: 240, height: 240)

            VStack(spacing: 6) {
                Label("Playing on your Apple Watch", systemImage: "applewatch.radiowaves.left.and.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.aquaDeep)
                Text(headline)
                    .font(Theme.displaySerif(28))
                    .foregroundStyle(Theme.ink)
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            // Level is a Pulse concept. Breathe follows a rhythm and Press is
            // the wearer's own thumb, so there is nothing here to turn up.
            if mirror.mode == .pulse {
                HStack(spacing: 26) {
                    intensityButton("minus", enabled: mirror.intensity > PatternEngine.minIntensity) {
                        adjustIntensity(by: -1)
                    }
                    intensityButton("plus", enabled: mirror.intensity < PatternEngine.maxIntensity) {
                        adjustIntensity(by: 1)
                    }
                }
            }

            Spacer()

            Button("I'm Done") {
                endSession()
            }
            .buttonStyle(.tideCTA)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .accessibilityIdentifier("end-watch-session")
        }
    }

    @ViewBuilder
    private var stage: some View {
        switch mirror.mode {
        case .breathe:
            BreathingBloom(pattern: .relaxed, anchor: mirror.startedAt)
        case .press:
            ZStack {
                Circle().fill(Theme.aquaTint)
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 58, weight: .medium))
                    .foregroundStyle(Theme.aqua)
            }
        case .pulse, .tone:
            RipplePulseView(
                interval: PulseSpec.forLevel(mirror.intensity).interval,
                color: Theme.aqua
            )
        }
    }

    private var headline: String {
        switch mirror.mode {
        case .breathe: return "Follow the breath"
        case .press: return "Keep the pressure on"
        case .pulse, .tone: return "Level \(mirror.intensity)"
        }
    }

    private var hint: String {
        switch mirror.mode {
        case .breathe: return "Long tap in, longer fade out. Eyes can stay shut."
        case .press: return "Thumb or band on the spot, three finger-widths below the crease."
        case .pulse, .tone: return "Turn the watch to the inside of your wrist."
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

    private func adjustIntensity(by delta: Int) {
        let next = min(
            max(mirror.intensity + delta, PatternEngine.minIntensity),
            PatternEngine.maxIntensity
        )
        guard next != mirror.intensity else { return }
        QueasySyncService.shared.sendIntensityDelta(delta, uuid: mirror.sessionUUID)
        // Optimistic; the watch echoes the real value right back.
        mirror.noteIntensity(next)
    }

    private func endSession() {
        QueasySyncService.shared.sendStopSession(uuid: mirror.sessionUUID)
        moveToRating()
    }

    private func moveToRating() {
        snapshot = Snapshot(
            uuid: mirror.sessionUUID,
            cause: mirror.cause,
            mode: mirror.mode,
            severityBefore: mirror.severityBefore,
            intensity: mirror.intensity,
            startedAt: mirror.startedAt,
            plannedMinutes: mirror.plannedMinutes
        )
        mirror.noteEnded()
        withAnimation { step = .rating }
    }

    // MARK: - Rating

    /// Same three-choice rating as the watch and phone session, so every
    /// surface asks the question the same way.
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

            Spacer()
        }
    }

    private func feelingButton(_ label: String, symbol: String, tint: Color, feeling: ReliefFeeling) -> some View {
        Button {
            saveEpisode(severityAfter: feeling.severityAfter(before: snapshot?.severityBefore ?? 3))
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
            .frame(height: 56)
            .background(Theme.paper2, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(tint.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("watch-after-feeling-\(feeling.rawValue)")
    }

    /// Upserts the episode by UUID. The watch sends its own (unrated) copy of
    /// the episode when it stops; whichever arrives first wins the insert and
    /// the other becomes an update, so no duplicates either way.
    private func saveEpisode(severityAfter: Int?) {
        defer {
            mirror.clear()
            dismiss()
        }
        guard let snapshot else { return }
        let context = DataService.sharedModelContainer.mainContext
        let uuid = snapshot.uuid
        let descriptor = FetchDescriptor<ReliefEpisode>(predicate: #Predicate { $0.uuid == uuid })
        let episode: ReliefEpisode
        if let existing = try? context.fetch(descriptor).first {
            if let severityAfter {
                existing.severityAfter = severityAfter
            }
            episode = existing
        } else {
            episode = ReliefEpisode(
                uuid: uuid,
                startedAt: snapshot.startedAt,
                endedAt: .now,
                cause: snapshot.cause,
                mode: snapshot.mode,
                severityBefore: snapshot.severityBefore,
                severityAfter: severityAfter,
                intensity: snapshot.intensity,
                plannedMinutes: snapshot.plannedMinutes,
                source: .watch
            )
            context.insert(episode)
        }
        try? context.save()

        // The phone owns this rating now: tell the watch to drop its own rating
        // screen so it doesn't sit stuck on the wrist (and can't re-rate the
        // same episode from the other side).
        QueasySyncService.shared.sendCompleteRating(uuid: uuid)

        guard severityAfter != nil else { return }
        settings.completedSessionCount += 1
        if ReviewPromptTracker.shouldPrompt(
            afterReliefDelta: episode.reliefDelta,
            sessionCount: settings.completedSessionCount
        ) {
            ReviewPromptTracker.recordPrompt()
            // Hand off to the enjoyment funnel; RootTabView shows it once this
            // full-screen session cover has dismissed.
            ReviewPromptCoordinator.shared.request(.enjoyment)
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let clamped = max(seconds, 0)
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }
}
