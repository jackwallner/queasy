import Foundation
import Testing

@testable import Queasy

@Suite("Modes")
struct ModeTests {
    private func checkIn(
        cause: NauseaCause = .general,
        severity: Int = 3,
        stillExposed: Bool = false,
        recentlyAte: Bool = false,
        mode: ReliefMode? = nil
    ) -> CheckIn {
        CheckIn(
            cause: cause,
            severity: severity,
            stillExposed: stillExposed,
            recentlyAte: recentlyAte,
            mode: mode
        )
    }

    @Test func everyCauseSuggestsEveryMode() {
        for cause in NauseaCause.allCases {
            let modes = PatternEngine.suggestedModes(for: cause)
            #expect(Set(modes) == Set(ReliefMode.allCases))
            #expect(modes.count == ReliefMode.allCases.count)
        }
    }

    /// The first suggestion is the mode with the most directly relevant
    /// published work, which is the claim the Learn copy makes.
    @Test func firstSuggestionMatchesTheLiterature() {
        #expect(PatternEngine.suggestedModes(for: .motion).first == .tone)
        #expect(PatternEngine.suggestedModes(for: .morningSickness).first == .press)
        #expect(PatternEngine.suggestedModes(for: .anxiety).first == .breathe)
    }

    @Test func planTakesTheCheckInsModeWhenSet() {
        let plan = PatternEngine.recommend(for: checkIn(cause: .motion, mode: .breathe))
        #expect(plan.mode == .breathe)
    }

    @Test func planFallsBackToTheSuggestedMode() {
        let plan = PatternEngine.recommend(for: checkIn(cause: .motion))
        #expect(plan.mode == .tone)
    }

    @Test func morningSicknessStartsGentlerAndRunsLonger() {
        let worst = PatternEngine.recommend(for: checkIn(cause: .morningSickness, severity: 5, stillExposed: true))
        #expect(worst.intensity <= PatternEngine.morningSicknessIntensityCap)

        let general = PatternEngine.recommend(for: checkIn(cause: .general, severity: 3))
        let morning = PatternEngine.recommend(for: checkIn(cause: .morningSickness, severity: 3))
        #expect(morning.durationMinutes > general.durationMinutes)
    }

    @Test func morningSicknessCarriesAProviderNote() {
        #expect(NauseaCause.morningSickness.safetyNote != nil)
        #expect(NauseaCause.motion.safetyNote == nil)
    }

    @Test func worseWavesGetALongerExhale() {
        let mild = PatternEngine.breathePattern(for: 1)
        let bad = PatternEngine.breathePattern(for: 5)
        #expect(bad.exhaleSeconds > mild.exhaleSeconds)
        for pattern in BreathePattern.all {
            #expect(pattern.exhaleSeconds > pattern.inhaleSeconds)
        }
    }

    @Test func toneIsTheOnlyModeThatCannotRunOnTheWrist() {
        #expect(ReliefMode.allCases.filter { !$0.runsOnWatch } == [.tone])
        #expect(ReliefMode.allCases.filter(\.needsHeadphones) == [.tone])
    }

    /// Pulse is the one mode with no citation, because there is no trial of a
    /// watch buzz at P6. Keeping that honest is the whole point of the rebuild,
    /// so it is a test rather than a comment.
    @Test func onlyPulseIsUncited() {
        for mode in ReliefMode.allCases where mode != .pulse {
            #expect(mode.evidenceNote != nil)
            #expect(mode.sourceURL != nil)
        }
        #expect(ReliefMode.pulse.evidenceNote == nil)
        #expect(ReliefMode.pulse.sourceURL == nil)
    }

    /// Plans written by 1.0.1, or in flight from a watch that has not updated,
    /// have no `mode` or `breathe` key.
    @Test func legacyPlansStillDecode() throws {
        let legacy = """
        {"cause":"motion","intensity":7,"durationMinutes":20,"severityBefore":4,"tips":["a"]}
        """
        let plan = try JSONDecoder().decode(ReliefPlan.self, from: Data(legacy.utf8))
        #expect(plan.mode == .pulse)
        #expect(plan.breathe == .relaxed)
        #expect(plan.intensity == 7)
        #expect(plan.cause == .motion)
    }

    @Test func planRoundTripsWithItsMode() throws {
        let plan = ReliefPlan(
            cause: .morningSickness,
            mode: .breathe,
            intensity: 4,
            breathe: .slower,
            durationMinutes: 22,
            severityBefore: 3,
            tips: []
        )
        let data = try JSONEncoder().encode(plan)
        #expect(try JSONDecoder().decode(ReliefPlan.self, from: data) == plan)
    }
}

@Suite("Free tier")
struct FreeTierTests {
    @Test func freeCapsTheModesWhoseLengthIsChosen() {
        for mode in [ReliefMode.pulse, .breathe] {
            #expect(FreeTier.cappedSeconds(for: mode, requested: 45 * 60, isPro: false) == FreeTier.sessionSeconds)
            #expect(FreeTier.isCapped(mode, requested: 45 * 60, isPro: false))
        }
    }

    /// Tone's minute and Press's three are protocols, not a length anyone
    /// chose, so they run in full for everyone.
    @Test func fixedProtocolModesAreNeverShortened() {
        #expect(FreeTier.cappedSeconds(for: .tone, requested: 60, isPro: false) == 60)
        #expect(FreeTier.cappedSeconds(for: .press, requested: PressProtocol.holdSeconds, isPro: false) == PressProtocol.holdSeconds)
        #expect(!FreeTier.isCapped(.press, requested: PressProtocol.holdSeconds, isPro: false))
    }

    @Test func proIsNeverCapped() {
        for mode in ReliefMode.allCases {
            #expect(FreeTier.cappedSeconds(for: mode, requested: 45 * 60, isPro: true) == 45 * 60)
            #expect(!FreeTier.isCapped(mode, requested: 45 * 60, isPro: true))
        }
    }

    @Test func aShortSessionIsNotCappedEvenWhenFree() {
        #expect(FreeTier.cappedSeconds(for: .pulse, requested: 60, isPro: false) == 60)
        #expect(!FreeTier.isCapped(.pulse, requested: 60, isPro: false))
    }

    @Test func everyProFeatureHasCopy() {
        for feature in ProFeature.allCases {
            #expect(!feature.title.isEmpty)
            #expect(!feature.detail.isEmpty)
        }
    }
}

@Suite("Upgrade prompt")
struct UpgradePromptTests {
    private func should(
        isPro: Bool = false,
        capped: Bool = true,
        count: Int = 3,
        reviewFiring: Bool = false
    ) -> Bool {
        UpgradePromptTracker.shouldPrompt(
            isPro: isPro,
            sessionWasCapped: capped,
            sessionCount: count,
            reviewPromptFiring: reviewFiring,
            now: Date(timeIntervalSince1970: 0)
        )
    }

    @Test func offersAtAMilestoneAfterACappedSession() {
        #expect(should())
    }

    @Test func staysQuietForSubscribers() {
        #expect(!should(isPro: true))
    }

    /// Nothing to sell if the session never ran out of room.
    @Test func staysQuietWhenNothingWasCapped() {
        #expect(!should(capped: false))
    }

    @Test func yieldsToTheReviewAsk() {
        #expect(!should(reviewFiring: true))
    }

    @Test func staysQuietBetweenMilestones() {
        #expect(!should(count: 1))
        #expect(!should(count: 2))
        #expect(!should(count: 4))
    }
}

@Suite("Best mode")
struct BestModeTests {
    private func entry(_ mode: ReliefMode, before: Int, after: Int?) -> EpisodeStats.Entry {
        EpisodeStats.Entry(startedAt: .now, cause: .general, mode: mode, severityBefore: before, severityAfter: after)
    }

    @Test func picksTheModeWithTheBiggestAverageDrop() {
        let summary = EpisodeStats.summarize([
            entry(.breathe, before: 4, after: 1),
            entry(.breathe, before: 4, after: 1),
            entry(.pulse, before: 4, after: 3),
            entry(.pulse, before: 4, after: 3),
        ])
        #expect(summary.bestMode == .breathe)
    }

    /// One good session is a coincidence. Pro promises a pattern, so it waits
    /// for two before naming anything.
    @Test func staysQuietUntilAModeHasTwoRatedSessions() {
        let summary = EpisodeStats.summarize([
            entry(.tone, before: 5, after: 1),
            entry(.press, before: 4, after: 2),
        ])
        #expect(summary.bestMode == nil)
    }

    @Test func ignoresUnratedSessions() {
        let summary = EpisodeStats.summarize([
            entry(.press, before: 4, after: nil),
            entry(.press, before: 4, after: nil),
        ])
        #expect(summary.bestMode == nil)
    }

    /// Episodes written before the rebuild have no mode and read as Pulse.
    @Test func legacyEpisodesDefaultToPulse() {
        let episode = ReliefEpisode(
            startedAt: .now,
            cause: .motion,
            severityBefore: 3,
            intensity: 5,
            plannedMinutes: 15,
            source: .phone
        )
        episode.modeRaw = nil
        #expect(episode.mode == .pulse)
    }
}

@Suite("Breathing pacer")
struct BreathingBloomTests {
    @Test func phaseFollowsTheCycle() {
        let anchor = Date(timeIntervalSince1970: 0)
        let pattern = BreathePattern.relaxed  // 4 in, 6 out

        let start = BreathingBloom.phase(at: anchor, anchor: anchor, pattern: pattern)
        #expect(start.isInhale)
        #expect(start.progress == 0)

        let midInhale = BreathingBloom.phase(at: anchor.addingTimeInterval(2), anchor: anchor, pattern: pattern)
        #expect(midInhale.isInhale)
        #expect(abs(midInhale.progress - 0.5) < 0.001)

        let midExhale = BreathingBloom.phase(at: anchor.addingTimeInterval(7), anchor: anchor, pattern: pattern)
        #expect(!midExhale.isInhale)

        // One full cycle later it is back at the top of an in-breath.
        let nextCycle = BreathingBloom.phase(at: anchor.addingTimeInterval(10), anchor: anchor, pattern: pattern)
        #expect(nextCycle.isInhale)
        #expect(abs(nextCycle.progress) < 0.001)
    }

    @Test func phaseSurvivesAClockThatRunsBackwards() {
        let anchor = Date(timeIntervalSince1970: 100)
        let phase = BreathingBloom.phase(at: anchor.addingTimeInterval(-30), anchor: anchor, pattern: .relaxed)
        #expect(phase.isInhale)
        #expect(phase.progress >= 0)
    }
}
