#if os(watchOS)
import Foundation
import Observation
import WatchKit

/// Plays the relief pattern on the wrist.
/// `WKExtendedRuntimeSession` (physical-therapy mode) keeps pulses running
/// after the screen turns off without recording workouts.
@MainActor
@Observable
final class WatchHapticEngine: NSObject {
    static let shared = WatchHapticEngine()

    enum Phase: Equatable {
        case idle
        case running
        case rating
    }

    private(set) var phase: Phase = .idle
    private(set) var plan: ReliefPlan = .quickStart
    private(set) var intensity: Int = 5
    private(set) var startedAt: Date = .now
    private(set) var remainingSeconds: Int = 0
    private(set) var sessionUUID = UUID().uuidString
    /// When the pulses actually stopped; the rating can come much later.
    private var endedAt: Date = .now

    private var runtimeSession: WKExtendedRuntimeSession?
    private var pulseTimer: Timer?
    private var tickTimer: Timer?
    private var burstTask: Task<Void, Never>?
    /// Breathe and Press are shaped over time rather than on a fixed interval,
    /// so they run as a cancellable loop instead of a timer.
    private var rhythmTask: Task<Void, Never>?

    /// Which of the four modes is on the wrist. Tone has no wrist form, so a
    /// plan that somehow arrives asking for it falls back to Pulse.
    var mode: ReliefMode { plan.mode == .tone ? .pulse : plan.mode }

    func start(plan: ReliefPlan) {
        guard phase != .running else { return }
        self.plan = plan
        intensity = plan.intensity
        startedAt = .now
        sessionUUID = UUID().uuidString
        remainingSeconds = min(plan.durationMinutes, 45) * 60
        phase = .running

        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        runtimeSession = session

        scheduleOutputs()
        startTicking()
        broadcastState()
        AnalyticsService.sessionStarted(source: .watch, intensity: intensity, cause: plan.cause)
    }

    /// Retune a running session to a newly arrived plan without restarting it.
    func adopt(plan: ReliefPlan) {
        guard phase == .running else { return }
        self.plan = plan
        intensity = plan.intensity
        remainingSeconds = min(plan.durationMinutes, 45) * 60
        scheduleOutputs()
        broadcastState()
    }

    func adjustIntensity(by delta: Int) {
        guard phase == .running, mode == .pulse else { return }
        let next = min(max(intensity + delta, PatternEngine.minIntensity), PatternEngine.maxIntensity)
        guard next != intensity else { return }
        intensity = next
        scheduleOutputs()
        broadcastState()
    }

    func finish() {
        guard phase == .running else { return }
        stopOutputs()
        endedAt = .now
        phase = .rating
        broadcastState()
        // Send the episode unrated right away so History captures the session
        // even if the rating screen is never touched (wrist down, app killed,
        // 45-min auto-finish). A later rating re-sends the same UUID and the
        // phone upserts it.
        sendEpisode(severityAfter: nil)
    }

    func complete(feeling: ReliefFeeling?) {
        let before = plan.severityBefore
        let after: Int? = feeling?.severityAfter(before: before)
        if after != nil {
            sendEpisode(severityAfter: after)
        }
        AnalyticsService.sessionCompleted(
            source: .watch,
            minutes: max(0, Int(endedAt.timeIntervalSince(startedAt) / 60)),
            reliefDelta: after.map { before - $0 }
        )
        phase = .idle
    }

    /// The phone already captured this session's rating; drop our own rating
    /// screen without re-sending the episode (that would fight the phone's
    /// upsert and could double-count).
    func dismissRating() {
        guard phase == .rating else { return }
        phase = .idle
    }

    func cancel() {
        let elapsed = Date().timeIntervalSince(startedAt)
        let wasRunning = phase == .running
        stopOutputs()
        // A real session that gets cancelled still belongs in History.
        if wasRunning, elapsed >= 60 {
            endedAt = .now
            sendEpisode(severityAfter: nil)
        }
        phase = .idle
        broadcastState()
    }

    /// Mirrors the session over to the phone so it can show live state and
    /// remote-control the wrist.
    private func broadcastState() {
        QueasySyncService.shared.sendWatchState([
            "phase": phase == .running ? "running" : "ended",
            "sessionUUID": sessionUUID,
            "startedAt": startedAt.timeIntervalSince1970,
            "endsAt": Date().addingTimeInterval(Double(max(remainingSeconds, 0))).timeIntervalSince1970,
            "intensity": intensity,
            "cause": plan.cause.rawValue,
            "mode": mode.rawValue,
            "severityBefore": plan.severityBefore,
            "plannedMinutes": plan.durationMinutes,
        ])
    }

    private func sendEpisode(severityAfter: Int?) {
        QueasySyncService.shared.sendEpisode(
            uuid: sessionUUID,
            startedAt: startedAt,
            endedAt: endedAt,
            cause: plan.cause,
            mode: mode,
            severityBefore: plan.severityBefore,
            severityAfter: severityAfter,
            intensity: intensity,
            plannedMinutes: plan.durationMinutes
        )
    }

    // MARK: - Output

    private func scheduleOutputs() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        rhythmTask?.cancel()
        rhythmTask = nil

        switch mode {
        case .pulse, .tone:
            schedulePulses()
        case .breathe:
            scheduleBreathing()
        case .press:
            schedulePressHold()
        }
    }

    private func schedulePulses() {
        let spec = cappedSpec
        playBurst(spec)
        pulseTimer = Timer.scheduledTimer(withTimeInterval: spec.interval, repeats: true) { _ in
            Task { @MainActor in
                let engine = WatchHapticEngine.shared
                guard engine.phase == .running, engine.mode == .pulse else { return }
                engine.playBurst(engine.cappedSpec)
            }
        }
    }

    /// The wrist version of the breathing pacer. `WKInterfaceDevice` only plays
    /// discrete types, so the shape has to come from what is tapped and when:
    /// a rise to open the in-breath, ticks to pace it, a fall to turn it round,
    /// then a sparser tick through the longer out-breath. You can follow it
    /// with your arm down and your eyes shut, which is the entire point.
    private func scheduleBreathing() {
        let breath = plan.breathe
        rhythmTask = Task { @MainActor in
            while !Task.isCancelled, self.phase == .running {
                WKInterfaceDevice.current().play(.directionUp)
                var elapsed = 0.0
                while elapsed + 1.0 < breath.inhaleSeconds {
                    try? await Task.sleep(for: .seconds(1))
                    if Task.isCancelled || self.phase != .running { return }
                    WKInterfaceDevice.current().play(.click)
                    elapsed += 1
                }
                try? await Task.sleep(for: .seconds(breath.inhaleSeconds - elapsed))
                if Task.isCancelled || self.phase != .running { return }

                WKInterfaceDevice.current().play(.directionDown)
                var out = 0.0
                while out + 1.5 < breath.exhaleSeconds {
                    try? await Task.sleep(for: .seconds(1.5))
                    if Task.isCancelled || self.phase != .running { return }
                    WKInterfaceDevice.current().play(.click)
                    out += 1.5
                }
                try? await Task.sleep(for: .seconds(breath.exhaleSeconds - out))
            }
        }
    }

    /// Press is the user's own thumb; the watch only marks the start, keeps the
    /// time, and reassures once a minute that it is still counting.
    private func schedulePressHold() {
        rhythmTask = Task { @MainActor in
            WKInterfaceDevice.current().play(.start)
            while !Task.isCancelled, self.phase == .running {
                try? await Task.sleep(for: .seconds(60))
                if Task.isCancelled || self.phase != .running { return }
                if self.remainingSeconds > 5 {
                    WKInterfaceDevice.current().play(.click)
                }
            }
        }
    }

    /// The level's spec with the user's strength cap applied.
    var cappedSpec: PulseSpec {
        var spec = PulseSpec.forLevel(intensity)
        let cap = AppSettings.shared.watchStrengthCap
        switch (spec.strength, cap) {
        case (.strong, .medium), (.strong, .soft):
            spec.strength = cap
        case (.medium, .soft):
            spec.strength = .soft
        default:
            break
        }
        return spec
    }

    private func playBurst(_ spec: PulseSpec) {
        burstTask?.cancel()
        let haptic = Self.hapticType(for: spec.strength)
        burstTask = Task { @MainActor in
            for i in 0..<spec.burstCount {
                if i > 0 {
                    try? await Task.sleep(for: .seconds(PulseSpec.intraBurstGap))
                    if Task.isCancelled { return }
                }
                WKInterfaceDevice.current().play(haptic)
            }
        }
    }

    static func hapticType(for strength: PulseStrength) -> WKHapticType {
        switch strength {
        case .soft: return .click
        case .medium: return .directionUp
        case .strong: return .notification
        }
    }

    // MARK: - Clock

    private func startTicking() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                WatchHapticEngine.shared.tick()
            }
        }
    }

    private func tick() {
        guard phase == .running else { return }
        remainingSeconds -= 1
        if remainingSeconds <= 0 {
            if mode == .press { WKInterfaceDevice.current().play(.stop) }
            finish()
        }
    }

    private func stopOutputs() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        tickTimer?.invalidate()
        tickTimer = nil
        burstTask?.cancel()
        burstTask = nil
        rhythmTask?.cancel()
        rhythmTask = nil
        runtimeSession?.invalidate()
        runtimeSession = nil
    }
}

extension WatchHapticEngine: WKExtendedRuntimeSessionDelegate {
    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in
            WatchHapticEngine.shared.finish()
        }
    }

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        Task { @MainActor in
            let engine = WatchHapticEngine.shared
            if engine.phase == .running {
                engine.finish()
            }
        }
    }
}
#endif
