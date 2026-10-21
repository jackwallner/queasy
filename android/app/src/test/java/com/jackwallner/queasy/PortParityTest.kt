package com.jackwallner.queasy

import com.jackwallner.queasy.model.BreathePattern
import com.jackwallner.queasy.model.CheckIn
import com.jackwallner.queasy.model.FreeTier
import com.jackwallner.queasy.model.NauseaCause
import com.jackwallner.queasy.model.PatternEngine
import com.jackwallner.queasy.model.PressProtocol
import com.jackwallner.queasy.model.ProFeature
import com.jackwallner.queasy.model.PulseSpec
import com.jackwallner.queasy.model.ReliefFeeling
import com.jackwallner.queasy.model.ReliefMode
import com.jackwallner.queasy.model.ReliefPlan
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Every value the iOS engine computes, exported from the real Swift sources by
 * `scripts/sync-android-parity.sh`, checked against the Kotlin port. Rerun the
 * script whenever `Shared/Models` or `PatternEngine.swift` change.
 */
class PortParityTest {
    private val fixture = JSONObject(javaClass.classLoader!!.getResource("queasy-parity.json")!!.readText())

    private fun JSONArray.objects() = (0 until length()).map { getJSONObject(it) }
    private fun JSONArray.strings() = (0 until length()).map { getString(it) }

    private fun assertPlan(expected: JSONObject, actual: ReliefPlan, context: String) {
        assertEquals(context, expected.getString("cause"), actual.cause.raw)
        assertEquals(context, expected.getString("mode"), actual.mode.raw)
        assertEquals(context, expected.getInt("intensity"), actual.intensity)
        assertEquals(context, expected.getDouble("inhale"), actual.breathe.inhaleSeconds, 0.0)
        assertEquals(context, expected.getDouble("exhale"), actual.breathe.exhaleSeconds, 0.0)
        assertEquals(context, expected.getInt("durationMinutes"), actual.durationMinutes)
        assertEquals(context, expected.getInt("severityBefore"), actual.severityBefore)
        assertEquals(context, expected.getJSONArray("tips").strings(), actual.tips)
    }

    @Test fun everyCheckInProducesTheSwiftPlan() {
        val cases = fixture.getJSONArray("plans").objects()
        assertEquals(6 * 9 * 2 * 2 * 5, cases.size)
        for (case in cases) {
            val input = case.getJSONObject("input")
            val checkIn = CheckIn(
                cause = NauseaCause.from(input.getString("cause"))!!,
                severity = input.getInt("severity"),
                stillExposed = input.getBoolean("stillExposed"),
                recentlyAte = input.getBoolean("recentlyAte"),
                mode = if (input.isNull("mode")) null else ReliefMode.from(input.getString("mode")),
            )
            assertPlan(case.getJSONObject("plan"), PatternEngine.recommend(checkIn), input.toString())
        }
    }

    @Test fun freeTierCapsMatchSwift() {
        val cases = fixture.getJSONArray("caps").objects()
        assertEquals(64, cases.size)
        for (case in cases) {
            val mode = ReliefMode.from(case.getString("mode"))!!
            val requested = case.getInt("requested")
            val isPro = case.getBoolean("isPro")
            assertEquals(case.toString(), case.getInt("seconds"), FreeTier.cappedSeconds(mode, requested, isPro))
            assertEquals(case.toString(), case.getBoolean("capped"), FreeTier.isCapped(mode, requested, isPro))
        }
        assertEquals(fixture.getInt("freeSessionSeconds"), FreeTier.SESSION_SECONDS)
        assertEquals(fixture.getInt("freeHistoryDays"), FreeTier.HISTORY_DAYS)
    }

    @Test fun pulseTableMatchesSwift() {
        val levels = fixture.getJSONArray("pulseLevels").objects()
        assertEquals(levels.size, PulseSpec.levels.size)
        levels.forEachIndexed { i, level ->
            val spec = PulseSpec.levels[i]
            assertEquals(level.getDouble("interval"), spec.interval, 0.0)
            assertEquals(level.getInt("burstCount"), spec.burstCount)
            assertEquals(level.getString("strength"), spec.strength.raw)
        }
        assertEquals(fixture.getDouble("intraBurstGap"), PulseSpec.INTRA_BURST_GAP, 0.0)
    }

    @Test fun breathingPatternsMatchSwift() {
        val patterns = fixture.getJSONArray("breathePatterns").objects()
        assertEquals(patterns.size, BreathePattern.ALL.size)
        patterns.forEachIndexed { i, p ->
            val pattern = BreathePattern.ALL[i]
            assertEquals(p.getDouble("inhale"), pattern.inhaleSeconds, 0.0)
            assertEquals(p.getDouble("exhale"), pattern.exhaleSeconds, 0.0)
            assertEquals(p.getString("label"), pattern.label)
            assertEquals(p.getInt("breathsPerMinute"), pattern.breathsPerMinute)
        }
        for (p in fixture.getJSONArray("breatheForSeverity").objects()) {
            val pattern = PatternEngine.breathePattern(p.getInt("severity"))
            assertEquals(p.getDouble("inhale"), pattern.inhaleSeconds, 0.0)
            assertEquals(p.getDouble("exhale"), pattern.exhaleSeconds, 0.0)
        }
    }

    @Test fun causesMatchSwift() {
        val causes = fixture.getJSONArray("causes").objects()
        assertEquals(causes.map { it.getString("raw") }, NauseaCause.entries.map { it.raw })
        for (c in causes) {
            val cause = NauseaCause.from(c.getString("raw"))!!
            assertEquals(c.getString("label"), cause.label)
            assertEquals(c.getString("shortLabel"), cause.shortLabel)
            assertEquals(if (c.isNull("safetyNote")) null else c.getString("safetyNote"), cause.safetyNote)
            assertEquals(c.getJSONArray("suggestedModes").strings(), PatternEngine.suggestedModes(cause).map { it.raw })
        }
    }

    /**
     * Mode copy matches iOS except where iOS names the Apple Watch: the Breathe
     * tagline and blurb say "phone" on Android, deliberately, because Android
     * has no watch app. Any other drift fails here.
     */
    @Test fun modeCopyMatchesSwiftApartFromTheWatch() {
        val modes = fixture.getJSONArray("modes").objects()
        assertEquals(modes.map { it.getString("raw") }, ReliefMode.entries.map { it.raw })
        for (m in modes) {
            val mode = ReliefMode.from(m.getString("raw"))!!
            assertEquals(m.getString("title"), mode.title)
            assertEquals(if (m.isNull("evidenceNote")) null else m.getString("evidenceNote"), mode.evidenceNote)
            assertEquals(if (m.isNull("sourceURL")) null else m.getString("sourceURL"), mode.sourceUrl)
            assertEquals(m.getBoolean("needsHeadphones"), mode.needsHeadphones)
            assertEquals(m.getBoolean("hasVariableDuration"), mode.hasVariableDuration)
            if (mode == ReliefMode.BREATHE) {
                assertTrue(m.getString("blurb").contains("watch"))
                assertNotEquals(m.getString("blurb"), mode.blurb)
                assertTrue(mode.blurb.startsWith("Your phone taps the rhythm"))
            } else {
                assertEquals(m.getString("tagline"), mode.tagline)
                assertEquals(m.getString("blurb"), mode.blurb)
            }
        }
        ReliefMode.entries.forEach { assertTrue(it.name, "watch" !in it.blurb.lowercase() && "watch" !in it.tagline.lowercase()) }
    }

    @Test fun feelingsMapToTheSameAfterSeverity() {
        val feelings = fixture.getJSONArray("feelings").objects()
        assertEquals(15, feelings.size)
        for (f in feelings) {
            val feeling = ReliefFeeling.entries.first { it.raw == f.getString("feeling") }
            assertEquals(f.getInt("after"), feeling.severityAfter(f.getInt("before")))
        }
    }

    @Test fun pressProtocolMatchesSwift() {
        assertEquals(fixture.getJSONArray("pressSteps").strings(), PressProtocol.steps)
        assertEquals(fixture.getInt("pressHoldSeconds"), PressProtocol.HOLD_SECONDS)
    }

    /** The paywall bullets; the length detail drops iOS's watch-only "screen off" clause. */
    @Test fun proFeaturesMatchSwiftApartFromTheWatch() {
        val features = fixture.getJSONArray("proFeatures").objects()
        assertEquals(features.size, ProFeature.entries.size)
        features.forEachIndexed { i, f ->
            val feature = ProFeature.entries[i]
            assertEquals(f.getString("title"), feature.title)
            if (feature == ProFeature.FULL_LENGTH_SESSIONS) {
                assertTrue(f.getString("detail").startsWith(feature.detail.removeSuffix(".")))
                assertTrue("wrist" !in feature.detail)
            } else {
                assertEquals(f.getString("detail"), feature.detail)
            }
        }
    }

    @Test fun quickStartPlansMatchSwift() {
        assertPlan(fixture.getJSONObject("quickStart"), ReliefPlan.QUICK_START, "quickStart")
        val byMode = fixture.getJSONArray("quickStartByMode").objects()
        ReliefMode.entries.forEachIndexed { i, mode -> assertPlan(byMode[i], ReliefPlan.quickStart(mode), mode.raw) }
    }
}
