package com.jackwallner.queasy.model

import kotlin.math.max
import kotlin.math.min

/** The occasion, not a diagnosis. Drives intensity caps, duration, and tips. */
enum class NauseaCause(val raw: String) {
    MOTION("motion"),
    MORNING_SICKNESS("morningSickness"),
    HANGOVER("hangover"),
    VERTIGO("vertigo"),
    ANXIETY("anxiety"),
    GENERAL("general");

    val label: String
        get() = when (this) {
            MOTION -> "Motion sickness"
            MORNING_SICKNESS -> "Morning sickness"
            HANGOVER -> "Hangover"
            VERTIGO -> "Vertigo / dizziness"
            ANXIETY -> "Nervous stomach"
            GENERAL -> "Illness / other"
        }

    val shortLabel: String
        get() = when (this) {
            MOTION -> "Motion"
            MORNING_SICKNESS -> "Morning"
            HANGOVER -> "Hangover"
            VERTIGO -> "Vertigo"
            ANXIETY -> "Nerves"
            GENERAL -> "Other"
        }

    /** Shown when there is a reason to involve a clinician. Not conditional on anything measured. */
    val safetyNote: String?
        get() = when (this) {
            MORNING_SICKNESS -> "If you cannot keep fluids down for a day, are losing weight, or feel faint, call your midwife or doctor. Sickness in pregnancy can get serious and there is treatment for it."
            VERTIGO -> "New, severe or one-sided spinning is worth a doctor's opinion rather than an app's."
            else -> null
        }

    companion object {
        fun from(raw: String?): NauseaCause? = entries.firstOrNull { it.raw == raw }
    }
}

/** The three-question symptom check-in. */
data class CheckIn(
    val cause: NauseaCause,
    /** 1 (barely) … 5 (about to be sick). */
    val severity: Int,
    val stillExposed: Boolean,
    /** Ate within the last hour: start gentler on a full stomach. */
    val recentlyAte: Boolean,
    /** Set once the user picks a mode; null means whatever the engine suggests. */
    val mode: ReliefMode? = null,
)

enum class PulseStrength(val raw: String) {
    SOFT("soft"),
    MEDIUM("medium"),
    STRONG("strong");

    companion object {
        fun from(raw: String?): PulseStrength? = entries.firstOrNull { it.raw == raw }
    }
}

/** The after-session rating, shared so every surface maps a feeling to the same after-severity. */
enum class ReliefFeeling(val raw: String) {
    BETTER("better"),
    SAME("same"),
    WORSE("worse");

    fun severityAfter(before: Int): Int = when (this) {
        BETTER -> max(before - 2, 1)
        SAME -> before
        WORSE -> min(before + 1, 5)
    }
}

/**
 * One period of the vibration pattern: play [burstCount] taps of [strength],
 * then wait so consecutive periods start [interval] seconds apart.
 */
data class PulseSpec(val interval: Double, val burstCount: Int, val strength: PulseStrength) {
    companion object {
        /** Gap between taps inside a burst. */
        const val INTRA_BURST_GAP = 0.14

        /** The 10-level intensity table, indexed by `level - 1`. */
        val levels: List<PulseSpec> = listOf(
            PulseSpec(2.4, 1, PulseStrength.SOFT),
            PulseSpec(2.0, 1, PulseStrength.SOFT),
            PulseSpec(1.8, 1, PulseStrength.MEDIUM),
            PulseSpec(1.5, 1, PulseStrength.MEDIUM),
            PulseSpec(1.3, 2, PulseStrength.MEDIUM),
            PulseSpec(1.1, 2, PulseStrength.MEDIUM),
            PulseSpec(0.9, 2, PulseStrength.STRONG),
            PulseSpec(0.75, 3, PulseStrength.STRONG),
            PulseSpec(0.6, 3, PulseStrength.STRONG),
            PulseSpec(0.5, 3, PulseStrength.STRONG),
        )

        fun forLevel(level: Int): PulseSpec = levels[level.coerceIn(1, levels.size) - 1]
    }
}

/** The engine's output: what to run and for how long. */
data class ReliefPlan(
    val cause: NauseaCause,
    val mode: ReliefMode = ReliefMode.PULSE,
    /** 1…10, indexes into `PulseSpec.levels`. Only meaningful for Pulse. */
    val intensity: Int,
    /** Only meaningful for Breathe. */
    val breathe: BreathePattern = BreathePattern.RELAXED,
    val durationMinutes: Int,
    val severityBefore: Int,
    val tips: List<String>,
) {
    val spec: PulseSpec get() = PulseSpec.forLevel(intensity)

    companion object {
        /** Default plan for quick-start when no check-in was run. */
        val QUICK_START = ReliefPlan(
            cause = NauseaCause.GENERAL,
            mode = ReliefMode.PULSE,
            intensity = 5,
            durationMinutes = 15,
            severityBefore = 3,
            tips = emptyList(),
        )

        /** The free-tier default for a mode: no check-in, no tailoring, just go. */
        fun quickStart(mode: ReliefMode) = ReliefPlan(
            cause = NauseaCause.GENERAL,
            mode = mode,
            intensity = 5,
            durationMinutes = if (mode == ReliefMode.PRESS) PressProtocol.HOLD_SECONDS / 60 else 15,
            severityBefore = 3,
            tips = emptyList(),
        )
    }
}
