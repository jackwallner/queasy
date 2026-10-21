package com.jackwallner.queasy

import com.jackwallner.queasy.data.AppSettings
import com.jackwallner.queasy.data.EpisodeCodec
import com.jackwallner.queasy.data.EpisodeFile
import com.jackwallner.queasy.data.EpisodeStore
import com.jackwallner.queasy.data.InMemoryStore
import com.jackwallner.queasy.data.PackageKind
import com.jackwallner.queasy.data.PeriodUnit
import com.jackwallner.queasy.data.Plan
import com.jackwallner.queasy.data.PlanPeriod
import com.jackwallner.queasy.data.PressReminders
import com.jackwallner.queasy.data.ReviewAccess
import com.jackwallner.queasy.model.BreathePattern
import com.jackwallner.queasy.model.FreeTier
import com.jackwallner.queasy.model.HapticPatterns
import com.jackwallner.queasy.model.NauseaCause
import com.jackwallner.queasy.model.PulseSpec
import com.jackwallner.queasy.model.PulseStrength
import com.jackwallner.queasy.model.ReliefEpisode
import com.jackwallner.queasy.model.ReliefMode
import com.jackwallner.queasy.model.ReliefPlan
import com.jackwallner.queasy.model.Waveform
import com.jackwallner.queasy.session.Haptics
import com.jackwallner.queasy.session.SessionController
import com.jackwallner.queasy.session.ToneGenerator
import com.jackwallner.queasy.session.TonePlayer
import com.jackwallner.queasy.ui.screens.disclosure
import com.jackwallner.queasy.ui.screens.historyCsv
import com.jackwallner.queasy.ui.screens.specDescription
import com.jackwallner.queasy.ui.screens.visibleEpisodes
import java.security.MessageDigest
import java.time.Instant
import java.time.ZoneOffset
import java.time.ZonedDateTime
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToLong
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** What only the Android port has: the vibration waveforms, the tone, storage, billing copy, reminders and the session loop. */
class AndroidPortTest {
    // Vibration

    @Test fun everyPulseLevelLoopsAtItsInterval() {
        for (spec in PulseSpec.levels) {
            val wave = HapticPatterns.pulse(spec)
            assertEquals((spec.interval * 1000).roundToLong(), wave.totalMillis)
            assertEquals(spec.burstCount, wave.amplitudes.count { it > 0 })
            assertEquals(wave.timings.size, wave.amplitudes.size)
            assertTrue(wave.timings.all { it > 0 })
        }
    }

    @Test fun tapsInABurstStartTheSwiftGapApart() {
        val wave = HapticPatterns.pulse(PulseSpec.forLevel(10))
        val tap = HapticPatterns.tapMillis(PulseStrength.STRONG)
        assertEquals(tap, wave.timings[0])
        assertEquals(140L, wave.timings[0] + wave.timings[1])
        assertEquals(140L, wave.timings[2] + wave.timings[3])
    }

    @Test fun strongerLevelsTapHarderAndLonger() {
        val soft = HapticPatterns.pulse(PulseSpec.forLevel(1))
        val strong = HapticPatterns.pulse(PulseSpec.forLevel(10))
        assertTrue(strong.amplitudes.max() > soft.amplitudes.max())
        assertTrue(strong.timings[0] > soft.timings[0])
    }

    @Test fun breathSwellsInAndFadesOutOverOneCycle() {
        for (pattern in BreathePattern.ALL) {
            val wave = HapticPatterns.breath(pattern)
            assertEquals((pattern.cycleSeconds * 1000).roundToLong(), wave.totalMillis)
            assertTrue(wave.amplitudes.all { it in 1..255 })
            val inhaleSteps = ((pattern.inhaleSeconds * 1000).toLong() / HapticPatterns.BREATH_STEP_MILLIS).toInt()
            val inhale = wave.amplitudes.take(inhaleSteps)
            assertEquals(inhale.sorted(), inhale)
            val exhale = wave.amplitudes.drop(inhaleSteps + 1)
            assertEquals(exhale.sortedDescending(), exhale)
            assertTrue(abs(inhale.first() - 0.10 * 255) <= 1)
            assertTrue(abs(inhale.last() - 0.62 * 255) <= 1)
        }
    }

    @Test fun onOffBreathMarksEachPhaseWithinOneCycle() {
        for (pattern in BreathePattern.ALL) {
            val wave = HapticPatterns.breathOnOff(pattern)
            assertEquals((pattern.cycleSeconds * 1000).roundToLong(), wave.totalMillis)
            assertEquals((pattern.inhaleSeconds * 1000).roundToLong(), wave.timings[0] + wave.timings[1])
            assertTrue(wave.timings.all { it > 0 })
        }
    }

    // Tone

    @Test fun toneBufferIsWholeCyclesOfA100HzSineAtTheSwiftAmplitude() {
        val buffer = ToneGenerator.buffer()
        assertEquals(441 * ToneGenerator.CYCLES, buffer.size)
        val peak = buffer.maxOf { abs(it.toInt()) }
        assertEquals(0.18 * Short.MAX_VALUE, peak.toDouble(), 2.0)
        // Seamless loop: the sample after the last is the first sample again.
        assertEquals(0, buffer.first().toInt())
        assertTrue(abs(buffer.last().toInt()) < 0.18 * Short.MAX_VALUE * 0.02)
        val crossings = buffer.toList().zipWithNext().count { (a, b) -> a < 0 && b >= 0 }
        assertEquals(ToneGenerator.CYCLES - 1, crossings)
    }

    // Storage

    private class MemoryFile(var text: String? = null, var fail: Boolean = false) : EpisodeFile {
        override fun read() = text
        override fun write(text: String): Boolean {
            if (fail) return false
            this.text = text
            return true
        }
    }

    private fun episode(daysAgo: Long, after: Int? = 2, mode: ReliefMode = ReliefMode.BREATHE, now: Instant = Instant.ofEpochSecond(1_760_000_000)) =
        ReliefEpisode(
            uuid = "e$daysAgo",
            startedAt = now.minusSeconds(daysAgo * 86_400),
            endedAt = now.minusSeconds(daysAgo * 86_400 - 120),
            causeRaw = "motion",
            severityBefore = 4,
            severityAfter = after,
            intensity = 7,
            plannedMinutes = 2,
            modeRaw = mode.raw,
        )

    @Test fun episodesRoundTripAndSkipCorruptRows() {
        val list = listOf(episode(0), episode(3, after = null, mode = ReliefMode.PRESS))
        assertEquals(list, EpisodeCodec.decode(EpisodeCodec.encode(list)))
        val withJunk = EpisodeCodec.encode(list).replaceFirst("[", "[{\"uuid\":1},")
        assertEquals(list, EpisodeCodec.decode(withJunk))
        assertTrue(EpisodeCodec.decode("garbage").isEmpty())
        val legacy = EpisodeCodec.decode("""[{"uuid":"x","startedAt":0,"cause":"motion","severityBefore":3,"intensity":5,"plannedMinutes":15}]""")
        assertEquals(ReliefMode.PULSE, legacy.single().mode)
        assertNull(legacy.single().modeRaw)
    }

    @Test fun storeUpsertsByUuidNewestFirstAndPersists() {
        val file = MemoryFile()
        val store = EpisodeStore(file)
        store.upsert(episode(5))
        store.upsert(episode(1))
        store.upsert(episode(5).copy(severityAfter = 1))
        assertEquals(listOf("e1", "e5"), store.episodes.map { it.uuid })
        assertEquals(1, store.episodes.last().severityAfter)
        assertEquals(store.episodes, EpisodeStore(file).episodes)
        store.delete("e1")
        assertEquals(listOf("e5"), EpisodeStore(file).episodes.map { it.uuid })
    }

    @Test fun aFailedSaveIsReported() {
        val store = EpisodeStore(MemoryFile(fail = true))
        store.upsert(episode(0))
        assertTrue(store.saveFailure != null)
    }

    @Test fun freeHistoryShowsTheLastSevenDaysAndProShowsAll() {
        val now = Instant.ofEpochSecond(1_760_000_000)
        val all = listOf(episode(0), episode(6), episode(8), episode(40))
        assertEquals(listOf("e0", "e6"), visibleEpisodes(all, isPro = false, now = now).map { it.uuid })
        assertEquals(all, visibleEpisodes(all, isPro = true, now = now))
    }

    @Test fun csvExportKeepsTheIosColumnsOldestFirst() {
        val csv = historyCsv(listOf(episode(0), episode(3, after = null))).lines()
        assertEquals("started_at,ended_at,cause,severity_before,severity_after,intensity,planned_minutes,source", csv[0])
        assertEquals(3, csv.size)
        assertEquals("2025-10-06T08:53:20Z,2025-10-06T08:55:20Z,motion,4,,7,2,phone", csv[1])
        assertTrue(csv[2].endsWith(",motion,4,2,7,2,phone"))
    }

    @Test fun settingsApplyOverridesAndPersistUnderTheIosKeys() {
        val defaults = InMemoryStore()
        val settings = AppSettings(defaults)
        val plan = ReliefPlan.quickStart(ReliefMode.BREATHE)
        assertEquals(plan, settings.resolvedPlan(plan))
        settings.updateDefaultDuration(30)
        settings.updateDefaultBreatheIndex(2)
        settings.updateLastPlan(plan)
        settings.completeOnboarding()
        val resolved = settings.resolvedPlan(plan)
        assertEquals(30, resolved.durationMinutes)
        assertEquals(BreathePattern.SLOWER, resolved.breathe)
        assertEquals(30, defaults.getInt("defaultDurationMinutes"))
        assertEquals(2, defaults.getInt("defaultBreatheIndex"))
        assertTrue(defaults.getBoolean("hasCompletedOnboarding"))
        val reloaded = AppSettings(defaults)
        assertEquals(plan, reloaded.lastPlan)
        settings.updateDefaultDuration(null)
        assertFalse(defaults.contains("defaultDurationMinutes"))
        assertEquals(1, settings.incrementCompletedSessions())
    }

    // Billing copy and review access

    private val yearly = Plan("\$rc_annual", "com.jackwallner.queasy.pro.yearly", PackageKind.YEARLY, 14_990_000, "$14.99", "USD", PlanPeriod(1, PeriodUnit.YEAR), PlanPeriod(1, PeriodUnit.WEEK))
    private val monthly = Plan("\$rc_monthly", "com.jackwallner.queasy.pro.monthly", PackageKind.MONTHLY, 2_990_000, "$2.99", "USD", PlanPeriod(1, PeriodUnit.MONTH), PlanPeriod(1, PeriodUnit.WEEK))
    private val lifetime = Plan("\$rc_lifetime", "com.jackwallner.queasy.pro.lifetime", PackageKind.LIFETIME, 29_990_000, "$29.99", "USD", null, null)

    @Test fun planLabelsMatchTheIosPaywall() {
        Locale.setDefault(Locale.US)
        assertEquals("$14.99 / year", yearly.priceLabel)
        assertEquals("$2.99 / month", monthly.priceLabel)
        assertEquals("$29.99", lifetime.priceLabel)
        assertEquals("7-day free trial", yearly.introOfferLabel)
        assertEquals("$1.25/mo", yearly.perMonthLabel)
        assertNull(monthly.perMonthLabel)
        // iOS mock: "SAVE 58%" for $14.99 against 12 x $2.99.
        assertEquals(58, yearly.savingsPercent(monthly))
        assertNull(monthly.savingsPercent(monthly))
        assertEquals(listOf("Yearly", "Monthly", "Lifetime"), listOf(yearly, monthly, lifetime).map { it.displayName })
    }

    @Test fun disclosureNamesPriceTrialRenewalAndWhereToCancel() {
        Locale.setDefault(Locale.US)
        val trial = disclosure(yearly, "7-day free trial")
        assertTrue(trial.startsWith("7-Day Free Trial, then $14.99 / year."))
        assertTrue("Auto-renews" in trial && "Google Play" in trial && "cancel" in trial)
        assertTrue(disclosure(monthly, null).startsWith("$2.99 / month. Auto-renews"))
        assertEquals("$29.99. One-time purchase. Lifetime access, no subscription.", disclosure(lifetime, null))
    }

    @Test fun reviewAccessOnlyAcceptsTheCodeWhoseDigestShips() {
        val code = "QSY-TEST-CODE"
        val digest = MessageDigest.getInstance("SHA-256").digest(code.toByteArray()).joinToString("") { "%02x".format(it) }
        val defaults = InMemoryStore()
        val access = ReviewAccess(defaults, digest)
        assertFalse(access.isGranted)
        assertFalse(access.activate("wrong"))
        assertFalse(access.isGranted)
        assertTrue(access.activate("  $code "))
        assertTrue(ReviewAccess(defaults, digest).isGranted)
        // A build without a digest (debug without local.properties) can never grant it.
        assertFalse(ReviewAccess(InMemoryStore(), "").activate(code))
    }

    @Test fun specDescriptionReadsLikeIos() {
        assertEquals("Single tap, soft, every 2.4s", specDescription(PulseSpec.forLevel(1)))
        assertEquals("3-tap burst, strong, every 0.5s", specDescription(PulseSpec.forLevel(10)))
    }

    // Reminders

    @Test fun remindersFireAtTheNextOfEightTwoAndEight() {
        val morning = ZonedDateTime.of(2026, 10, 20, 7, 30, 0, 0, ZoneOffset.UTC)
        assertEquals(morning.withHour(8).withMinute(0), PressReminders.nextTrigger(8, morning))
        val atEight = morning.withHour(8).withMinute(0)
        assertEquals(atEight.plusDays(1), PressReminders.nextTrigger(8, atEight))
        assertEquals(morning.withHour(20).withMinute(0), PressReminders.nextTrigger(20, morning))
        assertEquals(listOf(8, 14, 20), PressReminders.HOURS)
    }

    // Session loop

    private class FakeHaptics(override val isAvailable: Boolean = true) : Haptics {
        val played = mutableListOf<Pair<Waveform, Boolean>>()
        var stops = 0
        override fun play(waveform: Waveform, repeat: Boolean) { played += waveform to repeat }
        override fun stop() { stops++ }
    }

    private class FakeTone : TonePlayer {
        var playing = false
        override fun start() { playing = true }
        override fun stop() { playing = false }
    }

    private class Harness(mode: ReliefMode, seconds: Int) {
        var now: Instant = Instant.ofEpochSecond(1_760_000_000)
        val haptics = FakeHaptics()
        val tone = FakeTone()
        val store = EpisodeStore(MemoryFile())
        val session = SessionController(haptics, tone, store, CoroutineScope(Dispatchers.Unconfined), { now })
        val plan = ReliefPlan.quickStart(mode).copy(cause = NauseaCause.MOTION, severityBefore = 4, intensity = 5)

        init { session.start(plan, seconds) }

        fun advance(seconds: Long) {
            now = now.plusSeconds(seconds)
            session.tick()
        }
    }

    @Test fun pulseRunsItsLevelAndLiveControlRetunesIt() {
        val h = Harness(ReliefMode.PULSE, FreeTier.SESSION_SECONDS)
        assertEquals(HapticPatterns.pulse(PulseSpec.forLevel(5)) to true, h.haptics.played.last())
        h.session.adjustIntensity(+1)
        assertEquals(6, h.session.intensity)
        assertEquals(HapticPatterns.pulse(PulseSpec.forLevel(6)), h.haptics.played.last().first)
        repeat(20) { h.session.adjustIntensity(+1) }
        assertEquals(10, h.session.intensity)
        assertFalse(h.tone.playing)
    }

    @Test fun aFreeSessionEndsAtTheCapAndSavesUnratedThenRated() {
        val h = Harness(ReliefMode.BREATHE, FreeTier.SESSION_SECONDS)
        h.advance(60)
        assertEquals(60, h.session.remainingSeconds)
        h.advance(60)
        assertEquals(SessionController.Phase.RATING, h.session.phase)
        assertEquals(1, h.haptics.stops)
        val saved = h.store.episodes.single()
        assertNull(saved.severityAfter)
        assertEquals("breathe", saved.modeRaw)
        assertEquals(2, saved.plannedMinutes)
        val rated = h.session.complete(2)
        assertEquals(SessionController.Phase.IDLE, h.session.phase)
        assertEquals(2, rated.reliefDelta)
        assertEquals(1, h.store.episodes.size)
        assertEquals(2, h.store.episodes.single().severityAfter)
    }

    @Test fun toneModePlaysTheToneAndNoVibration() {
        val h = Harness(ReliefMode.TONE, 60)
        assertTrue(h.tone.playing)
        assertTrue(h.haptics.played.isEmpty())
        h.advance(60)
        assertFalse(h.tone.playing)
        assertEquals(SessionController.Phase.RATING, h.session.phase)
    }

    @Test fun pressMarksTheStartAndEndOfTheHold() {
        val h = Harness(ReliefMode.PRESS, 180)
        assertEquals(HapticPatterns.marker to false, h.haptics.played.single())
        h.advance(180)
        assertEquals(2, h.haptics.played.size)
        assertEquals(HapticPatterns.marker, h.haptics.played.last().first)
    }

    @Test fun theOptionalToneLayersOverPulseAndBreathe() {
        val h = Harness(ReliefMode.PULSE, 120)
        h.session.updateToneEnabled(true)
        assertTrue(h.tone.playing)
        h.session.updateToneEnabled(false)
        assertFalse(h.tone.playing)
    }

    @Test fun accidentalCancelsAreNotRecordedButRealOnesAre() {
        val quick = Harness(ReliefMode.PULSE, 120)
        quick.advance(20)
        quick.session.cancel()
        assertTrue(quick.store.episodes.isEmpty())
        assertEquals(SessionController.Phase.IDLE, quick.session.phase)

        val real = Harness(ReliefMode.PULSE, 900)
        real.advance(90)
        real.session.cancel()
        assertEquals(1, real.store.episodes.size)
    }

    @Test fun aSecondStartWhileRunningIsIgnored() {
        val h = Harness(ReliefMode.PULSE, 120)
        h.session.start(ReliefPlan.quickStart(ReliefMode.TONE), 60)
        assertEquals(ReliefMode.PULSE, h.session.mode)
    }

    @Test fun waveformArraysCompareByContent() {
        assertArrayEquals(HapticPatterns.marker.timings, longArrayOf(60))
    }
}
