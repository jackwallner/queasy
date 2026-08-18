#if canImport(WatchConnectivity)
import Foundation
import Observation
import SwiftData
import WatchConnectivity

#if os(iOS)
/// Live watch pairing/install state for the UI. WCSession's flags only become
/// meaningful after activation and can flip while the app is open (watch app
/// finishes installing), so views observe this instead of polling the session.
@MainActor
@Observable
final class WatchAvailability {
    static let shared = WatchAvailability()

    private(set) var isPaired = false
    private(set) var isAppInstalled = false

    /// Paired but the watch app hasn't finished installing (or was removed).
    var isPairedWithoutApp: Bool { isPaired && !isAppInstalled }

    fileprivate func apply(paired: Bool, installed: Bool) {
        isPaired = paired
        isAppInstalled = installed
    }

    /// Re-reads the session flags (e.g. on scene activation).
    func refresh() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        apply(paired: session.isPaired, installed: session.isWatchAppInstalled)
    }
}

/// Phone-side mirror of the session running on the watch, fed by the state
/// broadcasts in `QueasySyncService`. Lets the phone show, retune, and end a
/// wrist session without touching the watch.
@MainActor
@Observable
final class WatchSessionMirror {
    static let shared = WatchSessionMirror()

    enum Phase: Equatable {
        case idle
        case running
        case ended
    }

    private(set) var phase: Phase = .idle
    private(set) var sessionUUID = ""
    private(set) var intensity = 5
    private(set) var startedAt = Date.distantPast
    private(set) var endsAt = Date.distantPast
    private(set) var cause: NauseaCause = .general
    private(set) var mode: ReliefMode = .pulse
    private(set) var severityBefore = 3
    private(set) var plannedMinutes = 15

    /// `endsAt` guard: a stale "running" context replayed after the session's
    /// window can't resurrect a dead session card.
    var isRunning: Bool { phase == .running && endsAt > Date() }

    /// Set by `WatchLauncher` when the phone asks the watch to start, so the
    /// home screen can pop the remote controls once the watch confirms.
    var pendingAutoPresent = false

    /// Sendable snapshot decoded off the WCSession thread, so nothing but
    /// value types crosses onto the main actor.
    struct Snapshot: Sendable {
        var uuid: String
        var isRunning: Bool
        var intensity: Int
        var startedAt: Date
        var endsAt: Date
        var cause: NauseaCause
        var mode: ReliefMode
        var severityBefore: Int
        var plannedMinutes: Int

        init?(_ state: [String: Any]) {
            guard let uuid = state["sessionUUID"] as? String,
                  let phaseRaw = state["phase"] as? String else { return nil }
            self.uuid = uuid
            self.intensity = state["intensity"] as? Int ?? 5
            self.startedAt = (state["startedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? .distantPast
            self.endsAt = (state["endsAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? .distantPast
            self.cause = (state["cause"] as? String).flatMap(NauseaCause.init(rawValue:)) ?? .general
            self.mode = (state["mode"] as? String).flatMap(ReliefMode.init(rawValue:)) ?? .pulse
            self.severityBefore = state["severityBefore"] as? Int ?? 3
            self.plannedMinutes = state["plannedMinutes"] as? Int ?? 15
            self.isRunning = phaseRaw == "running"
        }
    }

    fileprivate func apply(_ snapshot: Snapshot) {
        sessionUUID = snapshot.uuid
        intensity = snapshot.intensity
        startedAt = snapshot.startedAt
        endsAt = snapshot.endsAt
        cause = snapshot.cause
        mode = snapshot.mode
        severityBefore = snapshot.severityBefore
        plannedMinutes = snapshot.plannedMinutes
        phase = (snapshot.isRunning && snapshot.endsAt > Date()) ? .running : .ended
    }

    /// Phone-side optimistic updates while a command is in flight.
    func noteIntensity(_ value: Int) { intensity = value }
    func noteEnded() { phase = .ended }
    func clear() { phase = .idle }

    #if DEBUG
    /// Marketing capture: stage a believable running wrist session so the
    /// remote-control screen can be screenshotted without a paired watch.
    func seedScreenshotSession() {
        sessionUUID = "screenshot"
        intensity = 6
        startedAt = Date().addingTimeInterval(-6 * 60)
        endsAt = Date().addingTimeInterval(9 * 60)
        cause = .motion
        mode = .pulse
        severityBefore = 4
        plannedMinutes = 15
        phase = .running
    }
    #endif
}
#endif

/// Phone ⇄ watch bridge.
///
/// Phone → watch: the recommended `ReliefPlan`. Sent as a live message when the
/// watch is reachable AND written to the application context (last value wins,
/// survives the watch being asleep).
///
/// Watch → phone: completed episodes. Sent via `transferUserInfo` so they queue
/// until the phone is around; the phone upserts them into SwiftData keyed by
/// the episode UUID, so replays can't duplicate.
final class QueasySyncService: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = QueasySyncService()

    /// Watch side sets this to react to an incoming plan (already on main).
    /// The Bool is `autoStart`: the phone asked for the session to begin the
    /// moment the watch app is frontmost, no extra tap.
    @MainActor var onPlanReceived: ((ReliefPlan, Bool) -> Void)?

    /// Auto-start requests older than this are treated as a plain plan handoff
    /// so a stale context replay can't buzz someone hours later.
    private static let autoStartFreshness: TimeInterval = 10 * 60

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Phone → watch

    #if os(iOS)
    /// Whether there's a paired watch with Queasy installed to hand off to.
    var isWatchAppAvailable: Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        return session.activationState == .activated && session.isPaired && session.isWatchAppInstalled
    }

    /// True only while the watch app is active enough to receive live messages.
    var isWatchReachable: Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        return session.activationState == .activated && session.isReachable
    }
    #endif

    func sendPlan(_ plan: ReliefPlan, autoStart: Bool = false) {
        guard WCSession.isSupported() else { return }
        guard let data = try? JSONEncoder().encode(plan) else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        // issuedAt busts the "context unchanged, delivery skipped" optimization
        // when the same plan is sent twice.
        let payload: [String: Any] = [
            "plan": data,
            "issuedAt": Date().timeIntervalSince1970,
            "autoStart": autoStart,
        ]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
        try? session.updateApplicationContext(payload)
    }

    // MARK: - Phone → watch commands

    #if os(iOS)
    /// Ends the session currently running on the watch. The UUID rides along
    /// so a queued delivery can't kill a different, later session.
    func sendStopSession(uuid: String) {
        sendCommand(["command": "stop", "sessionUUID": uuid])
    }

    func sendIntensityDelta(_ delta: Int, uuid: String) {
        sendCommand(["command": "intensity", "delta": delta, "sessionUUID": uuid])
    }

    /// The session was already rated (or skipped) on the phone, so tell the
    /// watch to drop its own rating screen instead of leaving it stuck on the
    /// wrist. The phone owns the rating; the watch must not re-send the episode.
    func sendCompleteRating(uuid: String) {
        sendCommand(["command": "completeRating", "sessionUUID": uuid])
    }

    private func sendCommand(_ payload: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            // Queued fallback; harmless if stale thanks to the UUID guard.
            session.transferUserInfo(payload)
        }
    }
    #endif

    // MARK: - Watch → phone

    #if os(watchOS)
    /// Broadcasts the watch session state so the phone can mirror it live.
    /// Message for immediacy, application context so a phone app opened
    /// mid-session still learns about it.
    func sendWatchState(_ state: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let payload: [String: Any] = ["watchState": state]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
        try? session.updateApplicationContext(payload)
    }
    #endif

    func sendEpisode(
        uuid: String,
        startedAt: Date,
        endedAt: Date,
        cause: NauseaCause,
        mode: ReliefMode,
        severityBefore: Int,
        severityAfter: Int?,
        intensity: Int,
        plannedMinutes: Int
    ) {
        guard WCSession.isSupported() else { return }
        var payload: [String: Any] = [
            "episodeUUID": uuid,
            "startedAt": startedAt.timeIntervalSince1970,
            "endedAt": endedAt.timeIntervalSince1970,
            "cause": cause.rawValue,
            "mode": mode.rawValue,
            "severityBefore": severityBefore,
            "intensity": intensity,
            "plannedMinutes": plannedMinutes,
        ]
        if let after = severityAfter {
            payload["severityAfter"] = after
        }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        session.transferUserInfo(payload)
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        #if os(iOS)
        let paired = session.isPaired
        let installed = session.isWatchAppInstalled
        Task { @MainActor in
            WatchAvailability.shared.apply(paired: paired, installed: installed)
        }
        #endif
        // Replay whatever the counterpart last pushed while we were asleep.
        deliverPlan(from: session.receivedApplicationContext)
        deliverWatchState(from: session.receivedApplicationContext)
    }

    #if os(iOS)
    /// Fires when the watch pairs/unpairs or the watch app install completes.
    func sessionWatchStateDidChange(_ session: WCSession) {
        let paired = session.isPaired
        let installed = session.isWatchAppInstalled
        Task { @MainActor in
            WatchAvailability.shared.apply(paired: paired, installed: installed)
        }
    }
    #endif

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        deliverPlan(from: applicationContext)
        deliverWatchState(from: applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        deliverPlan(from: message)
        deliverWatchState(from: message)
        handleCommand(from: message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        persistEpisode(from: userInfo)
        handleCommand(from: userInfo)
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate so a swapped watch keeps syncing.
        session.activate()
    }
    #endif

    // MARK: - Payload handling

    private func deliverPlan(from payload: [String: Any]) {
        #if os(watchOS)
        guard let data = payload["plan"] as? Data,
              let plan = try? JSONDecoder().decode(ReliefPlan.self, from: data) else { return }
        let issuedAt = payload["issuedAt"] as? TimeInterval ?? 0
        let isFresh = Date().timeIntervalSince1970 - issuedAt < Self.autoStartFreshness
        let autoStart = (payload["autoStart"] as? Bool ?? false) && isFresh
        Task { @MainActor in
            QueasySyncService.shared.onPlanReceived?(plan, autoStart)
        }
        #endif
    }

    /// Watch → phone session-state broadcast lands in the phone-side mirror.
    private func deliverWatchState(from payload: [String: Any]) {
        #if os(iOS)
        guard let state = payload["watchState"] as? [String: Any],
              let snapshot = WatchSessionMirror.Snapshot(state) else { return }
        Task { @MainActor in
            WatchSessionMirror.shared.apply(snapshot)
        }
        #endif
    }

    /// Phone → watch remote control for the running session.
    private func handleCommand(from payload: [String: Any]) {
        #if os(watchOS)
        guard let command = payload["command"] as? String,
              let uuid = payload["sessionUUID"] as? String else { return }
        let delta = payload["delta"] as? Int
        Task { @MainActor in
            let engine = WatchHapticEngine.shared
            guard engine.sessionUUID == uuid else { return }
            switch command {
            case "stop":
                if engine.phase == .running { engine.finish() }
            case "intensity":
                if engine.phase == .running, let delta { engine.adjustIntensity(by: delta) }
            case "completeRating":
                if engine.phase == .rating { engine.dismissRating() }
            default:
                break
            }
        }
        #endif
    }

    private func persistEpisode(from payload: [String: Any]) {
        #if os(iOS)
        guard let uuid = payload["episodeUUID"] as? String,
              let started = payload["startedAt"] as? TimeInterval,
              let ended = payload["endedAt"] as? TimeInterval,
              let causeRaw = payload["cause"] as? String,
              let severityBefore = payload["severityBefore"] as? Int,
              let intensity = payload["intensity"] as? Int,
              let plannedMinutes = payload["plannedMinutes"] as? Int
        else { return }
        let severityAfter = payload["severityAfter"] as? Int
        // Read every field out of the payload before the hop: `[String: Any]`
        // is not Sendable, so capturing it in the task is a data race.
        let mode = (payload["mode"] as? String).flatMap(ReliefMode.init(rawValue:)) ?? .pulse
        Task { @MainActor in
            // Upsert on the container's MAIN context: a background context save
            // doesn't refresh HistoryView's @Query until relaunch, which read
            // as "history is missing sessions". The explicit fetch also lets a
            // later rated payload update the unrated episode sent at finish.
            let context = DataService.sharedModelContainer.mainContext
            let descriptor = FetchDescriptor<ReliefEpisode>(predicate: #Predicate { $0.uuid == uuid })
            if let existing = try? context.fetch(descriptor).first {
                if let severityAfter {
                    existing.severityAfter = severityAfter
                }
                existing.intensity = intensity
                try? context.save()
                return
            }
            let episode = ReliefEpisode(
                uuid: uuid,
                startedAt: Date(timeIntervalSince1970: started),
                endedAt: Date(timeIntervalSince1970: ended),
                cause: NauseaCause(rawValue: causeRaw) ?? .general,
                mode: mode,
                severityBefore: severityBefore,
                severityAfter: severityAfter,
                intensity: intensity,
                plannedMinutes: plannedMinutes,
                source: .watch
            )
            context.insert(episode)
            try? context.save()
            AnalyticsService.sessionCompleted(
                source: .watch,
                minutes: episode.actualMinutes,
                reliefDelta: episode.reliefDelta
            )
        }
        #endif
    }
}
#endif
