package com.jackwallner.queasy

import com.jackwallner.queasy.data.PlanCodec
import com.jackwallner.queasy.model.BreathPhase
import com.jackwallner.queasy.model.BreathePattern
import com.jackwallner.queasy.model.CheckIn
import com.jackwallner.queasy.model.FreeTier
import com.jackwallner.queasy.model.NauseaCause
import com.jackwallner.queasy.model.PatternEngine
import com.jackwallner.queasy.model.PressProtocol
import com.jackwallner.queasy.model.ProFeature
import com.jackwallner.queasy.model.PulseSpec
import com.jackwallner.queasy.model.ReliefMode
import com.jackwallner.queasy.model.ReliefPlan
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** `PatternEngineTests.swift` and the Modes, Free tier and Breathing pacer suites of `ModeAndFreeTierTests.swift`. */
class EngineTest {
    private fun checkIn(
        cause: NauseaCause = NauseaCause.MOTION,
        severity: Int = 3,
        stillExposed: Boolean = false,
        recentlyAte: Boolean = false,
        mode: ReliefMode? = null,
    ) = CheckIn(cause, severity, stillExposed, recentlyAte, mode)

    @Test fun intensityScalesWithSeverity() {
        var previous = 0
        for (severity in 1..5) {
            val plan = PatternEngine.recommend(checkIn(severity = severity))
            assertTrue(plan.intensity >= previous)
            previous = plan.intensity
        }
        assertEquals(2, PatternEngine.recommend(checkIn(severity = 1)).intensity)
        assertEquals(10, PatternEngine.recommend(checkIn(severity = 5)).intensity)
    }

    @Test fun stillExposedAddsOneLevel() {
        val calm = PatternEngine.recommend(checkIn(severity = 3))
        val exposed = PatternEngine.recommend(checkIn(severity = 3, stillExposed = true))
        assertEquals(calm.intensity + 1, exposed.intensity)
    }

    @Test fun worstCaseClampsToMaxIntensity() {
        val plan = PatternEngine.recommend(checkIn(NauseaCause.HANGOVER, 5, stillExposed = true))
        assertEquals(PatternEngine.MAX_INTENSITY, plan.intensity)
    }

    @Test fun recentMealSoftensStart() {
        val empty = PatternEngine.recommend(checkIn(severity = 3))
        val full = PatternEngine.recommend(checkIn(severity = 3, recentlyAte = true))
        assertEquals(empty.intensity - 1, full.intensity)
    }

    @Test fun intensityStaysInBounds() {
        for (severity in listOf(-3, 0, 1, 5, 9)) for (exposed in listOf(true, false)) for (ate in listOf(true, false)) {
            for (cause in NauseaCause.entries) {
                val plan = PatternEngine.recommend(checkIn(cause, severity, exposed, ate))
                assertTrue(plan.intensity in PatternEngine.MIN_INTENSITY..PatternEngine.MAX_INTENSITY)
                assertTrue(plan.durationMinutes in PatternEngine.MIN_DURATION..PatternEngine.MAX_DURATION)
            }
        }
    }

    @Test fun hangoverRunsLonger() {
        val base = PatternEngine.recommend(checkIn(NauseaCause.MOTION, 3)).durationMinutes
        val hangover = PatternEngine.recommend(checkIn(NauseaCause.HANGOVER, 3)).durationMinutes
        assertEquals(base + 5, hangover)
    }

    @Test fun everyCauseHasTips() {
        NauseaCause.entries.forEach { assertTrue(PatternEngine.recommend(checkIn(it, 3)).tips.isNotEmpty()) }
    }

    @Test fun pulseTableHasTenMonotonicLevels() {
        assertEquals(10, PulseSpec.levels.size)
        PulseSpec.levels.zipWithNext().forEach { (a, b) ->
            assertTrue(a.interval >= b.interval)
            assertTrue(a.burstCount <= b.burstCount)
        }
    }

    @Test fun specLevelClamps() {
        assertEquals(PulseSpec.levels[0], PulseSpec.forLevel(0))
        assertEquals(PulseSpec.levels[9], PulseSpec.forLevel(99))
        assertEquals(PulseSpec.levels[3], PulseSpec.forLevel(4))
    }

    @Test fun planRoundTripsThroughJSON() {
        val plan = PatternEngine.recommend(checkIn(NauseaCause.VERTIGO, 4, stillExposed = true))
        assertEquals(plan, PlanCodec.decode(PlanCodec.encode(plan)))
    }

    @Test fun everyCauseSuggestsEveryMode() {
        for (cause in NauseaCause.entries) {
            val modes = PatternEngine.suggestedModes(cause)
            assertEquals(ReliefMode.entries.toSet(), modes.toSet())
            assertEquals(ReliefMode.entries.size, modes.size)
        }
    }

    @Test fun firstSuggestionMatchesTheLiterature() {
        assertEquals(ReliefMode.TONE, PatternEngine.suggestedModes(NauseaCause.MOTION).first())
        assertEquals(ReliefMode.PRESS, PatternEngine.suggestedModes(NauseaCause.MORNING_SICKNESS).first())
        assertEquals(ReliefMode.BREATHE, PatternEngine.suggestedModes(NauseaCause.ANXIETY).first())
    }

    @Test fun planTakesTheCheckInsModeWhenSet() {
        assertEquals(ReliefMode.BREATHE, PatternEngine.recommend(checkIn(NauseaCause.MOTION, mode = ReliefMode.BREATHE)).mode)
    }

    @Test fun planFallsBackToTheSuggestedMode() {
        assertEquals(ReliefMode.TONE, PatternEngine.recommend(checkIn(NauseaCause.MOTION)).mode)
    }

    @Test fun morningSicknessStartsGentlerAndRunsLonger() {
        val worst = PatternEngine.recommend(checkIn(NauseaCause.MORNING_SICKNESS, 5, stillExposed = true))
        assertTrue(worst.intensity <= PatternEngine.MORNING_SICKNESS_INTENSITY_CAP)
        val general = PatternEngine.recommend(checkIn(NauseaCause.GENERAL, 3))
        val morning = PatternEngine.recommend(checkIn(NauseaCause.MORNING_SICKNESS, 3))
        assertTrue(morning.durationMinutes > general.durationMinutes)
    }

    @Test fun morningSicknessCarriesAProviderNote() {
        assertNotNull(NauseaCause.MORNING_SICKNESS.safetyNote)
        assertNull(NauseaCause.MOTION.safetyNote)
    }

    @Test fun worseWavesGetALongerExhale() {
        assertTrue(PatternEngine.breathePattern(5).exhaleSeconds > PatternEngine.breathePattern(1).exhaleSeconds)
        BreathePattern.ALL.forEach { assertTrue(it.exhaleSeconds > it.inhaleSeconds) }
    }

    @Test fun toneIsTheOnlyModeThatNeedsHeadphones() {
        assertEquals(listOf(ReliefMode.TONE), ReliefMode.entries.filter { it.needsHeadphones })
    }

    /** Pulse is the one mode with no citation: there is no trial of a buzz at P6. */
    @Test fun onlyPulseIsUncited() {
        ReliefMode.entries.filter { it != ReliefMode.PULSE }.forEach {
            assertNotNull(it.evidenceNote)
            assertNotNull(it.sourceUrl)
        }
        assertNull(ReliefMode.PULSE.evidenceNote)
        assertNull(ReliefMode.PULSE.sourceUrl)
    }

    /** Plans written by 1.0.1, or another old build, have no `mode` or `breathe` key. */
    @Test fun legacyPlansStillDecode() {
        val plan = PlanCodec.decode("""{"cause":"motion","intensity":7,"durationMinutes":20,"severityBefore":4,"tips":["a"]}""")!!
        assertEquals(ReliefMode.PULSE, plan.mode)
        assertEquals(BreathePattern.RELAXED, plan.breathe)
        assertEquals(7, plan.intensity)
        assertEquals(NauseaCause.MOTION, plan.cause)
    }

    /** A plan in Swift's `JSONEncoder` shape, as iOS stores it under `lastPlanJSON`. */
    @Test fun swiftEncodedPlansDecode() {
        val swift = """{"breathe":{"exhaleSeconds":8,"inhaleSeconds":4},"cause":"morningSickness","durationMinutes":22,"intensity":4,"mode":"breathe","severityBefore":3,"tips":[]}"""
        assertEquals(
            ReliefPlan(NauseaCause.MORNING_SICKNESS, ReliefMode.BREATHE, 4, BreathePattern.SLOWER, 22, 3, emptyList()),
            PlanCodec.decode(swift),
        )
        assertNull(PlanCodec.decode("""{"cause":"martian","intensity":1,"durationMinutes":1,"severityBefore":1}"""))
        assertNull(PlanCodec.decode("not json"))
    }

    @Test fun planRoundTripsWithItsMode() {
        val plan = ReliefPlan(NauseaCause.MORNING_SICKNESS, ReliefMode.BREATHE, 4, BreathePattern.SLOWER, 22, 3, emptyList())
        assertEquals(plan, PlanCodec.decode(PlanCodec.encode(plan)))
    }

    @Test fun freeCapsTheModesWhoseLengthIsChosen() {
        for (mode in listOf(ReliefMode.PULSE, ReliefMode.BREATHE)) {
            assertEquals(FreeTier.SESSION_SECONDS, FreeTier.cappedSeconds(mode, 45 * 60, isPro = false))
            assertTrue(FreeTier.isCapped(mode, 45 * 60, isPro = false))
        }
    }

    @Test fun fixedProtocolModesAreNeverShortened() {
        assertEquals(60, FreeTier.cappedSeconds(ReliefMode.TONE, 60, isPro = false))
        assertEquals(PressProtocol.HOLD_SECONDS, FreeTier.cappedSeconds(ReliefMode.PRESS, PressProtocol.HOLD_SECONDS, isPro = false))
        assertFalse(FreeTier.isCapped(ReliefMode.PRESS, PressProtocol.HOLD_SECONDS, isPro = false))
    }

    @Test fun proIsNeverCapped() {
        ReliefMode.entries.forEach {
            assertEquals(45 * 60, FreeTier.cappedSeconds(it, 45 * 60, isPro = true))
            assertFalse(FreeTier.isCapped(it, 45 * 60, isPro = true))
        }
    }

    @Test fun aShortSessionIsNotCappedEvenWhenFree() {
        assertEquals(60, FreeTier.cappedSeconds(ReliefMode.PULSE, 60, isPro = false))
        assertFalse(FreeTier.isCapped(ReliefMode.PULSE, 60, isPro = false))
    }

    @Test fun everyProFeatureHasCopy() {
        ProFeature.entries.forEach {
            assertTrue(it.title.isNotEmpty())
            assertTrue(it.detail.isNotEmpty())
        }
    }

    @Test fun breathPhaseFollowsTheCycle() {
        val pattern = BreathePattern.RELAXED // 4 in, 6 out
        val start = BreathPhase.at(0, pattern)
        assertTrue(start.isInhale)
        assertEquals(0f, start.progress, 0f)
        val midInhale = BreathPhase.at(2_000, pattern)
        assertTrue(midInhale.isInhale)
        assertEquals(0.5f, midInhale.progress, 0.001f)
        assertFalse(BreathPhase.at(7_000, pattern).isInhale)
        val nextCycle = BreathPhase.at(10_000, pattern)
        assertTrue(nextCycle.isInhale)
        assertEquals(0f, nextCycle.progress, 0.001f)
        assertEquals(4, start.secondsLeft)
        assertEquals(0.42f, start.scale, 0.001f)
        assertEquals(0.92f, BreathPhase.at(3_999, pattern).scale, 0.01f)
    }

    @Test fun breathPhaseSurvivesAClockThatRunsBackwards() {
        val phase = BreathPhase.at(-30_000, BreathePattern.RELAXED)
        assertTrue(phase.isInhale)
        assertTrue(phase.progress >= 0)
    }
}
