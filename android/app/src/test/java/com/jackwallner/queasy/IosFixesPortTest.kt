package com.jackwallner.queasy

import com.jackwallner.queasy.data.AppSettings
import com.jackwallner.queasy.data.InMemoryStore
import com.jackwallner.queasy.model.CheckIn
import com.jackwallner.queasy.model.EpisodeStats
import com.jackwallner.queasy.model.FreeTier
import com.jackwallner.queasy.model.NauseaCause
import com.jackwallner.queasy.model.PatternEngine
import com.jackwallner.queasy.model.PressProtocol
import com.jackwallner.queasy.model.ReliefMode
import com.jackwallner.queasy.model.ReliefPlan
import com.jackwallner.queasy.ui.screens.modePlanFor
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Test

/** Android twins of iOS fixes 3091f6c (fixed protocol lengths) and d3494c5 (heatmap across a DST gap). */
class IosFixesPortTest {
    // 3091f6c: ResolvedSessionDurationTests

    @Test fun checkInProtocolsKeepTheirDurationAfterPreferences() {
        for (override in listOf<Int?>(null, 1, 30)) {
            val settings = AppSettings(InMemoryStore())
            settings.updateDefaultDuration(override)
            for (cause in NauseaCause.entries) {
                for (severity in 1..5) {
                    for (mode in ReliefMode.entries) {
                        val checkIn = CheckIn(cause, severity, stillExposed = false, recentlyAte = false, mode = mode)
                        val original = PatternEngine.recommend(checkIn)
                        val resolved = settings.resolvedPlan(original)
                        val expected = when (mode) {
                            ReliefMode.TONE -> 60
                            ReliefMode.PRESS -> 180
                            ReliefMode.PULSE, ReliefMode.BREATHE -> (override ?: original.durationMinutes) * 60
                        }
                        assertEquals("$override $cause $severity $mode", expected, resolved.durationMinutes * 60)
                        for (isPro in listOf(false, true)) {
                            val granted = FreeTier.cappedSeconds(mode, resolved.durationMinutes * 60, isPro)
                            val want = if (mode.hasVariableDuration && !isPro) minOf(expected, FreeTier.SESSION_SECONDS) else expected
                            assertEquals(want, granted)
                        }
                        assertEquals(original, PatternEngine.recommend(checkIn))
                    }
                }
            }
        }
    }

    @Test fun modeCardsKeepFixedLengthsWhateverTheLastPlanWas() {
        for (override in listOf<Int?>(null, 30)) {
            for (lastMode in ReliefMode.entries) {
                val settings = AppSettings(InMemoryStore())
                settings.updateDefaultDuration(override)
                settings.updateLastPlan(ReliefPlan.quickStart(lastMode))
                assertEquals(60, modePlanFor(settings, ReliefMode.TONE).durationMinutes * 60)
                assertEquals(PressProtocol.HOLD_SECONDS, modePlanFor(settings, ReliefMode.PRESS).durationMinutes * 60)
                // A variable mode started from a Tone or Press plan must not inherit its short length.
                val pulse = modePlanFor(settings, ReliefMode.PULSE)
                assertEquals(override ?: ReliefPlan.quickStart(lastMode).durationMinutes.coerceAtLeast(PatternEngine.MIN_DURATION), pulse.durationMinutes)
            }
        }
    }

    // d3494c5: the heatmap keeps every day where DST skips local midnight. LocalDate steps cannot drift.

    private fun at(zone: ZoneId, date: String, hour: Int = 12): Instant =
        LocalDate.parse(date).atTime(hour, 0).atZone(zone).toInstant()

    private fun entry(startedAt: Instant) = EpisodeStats.Entry(startedAt, NauseaCause.MOTION, ReliefMode.PULSE, 3, null)

    @Test fun heatmapKeepsEveryDayWhereDstSkipsMidnight() {
        // Cairo, Beirut and Havana move the clocks at local midnight, so a day starts at 01:00.
        for (id in listOf("Africa/Cairo", "Asia/Beirut", "America/Havana", "America/Los_Angeles")) {
            val zone = ZoneId.of(id)
            val first = LocalDate.of(2026, 3, 20)
            val dates = (0L until 20L).map { first.plusDays(it) }
            val entries = dates.map { entry(at(zone, it.toString())) }
            val days = EpisodeStats.heatmap(entries, 90, at(zone, "2026-04-08", 20), zone)
            assertEquals(id, dates, days.map { it.date })
            assertEquals(id, List(dates.size) { 1 }, days.map { it.count })
        }
    }

    @Test fun heatmapKeepsEveryDayAcrossFallBackAndAWestwardMove() {
        val la = ZoneId.of("America/Los_Angeles")
        val first = LocalDate.of(2026, 10, 28)
        val dates = (0L until 10L).map { first.plusDays(it) }
        val entries = dates.map { entry(at(la, it.toString())) }
        val days = EpisodeStats.heatmap(entries, 90, at(la, "2026-11-06", 20), la)
        assertEquals(dates, days.map { it.date })
        assertEquals(List(10) { 1 }, days.map { it.count })
        // The same episodes read in a zone further west land on their local days without gaps.
        val honolulu = ZoneId.of("Pacific/Honolulu")
        val west = EpisodeStats.heatmap(entries, 90, at(la, "2026-11-06", 20), honolulu)
        assertEquals(west.map { it.date }.distinct(), west.map { it.date })
        assertEquals(entries.size, west.sumOf { it.count })
    }
}
