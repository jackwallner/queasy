import CoreHaptics
import Foundation
import Observation
import SwiftData
import UIKit

/// Runs a session on the iPhone. Pulse and Breathe come out of Core Haptics
/// (hold the phone against the inside of your wrist, or just rest it on you for
/// Breathe), Tone comes out of the speaker or headphones, and Press is a timer
/// for pressure you apply yourself.
@MainActor
@Observable
final class PhoneSessionController {
    static let shared = PhoneSessionController()

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
    private(set) var totalSeconds: Int = 0
    private(set) var hapticsAvailable = true
    private(set) var sessionUUID = UUID().uuidString

    var mode: ReliefMode { plan.mode }

    /// Sessions shorter than this that get cancelled are treated as accidental
    /// taps and left out of History.
    private static let minRecordedSeconds: TimeInterval = 60

    var toneEnabled = false {
        didSet {
            guard phase == .running, mode != .tone else { return }
            toneEnabled ? tone.start() : tone.stop()
        }
    }

    private var engine: CHHapticEngine?
    private var player: CHHapticAdvancedPatternPlayer?
    private var tickTimer: Timer?
    private let tone = ToneGenerator()

    /// - Parameter seconds: the length actually granted, after the free-tier
    ///   cap. Defaults to the plan's own length.
    func start(plan: ReliefPlan, seconds: Int? = nil) {
        guard phase != .running else { return }
        self.plan = plan
        intensity = plan.intensity
        startedAt = .now
        sessionUUID = UUID().uuidString
        totalSeconds = seconds ?? plan.durationMinutes * 60
        remainingSeconds = totalSeconds
        phase = .running
        UIApplication.shared.isIdleTimerDisabled = true
        startEngine()
        startPattern()
        startTicking()
        if plan.mode == .tone || toneEnabled { tone.start() }
        AnalyticsService.sessionStarted(source: .phone, intensity: intensity, cause: plan.cause)
    }

    func adjustIntensity(by delta: Int) {
        guard phase == .running, mode == .pulse else { return }
        let next = min(max(intensity + delta, PatternEngine.minIntensity), PatternEngine.maxIntensity)
        guard next != intensity else { return }
        intensity = next
        startPattern()
    }

    /// Stops the outputs and moves to the rating step. The episode is saved
    /// unrated right away so History still captures it if the rating never
    /// happens (app killed, sheet abandoned).
    func finish() {
        guard phase == .running else { return }
        stopOutputs()
        phase = .rating
        persistEpisode(severityAfter: nil)
    }

    /// Rating step completed (or skipped with nil) — updates the saved episode.
    @discardableResult
    func complete(severityAfter: Int?) -> ReliefEpisode {
        let episode = persistEpisode(severityAfter: severityAfter)
        phase = .idle
        AnalyticsService.sessionCompleted(source: .phone, minutes: episode.actualMinutes, reliefDelta: episode.reliefDelta)
        return episode
    }

    func cancel() {
        let elapsed = Date().timeIntervalSince(startedAt)
        let wasRunning = phase == .running
        stopOutputs()
        // A real session that gets cancelled still belongs in History.
        if wasRunning, elapsed >= Self.minRecordedSeconds {
            let episode = persistEpisode(severityAfter: nil)
            AnalyticsService.sessionCompleted(source: .phone, minutes: episode.actualMinutes, reliefDelta: nil)
        }
        phase = .idle
    }

    /// Upserts this session's episode (keyed by `sessionUUID`) into the shared
    /// store on the main context so HistoryView's @Query refreshes live.
    @discardableResult
    private func persistEpisode(severityAfter: Int?) -> ReliefEpisode {
        let context = DataService.sharedModelContainer.mainContext
        let uuid = sessionUUID
        let descriptor = FetchDescriptor<ReliefEpisode>(predicate: #Predicate { $0.uuid == uuid })
        if let existing = try? context.fetch(descriptor).first {
            existing.severityAfter = severityAfter
            existing.intensity = intensity
            try? context.save()
            return existing
        }
        let episode = ReliefEpisode(
            uuid: uuid,
            startedAt: startedAt,
            endedAt: .now,
            cause: plan.cause,
            mode: plan.mode,
            severityBefore: plan.severityBefore,
            severityAfter: severityAfter,
            intensity: intensity,
            plannedMinutes: max(totalSeconds / 60, 1),
            source: .phone
        )
        context.insert(episode)
        try? context.save()
        return episode
    }

    // MARK: - Haptics

    private func startEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            hapticsAvailable = false
            return
        }
        do {
            let engine = try CHHapticEngine()
            engine.resetHandler = { [weak self] in
                Task { @MainActor in
                    guard let self, self.phase == .running else { return }
                    self.startEngine()
                    self.startPattern()
                }
            }
            try engine.start()
            self.engine = engine
            hapticsAvailable = true
        } catch {
            hapticsAvailable = false
        }
    }

    /// Installs the looping haptic pattern for the current mode, if it has one.
    private func startPattern() {
        guard let engine else { return }
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil

        do {
            switch mode {
            case .pulse:
                let pattern = try Self.pattern(for: PulseSpec.forLevel(intensity))
                let player = try engine.makeAdvancedPlayer(with: pattern)
                player.loopEnabled = true
                try player.start(atTime: CHHapticTimeImmediate)
                self.player = player
            case .breathe:
                let pattern = try Self.breathingPattern(for: plan.breathe)
                let player = try engine.makeAdvancedPlayer(with: pattern)
                player.loopEnabled = true
                try player.start(atTime: CHHapticTimeImmediate)
                self.player = player
            case .press:
                // Just a marker so you know the hold has started; the pressure
                // is yours, the phone only keeps time.
                try playMarker(on: engine)
            case .tone:
                break
            }
        } catch {
            hapticsAvailable = false
        }
    }

    private func playMarker(on engine: CHHapticEngine) throws {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
            ], relativeTime: 0),
        ]
        let pattern = try CHHapticPattern(events: events, parameters: [])
        try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
    }

    /// One period of the spec as a loopable pattern: `burstCount` transients,
    /// then silence until `interval` has elapsed.
    static func pattern(for spec: PulseSpec) throws -> CHHapticPattern {
        let (intensityValue, sharpness): (Float, Float) = {
            switch spec.strength {
            case .soft: return (0.5, 0.3)
            case .medium: return (0.75, 0.45)
            case .strong: return (1.0, 0.6)
            }
        }()
        var events: [CHHapticEvent] = []
        for i in 0..<spec.burstCount {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityValue),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                ],
                relativeTime: Double(i) * PulseSpec.intraBurstGap
            ))
        }
        // A zero-intensity continuous tail pads the pattern out to the full
        // interval so loopEnabled repeats at the right cadence.
        let burstSpan = Double(max(spec.burstCount - 1, 0)) * PulseSpec.intraBurstGap + 0.1
        if spec.interval > burstSpan {
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0)],
                relativeTime: burstSpan,
                duration: spec.interval - burstSpan
            ))
        }
        return try CHHapticPattern(events: events, parameters: [])
    }

    /// One breath as a loopable pattern: a swell that rises through the
    /// in-breath, a small click at the turn, and a longer fall through the
    /// out-breath. The point is that you can follow it with your eyes closed.
    static func breathingPattern(for breath: BreathePattern) throws -> CHHapticPattern {
        let events: [CHHapticEvent] = [
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25),
                ],
                relativeTime: 0,
                duration: breath.inhaleSeconds
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.65),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                ],
                relativeTime: breath.inhaleSeconds
            ),
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.12),
                ],
                relativeTime: breath.inhaleSeconds,
                duration: breath.exhaleSeconds
            ),
        ]
        let curves: [CHHapticParameterCurve] = [
            CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0, value: 0.10),
                    .init(relativeTime: breath.inhaleSeconds, value: 0.62),
                ],
                relativeTime: 0
            ),
            CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0, value: 0.50),
                    .init(relativeTime: breath.exhaleSeconds, value: 0.04),
                ],
                relativeTime: breath.inhaleSeconds
            ),
        ]
        return try CHHapticPattern(events: events, parameterCurves: curves)
    }

    // MARK: - Clock

    private func startTicking() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                Self.shared.tick()
            }
        }
    }

    private func tick() {
        guard phase == .running else { return }
        remainingSeconds -= 1
        if remainingSeconds <= 0 {
            if mode == .press, let engine { try? playMarker(on: engine) }
            finish()
        }
    }

    private func stopOutputs() {
        UIApplication.shared.isIdleTimerDisabled = false
        tickTimer?.invalidate()
        tickTimer = nil
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        engine?.stop()
        engine = nil
        tone.stop()
    }
}
