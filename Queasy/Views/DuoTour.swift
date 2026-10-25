#if DEBUG
import Foundation
import os

/// Store captures on both iPhone Duo displays. `-DuoTour` walks the scenes on
/// a timer, because a capture job can launch the app but cannot tap it, and
/// `simctl openurl` raises a confirmation alert nobody can answer.
/// `-DuoTourFirst <s>` delays the first scene, `-DuoTourStep <s>` is the dwell
/// on each. Every step logs a `DUOTOUR` line that maps captures to scenes.
/// The walk repeats, so the outer and the inner display each see every scene.
@MainActor
@Observable
final class DuoTour {
    static let shared = DuoTour()
    private init() {}

    static let scenes = ["relieve", "session-breathe", "learn", "settings", "mode-breathe", "checkin", "upgrade"]

    private(set) var scene: String?
    private var isRunning = false
    private let logger = Logger(subsystem: "com.jackwallner.queasy", category: "DuoTour")

    nonisolated static func tab(for scene: String?) -> Int {
        switch scene {
        case "learn": return 2
        case "settings": return 3
        default: return 0
        }
    }

    func run() async {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-DuoTour"), !isRunning else { return }
        isRunning = true
        func seconds(_ key: String, _ fallback: Double) -> Double {
            guard let flag = args.firstIndex(of: key), args.indices.contains(flag + 1) else { return fallback }
            return Double(args[flag + 1]) ?? fallback
        }
        try? await Task.sleep(for: .seconds(seconds("-DuoTourFirst", 2)))
        let step = seconds("-DuoTourStep", 10)
        while !Task.isCancelled {
            for next in Self.scenes {
                scene = next
                logger.notice("DUOTOUR \(next, privacy: .public) \(Date.now.timeIntervalSince1970, privacy: .public)")
                try? await Task.sleep(for: .seconds(step))
            }
        }
    }
}
#endif
