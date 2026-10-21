package com.jackwallner.queasy.model

import kotlin.math.ceil

/**
 * Where a breath is at a moment in time, driven by wall-clock time so the ring
 * and the vibration agree. Ports `BreathingBloom.phase(at:anchor:pattern:)`.
 */
data class BreathPhase(
    val isInhale: Boolean,
    /** 0…1 through the current half of the cycle. */
    val progress: Float,
    val secondsLeft: Int,
) {
    /** 0.42 at rest, 0.92 at the top of the in-breath, eased both ways. */
    val scale: Float
        get() {
            val eased = progress * progress * (3 - 2 * progress)
            val openness = if (isInhale) eased else 1 - eased
            return 0.42f + 0.5f * openness
        }

    companion object {
        fun at(elapsedMillis: Long, pattern: BreathePattern): BreathPhase {
            val elapsed = maxOf(elapsedMillis, 0L) / 1000.0
            val into = elapsed % pattern.cycleSeconds
            if (into < pattern.inhaleSeconds) {
                return BreathPhase(
                    isInhale = true,
                    progress = (into / pattern.inhaleSeconds).toFloat(),
                    secondsLeft = ceil(pattern.inhaleSeconds - into).toInt(),
                )
            }
            val out = into - pattern.inhaleSeconds
            return BreathPhase(
                isInhale = false,
                progress = (out / pattern.exhaleSeconds).toFloat(),
                secondsLeft = ceil(pattern.exhaleSeconds - out).toInt(),
            )
        }
    }
}
