package com.jackwallner.queasy.model

/**
 * Pure check-in to plan mapping, the product's "algorithm". Deterministic and
 * unit-tested, no side effects. Ports `Shared/Services/PatternEngine.swift`.
 */
object PatternEngine {
    const val MIN_INTENSITY = 1
    const val MAX_INTENSITY = 10
    const val MIN_DURATION = 10
    const val MAX_DURATION = 45

    /** Morning sickness sessions start gentler and run longer. */
    const val MORNING_SICKNESS_INTENSITY_CAP = 6

    fun recommend(checkIn: CheckIn): ReliefPlan {
        val severity = checkIn.severity.coerceIn(1, 5)

        var intensity = severity * 2
        if (checkIn.stillExposed) intensity += 1
        // Full stomach: start one level gentler, ramp up manually if needed.
        if (checkIn.recentlyAte) intensity -= 1
        intensity = intensity.coerceIn(MIN_INTENSITY, MAX_INTENSITY)
        if (checkIn.cause == NauseaCause.MORNING_SICKNESS) {
            intensity = minOf(intensity, MORNING_SICKNESS_INTENSITY_CAP)
        }

        var duration = 8 + severity * 3
        if (checkIn.cause == NauseaCause.HANGOVER) duration += 5
        if (checkIn.cause == NauseaCause.MORNING_SICKNESS) duration += 5
        duration = duration.coerceIn(MIN_DURATION, MAX_DURATION)

        return ReliefPlan(
            cause = checkIn.cause,
            mode = checkIn.mode ?: suggestedModes(checkIn.cause)[0],
            intensity = intensity,
            breathe = breathePattern(severity),
            durationMinutes = duration,
            severityBefore = severity,
            tips = tips(checkIn),
        )
    }

    /**
     * The modes worth offering for an occasion, best first: the one with the
     * most directly relevant published work, not the one most likely to help.
     */
    fun suggestedModes(cause: NauseaCause): List<ReliefMode> = when (cause) {
        // The 100 Hz work was done on motion sickness specifically.
        NauseaCause.MOTION -> listOf(ReliefMode.TONE, ReliefMode.BREATHE, ReliefMode.PULSE, ReliefMode.PRESS)
        // The wristband trials, including the pregnancy ones, tested pressure.
        NauseaCause.MORNING_SICKNESS -> listOf(ReliefMode.PRESS, ReliefMode.BREATHE, ReliefMode.PULSE, ReliefMode.TONE)
        NauseaCause.VERTIGO -> listOf(ReliefMode.BREATHE, ReliefMode.TONE, ReliefMode.PULSE, ReliefMode.PRESS)
        NauseaCause.HANGOVER, NauseaCause.ANXIETY, NauseaCause.GENERAL ->
            listOf(ReliefMode.BREATHE, ReliefMode.PULSE, ReliefMode.PRESS, ReliefMode.TONE)
    }

    /** Worse waves get a longer exhale, the only dial paced breathing really has. */
    fun breathePattern(severity: Int): BreathePattern = when {
        severity <= 2 -> BreathePattern.GENTLE
        severity <= 4 -> BreathePattern.RELAXED
        else -> BreathePattern.SLOWER
    }

    fun tips(checkIn: CheckIn): List<String> {
        val tips = when (checkIn.cause) {
            NauseaCause.MOTION -> mutableListOf(
                "Look at the horizon or a stable point far away.",
                "Crack a window. Cool moving air helps.",
                "Skip reading or scrolling until the wave passes.",
            )
            NauseaCause.MORNING_SICKNESS -> mutableListOf(
                "An empty stomach is the usual trigger. Small and often beats three meals.",
                "Plain crackers before you sit up in the morning, if you can face them.",
                "Cold food carries less smell than hot food.",
                "Sip fluids between meals rather than with them.",
            )
            NauseaCause.HANGOVER -> mutableListOf(
                "Rehydrate slowly, small sips beat big gulps.",
                "Bland carbs (toast, crackers) settle faster than grease.",
                "Dim screens and bright lights while the session runs.",
            )
            NauseaCause.VERTIGO -> mutableListOf(
                "Sit down and fix your eyes on one still object.",
                "Move your head slowly, no quick turns.",
            )
            NauseaCause.ANXIETY -> mutableListOf(
                "Breathe out longer than you breathe in: 4 in, 6 out.",
                "Drop your shoulders and unclench your jaw.",
                "Match your exhale to the pulse rhythm.",
            )
            NauseaCause.GENERAL -> mutableListOf(
                "Slow, steady breaths through your nose.",
                "Cool air and loose clothing help more than you'd think.",
                "Small sips of water, and avoid strong smells.",
            )
        }
        if (checkIn.stillExposed && checkIn.cause == NauseaCause.MOTION) {
            tips.add(0, "If you're a passenger, face forward and sit up front if you can.")
        }
        return tips
    }
}
