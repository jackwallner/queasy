import Foundation

/// Pure aggregation over episodes for the History header. Takes plain tuples so
/// unit tests don't need SwiftData.
enum EpisodeStats {
    struct Summary: Equatable {
        var totalSessions: Int
        var sessionsThisWeek: Int
        /// Mean of (before - after) across rated episodes; nil when none rated.
        var averageReliefDelta: Double?
        /// Cause with the best average relief delta (min 2 rated episodes).
        var bestCause: NauseaCause?
        /// Mode the user tends to come out of feeling better (min 2 rated).
        /// This is the thing Pro promises to show, so it is computed the same
        /// cautious way: two sessions before it will say anything at all.
        var bestMode: ReliefMode?
    }

    struct Entry {
        var startedAt: Date
        var cause: NauseaCause
        var mode: ReliefMode = .pulse
        var severityBefore: Int
        var severityAfter: Int?
    }

    static func summarize(_ entries: [Entry], now: Date = Date(), calendar: Calendar = .current) -> Summary {
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let thisWeek = entries.filter { $0.startedAt >= weekStart }.count

        let rated = entries.compactMap { entry -> (cause: NauseaCause, mode: ReliefMode, delta: Int)? in
            guard let after = entry.severityAfter else { return nil }
            return (entry.cause, entry.mode, entry.severityBefore - after)
        }
        let avg: Double? = rated.isEmpty
            ? nil
            : Double(rated.reduce(0) { $0 + $1.delta }) / Double(rated.count)

        var byCause: [NauseaCause: [Int]] = [:]
        var byMode: [ReliefMode: [Int]] = [:]
        for item in rated {
            byCause[item.cause, default: []].append(item.delta)
            byMode[item.mode, default: []].append(item.delta)
        }
        let best = byCause
            .filter { $0.value.count >= 2 }
            .map { (cause: $0.key, avg: Double($0.value.reduce(0, +)) / Double($0.value.count)) }
            .max { $0.avg < $1.avg }?
            .cause
        let bestMode = byMode
            .filter { $0.value.count >= 2 }
            .map { (mode: $0.key, avg: Double($0.value.reduce(0, +)) / Double($0.value.count)) }
            .max { $0.avg < $1.avg }?
            .mode

        return Summary(
            totalSessions: entries.count,
            sessionsThisWeek: thisWeek,
            averageReliefDelta: avg,
            bestCause: best,
            bestMode: bestMode
        )
    }

    // MARK: - Calendar heatmap

    /// One cell per calendar day in the lookback window (queasy-log view).
    struct HeatmapDay: Identifiable, Equatable, Sendable {
        var date: Date
        var count: Int
        /// Worst check-in severity that day (1-5); nil on calm days.
        var peakSeverity: Int?

        var id: Date { date }
    }

    /// Builds the day grid for the last `days` days, starting no earlier than
    /// the first logged episode (rendering earlier days would imply data we
    /// don't have).
    static func heatmap(
        _ entries: [Entry],
        days: Int = 90,
        endingAt end: Date = Date(),
        calendar: Calendar = .current
    ) -> [HeatmapDay] {
        let today = calendar.startOfDay(for: end)
        guard let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: today),
              let firstEpisode = entries.map(\.startedAt).min()
        else { return [] }
        let firstDay = calendar.startOfDay(for: firstEpisode)
        let start = max(windowStart, min(firstDay, today))

        var byDay: [Date: (count: Int, peak: Int?)] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.startedAt)
            guard day >= start, day <= today else { continue }
            var cell = byDay[day] ?? (count: 0, peak: nil)
            cell.count += 1
            cell.peak = max(cell.peak ?? 0, entry.severityBefore)
            byDay[day] = cell
        }

        var out: [HeatmapDay] = []
        var cursor = start
        while cursor <= today {
            let cell = byDay[cursor]
            out.append(HeatmapDay(date: cursor, count: cell?.count ?? 0, peakSeverity: cell?.peak))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86_400)
        }
        return out
    }
}
