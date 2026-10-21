package com.jackwallner.queasy

import com.jackwallner.queasy.data.ConversionDiagnostics
import com.jackwallner.queasy.data.InMemoryStore
import com.jackwallner.queasy.data.ReviewPromptTracker
import com.jackwallner.queasy.data.UpgradePromptTracker
import com.jackwallner.queasy.model.EpisodeStats
import com.jackwallner.queasy.model.NauseaCause
import com.jackwallner.queasy.model.ReliefEpisode
import com.jackwallner.queasy.model.ReliefMode
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** `EpisodeStatsTests.swift`, the Best mode and Upgrade prompt suites, `ReviewPromptTrackerTests.swift` and `PaywallFunnelTests.swift`. */
class StatsAndTrackersTest {
    private val now = Instant.ofEpochSecond(1_760_000_000)
    private val zone: ZoneId = ZoneOffset.UTC

    private fun entry(daysAgo: Long, cause: NauseaCause = NauseaCause.MOTION, before: Int = 4, after: Int? = null, mode: ReliefMode = ReliefMode.PULSE) =
        EpisodeStats.Entry(now.minusSeconds(daysAgo * 86_400), cause, mode, before, after)

    @Test fun emptyInputProducesEmptySummary() {
        val s = EpisodeStats.summarize(emptyList(), now, zone)
        assertEquals(0, s.totalSessions)
        assertEquals(0, s.sessionsThisWeek)
        assertNull(s.averageReliefDelta)
        assertNull(s.bestCause)
    }

    @Test fun weekWindowCountsLastSevenDays() {
        val s = EpisodeStats.summarize(listOf(entry(0), entry(6), entry(7), entry(30)), now, zone)
        assertEquals(4, s.totalSessions)
        assertEquals(2, s.sessionsThisWeek)
    }

    @Test fun averageIgnoresUnratedEpisodes() {
        val s = EpisodeStats.summarize(listOf(entry(1, before = 4, after = 2), entry(2, before = 3, after = 3), entry(3, before = 5)), now, zone)
        assertEquals(1.0, s.averageReliefDelta!!, 0.0)
    }

    @Test fun bestCauseRequiresTwoRatedEpisodes() {
        val s = EpisodeStats.summarize(
            listOf(entry(1, NauseaCause.VERTIGO, 5, 1), entry(2, NauseaCause.MOTION, 4, 3), entry(3, NauseaCause.MOTION, 4, 2)),
            now, zone,
        )
        assertEquals(NauseaCause.MOTION, s.bestCause)
    }

    @Test fun bestCausePicksHighestAverageDelta() {
        val s = EpisodeStats.summarize(
            listOf(
                entry(1, NauseaCause.MOTION, 4, 3), entry(2, NauseaCause.MOTION, 4, 3),
                entry(3, NauseaCause.HANGOVER, 5, 2), entry(4, NauseaCause.HANGOVER, 5, 2),
            ),
            now, zone,
        )
        assertEquals(NauseaCause.HANGOVER, s.bestCause)
    }

    @Test fun heatmapWindowStartsAtFirstEpisode() {
        val days = EpisodeStats.heatmap(listOf(entry(10), entry(3), entry(3, before = 5), entry(0, before = 2)), 90, now, zone)
        assertEquals(11, days.size)
        assertEquals(1, days.first().count)
        assertEquals(1, days.last().count)
        assertEquals(2, days.last().peakSeverity)
        val threeAgo = days[days.size - 4]
        assertEquals(2, threeAgo.count)
        assertEquals(5, threeAgo.peakSeverity)
        assertEquals(0, days[1].count)
        assertNull(days[1].peakSeverity)
    }

    @Test fun heatmapCapsAtLookbackWindow() {
        assertEquals(90, EpisodeStats.heatmap(listOf(entry(200), entry(0)), 90, now, zone).size)
    }

    @Test fun heatmapEmptyWithoutEpisodes() {
        assertTrue(EpisodeStats.heatmap(emptyList(), endingAt = now, zone = zone).isEmpty())
    }

    @Test fun picksTheModeWithTheBiggestAverageDrop() {
        val s = EpisodeStats.summarize(
            listOf(
                entry(0, before = 4, after = 1, mode = ReliefMode.BREATHE), entry(0, before = 4, after = 1, mode = ReliefMode.BREATHE),
                entry(0, before = 4, after = 3, mode = ReliefMode.PULSE), entry(0, before = 4, after = 3, mode = ReliefMode.PULSE),
            ),
            now, zone,
        )
        assertEquals(ReliefMode.BREATHE, s.bestMode)
    }

    @Test fun staysQuietUntilAModeHasTwoRatedSessions() {
        val s = EpisodeStats.summarize(listOf(entry(0, before = 5, after = 1, mode = ReliefMode.TONE), entry(0, before = 4, after = 2, mode = ReliefMode.PRESS)), now, zone)
        assertNull(s.bestMode)
    }

    @Test fun ignoresUnratedSessions() {
        val s = EpisodeStats.summarize(listOf(entry(0, mode = ReliefMode.PRESS), entry(0, mode = ReliefMode.PRESS)), now, zone)
        assertNull(s.bestMode)
    }

    @Test fun legacyEpisodesDefaultToPulse() {
        val e = ReliefEpisode(startedAt = now, causeRaw = "motion", severityBefore = 3, intensity = 5, plannedMinutes = 15, modeRaw = null)
        assertEquals(ReliefMode.PULSE, e.mode)
    }

    // Upgrade prompt

    private fun should(isPro: Boolean = false, capped: Boolean = true, count: Int = 3, store: InMemoryStore = InMemoryStore()) =
        UpgradePromptTracker(store).shouldPrompt(isPro, capped, count, Instant.EPOCH)

    @Test fun offersAtAMilestoneAfterACappedSession() = assertTrue(should())

    @Test fun staysQuietForSubscribers() = assertFalse(should(isPro = true))

    @Test fun staysQuietWhenNothingWasCapped() = assertFalse(should(capped = false))

    @Test fun staysQuietBetweenMilestones() {
        listOf(1, 2, 4).forEach { assertFalse(should(count = it)) }
    }

    @Test fun upgradeOfferWaitsOutItsCooldown() {
        val store = InMemoryStore()
        val tracker = UpgradePromptTracker(store)
        tracker.recordPrompt(now)
        assertFalse(tracker.shouldPrompt(false, true, 8, now.plusSeconds(4 * 86_400)))
        assertTrue(tracker.shouldPrompt(false, true, 8, now.plusSeconds(6 * 86_400)))
    }

    // Review prompt tracker

    private fun tracker(launches: Int = 9) = ReviewPromptTracker(InMemoryStore()) { now }.apply { appLaunchCount = launches }

    @Test fun asksFromTheSecondSession() = assertTrue(tracker(2).canRequestReview(hasCompletedSetup = true))

    @Test fun neverAsksInTheFirstSession() = assertFalse(tracker(1).canRequestReview(hasCompletedSetup = true))

    @Test fun stillRequiresFinishedOnboarding() = assertFalse(tracker().canRequestReview(hasCompletedSetup = false))

    @Test fun openingTheReviewPageEndsTheAsks() {
        val t = tracker()
        t.markOpenedWriteReview()
        t.lastShown = now.minusSeconds(365 * 86_400L)
        assertFalse(t.canRequestReview(true))
    }

    @Test fun waitsOutTheCooldown() {
        val t = tracker()
        t.lastShown = now.minusSeconds(10 * 86_400L)
        assertFalse(t.canRequestReview(true))
        t.lastShown = now.minusSeconds(31 * 86_400L)
        assertTrue(t.canRequestReview(true))
    }

    @Test fun feedbackNeverEndsTheAsks() {
        val t = tracker()
        t.markFeedbackSubmitted()
        assertEquals(ReviewPromptTracker.Outcome.SUBMITTED_FEEDBACK, t.outcome)
        assertNull("feedback must not start a cooldown", t.lastShown)
        assertTrue(t.canRequestReview(true))
    }

    @Test fun feedbackAfterTheReviewPageKeepsTheAsksEnded() {
        val t = tracker()
        t.markOpenedWriteReview()
        t.markFeedbackSubmitted()
        assertEquals(ReviewPromptTracker.Outcome.OPENED_WRITE_REVIEW, t.outcome)
        assertFalse(t.canRequestReview(true))
    }

    @Test fun blockedAskKeepsTheMomentPending() {
        val t = tracker()
        t.recordPositiveMoment()
        assertTrue(t.shouldRequestAfterPositiveMoment(true))
        assertTrue(t.shouldRequestAfterPositiveMoment(true))
        t.markShown()
        assertFalse(t.shouldRequestAfterPositiveMoment(true))
    }

    @Test fun automationRunsNeverCountOrAsk() {
        val t = tracker(0).apply { isAutomationRun = true }
        t.recordAppLaunch()
        t.recordPositiveMoment()
        assertEquals(0, t.appLaunchCount)
        assertFalse(t.hasPendingPositiveMoment)
        t.appLaunchCount = 5
        assertFalse(t.canRequestReview(true))
    }

    // Conversion diagnostics (fleet-wide paywall record)

    private fun diagnostics(clock: () -> Instant = { now }) = ConversionDiagnostics(InMemoryStore(), clock)

    @Test fun countsPitchesPerSurfaceAndInTotal() {
        val d = diagnostics()
        d.recordPitchView("queasy_after_session")
        d.recordPitchView("queasy_after_session")
        d.recordPitchView("queasy_history")
        val a = d.subscriberAttributes
        assertEquals("3", a["pitch_views_total"])
        assertEquals("2", a["pitch_views_after_session"])
        assertEquals("history", a["pitch_last"])
    }

    @Test fun noAttributesBeforeAnyPitchIsSeen() {
        val d = diagnostics()
        d.recordAppOpen()
        assertTrue(d.subscriberAttributes.isEmpty())
    }

    @Test fun recordsHowEarlyTheFirstPitchArrived() {
        val d = diagnostics()
        d.recordAppOpen()
        d.recordAppOpen()
        d.recordPitchView("queasy_after_session")
        assertEquals("2", d.subscriberAttributes["opens_before_first_pitch"])
        assertEquals("0", d.subscriberAttributes["days_since_install"])
    }

    @Test fun theEarlinessPairIsFrozenOnTheFirstPitchOnly() {
        val d = diagnostics()
        d.recordAppOpen()
        d.recordPitchView("queasy_after_session")
        d.recordAppOpen()
        d.recordPitchView("queasy_history")
        assertEquals("1", d.subscriberAttributes["opens_before_first_pitch"])
    }

    @Test fun anInstallThatPredatesThisCodeReportsNoAge() {
        val d = diagnostics()
        d.recordPitchView("queasy_after_session")
        assertNull(d.subscriberAttributes["days_since_install"])
        assertEquals("1", d.subscriberAttributes["pitch_views_total"])
    }

    @Test fun conversionFreezesTheSurfaceAndCountAtTheMomentOfSale() {
        val d = diagnostics()
        d.recordPitchView("queasy_after_session")
        d.recordPitchView("queasy_history")
        d.recordConversion("yearly", startedTrial = true, offeringId = "default")
        d.recordPitchView("queasy_after_session")
        val a = d.subscriberAttributes
        assertEquals("history", a["converted_surface"])
        assertEquals("2", a["pitch_views_at_convert"])
        assertEquals("true", a["converted_with_trial"])
        assertEquals("default", a["converted_offering"])
    }

    @Test fun onlyTheFirstConversionIsRecorded() {
        val d = diagnostics()
        d.recordPitchView("queasy_after_session")
        d.recordConversion("monthly", startedTrial = true)
        d.recordConversion("yearly", startedTrial = false)
        assertEquals("monthly", d.subscriberAttributes["converted_plan"])
        assertEquals("true", d.subscriberAttributes["converted_with_trial"])
    }

    @Test fun attributeKeysStayInsideRevenueCatsLimit() {
        val d = diagnostics()
        d.recordPitchView("queasy_" + "a".repeat(80))
        d.subscriberAttributes.keys.forEach { assertTrue("too long: $it", it.length <= 40) }
    }

    @Test fun noAttributeCarriesFreeTextOrHealthData() {
        val d = diagnostics()
        d.recordAppOpen()
        d.recordPitchView("queasy_after_session")
        d.recordConversion("monthly", startedTrial = false)
        d.subscriberAttributes.forEach { (key, value) ->
            assertFalse("$key looks like free text: $value", value.contains(" "))
            assertTrue("$key is too long to be a label", value.length <= 64)
        }
    }
}
