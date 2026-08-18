import Foundation
import Testing
@testable import Queasy

struct EpisodeStatsTests {
    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    private func entry(
        daysAgo: Int,
        cause: NauseaCause = .motion,
        before: Int = 4,
        after: Int? = nil
    ) -> EpisodeStats.Entry {
        EpisodeStats.Entry(
            startedAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!,
            cause: cause,
            severityBefore: before,
            severityAfter: after
        )
    }

    @Test func emptyInputProducesEmptySummary() {
        let summary = EpisodeStats.summarize([], now: now)
        #expect(summary.totalSessions == 0)
        #expect(summary.sessionsThisWeek == 0)
        #expect(summary.averageReliefDelta == nil)
        #expect(summary.bestCause == nil)
    }

    @Test func weekWindowCountsLastSevenDays() {
        let entries = [
            entry(daysAgo: 0),
            entry(daysAgo: 6),
            entry(daysAgo: 7),
            entry(daysAgo: 30),
        ]
        let summary = EpisodeStats.summarize(entries, now: now)
        #expect(summary.totalSessions == 4)
        #expect(summary.sessionsThisWeek == 2)
    }

    @Test func averageIgnoresUnratedEpisodes() {
        let entries = [
            entry(daysAgo: 1, before: 4, after: 2),  // delta 2
            entry(daysAgo: 2, before: 3, after: 3),  // delta 0
            entry(daysAgo: 3, before: 5, after: nil),
        ]
        let summary = EpisodeStats.summarize(entries, now: now)
        #expect(summary.averageReliefDelta == 1.0)
    }

    @Test func bestCauseRequiresTwoRatedEpisodes() {
        let entries = [
            entry(daysAgo: 1, cause: .vertigo, before: 5, after: 1),  // one great episode — not enough
            entry(daysAgo: 2, cause: .motion, before: 4, after: 3),
            entry(daysAgo: 3, cause: .motion, before: 4, after: 2),
        ]
        let summary = EpisodeStats.summarize(entries, now: now)
        #expect(summary.bestCause == .motion)
    }

    @Test func bestCausePicksHighestAverageDelta() {
        let entries = [
            entry(daysAgo: 1, cause: .motion, before: 4, after: 3),    // avg 1
            entry(daysAgo: 2, cause: .motion, before: 4, after: 3),
            entry(daysAgo: 3, cause: .hangover, before: 5, after: 2),  // avg 3
            entry(daysAgo: 4, cause: .hangover, before: 5, after: 2),
        ]
        let summary = EpisodeStats.summarize(entries, now: now)
        #expect(summary.bestCause == .hangover)
    }

    @Test func reviewPromptOnlyAfterImprovementAtMilestones() {
        // Far-future "now" so a previously recorded prompt date can't interfere.
        let farFuture = Date(timeIntervalSince1970: 4_000_000_000)
        func decision(_ delta: Int?, _ count: Int) -> Bool {
            ReviewPromptTracker.shouldPrompt(afterReliefDelta: delta, sessionCount: count, now: farFuture)
        }
        #expect(decision(1, 2))
        #expect(!decision(0, 2))
        #expect(!decision(nil, 2))
        #expect(!decision(2, 3))
        #expect(decision(2, 15))
    }
}

extension EpisodeStatsTests {
    @Test func heatmapWindowStartsAtFirstEpisode() {
        let entries = [
            entry(daysAgo: 10),
            entry(daysAgo: 3),
            entry(daysAgo: 3, before: 5),
            entry(daysAgo: 0, before: 2),
        ]
        let days = EpisodeStats.heatmap(entries, days: 90, endingAt: now)
        #expect(days.count == 11)  // first episode 10 days ago -> 11 cells
        #expect(days.first?.count == 1)
        #expect(days.last?.count == 1)
        #expect(days.last?.peakSeverity == 2)
        let threeAgo = days[days.count - 4]
        #expect(threeAgo.count == 2)
        #expect(threeAgo.peakSeverity == 5)  // worst of the two check-ins wins
        #expect(days[1].count == 0)
        #expect(days[1].peakSeverity == nil)
    }

    @Test func heatmapCapsAtLookbackWindow() {
        let entries = [entry(daysAgo: 200), entry(daysAgo: 0)]
        let days = EpisodeStats.heatmap(entries, days: 90, endingAt: now)
        #expect(days.count == 90)
    }

    @Test func heatmapEmptyWithoutEpisodes() {
        #expect(EpisodeStats.heatmap([], endingAt: now).isEmpty)
    }
}
