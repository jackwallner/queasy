package com.jackwallner.queasy.model

import kotlin.math.roundToInt
import kotlin.math.roundToLong

/**
 * One loop of vibration, as Android's waveform takes it: segment lengths in
 * milliseconds and an amplitude (0 off, 1…255 on) for each. Pure, so the
 * cadence can be checked on the JVM against the iOS Core Haptics patterns in
 * `PhoneSessionController.swift`.
 */
data class Waveform(val timings: LongArray, val amplitudes: IntArray) {
    val totalMillis: Long get() = timings.sum()

    override fun equals(other: Any?) =
        other is Waveform && timings.contentEquals(other.timings) && amplitudes.contentEquals(other.amplitudes)

    override fun hashCode() = 31 * timings.contentHashCode() + amplitudes.contentHashCode()
}

object HapticPatterns {
    /** A tap's length. Strength also lengthens it, so motors without amplitude control still read soft from strong. */
    fun tapMillis(strength: PulseStrength): Long = when (strength) {
        PulseStrength.SOFT -> 28
        PulseStrength.MEDIUM -> 40
        PulseStrength.STRONG -> 55
    }

    /** iOS intensities 0.5 / 0.75 / 1.0 on Android's 1…255 scale. */
    fun amplitude(strength: PulseStrength): Int = when (strength) {
        PulseStrength.SOFT -> 128
        PulseStrength.MEDIUM -> 191
        PulseStrength.STRONG -> 255
    }

    /** One period of the spec: [PulseSpec.burstCount] taps, then silence until the interval has elapsed. */
    fun pulse(spec: PulseSpec): Waveform {
        val tap = tapMillis(spec.strength)
        val gap = (PulseSpec.INTRA_BURST_GAP * 1000).roundToLong() - tap
        val timings = mutableListOf<Long>()
        val amplitudes = mutableListOf<Int>()
        repeat(spec.burstCount) { i ->
            timings += tap
            amplitudes += amplitude(spec.strength)
            if (i < spec.burstCount - 1) {
                timings += gap
                amplitudes += 0
            }
        }
        val rest = (spec.interval * 1000).roundToLong() - timings.sum()
        if (rest > 0) {
            timings += rest
            amplitudes += 0
        }
        return Waveform(timings.toLongArray(), amplitudes.toIntArray())
    }

    /** Length of each ramp step in the breathing swell. */
    const val BREATH_STEP_MILLIS = 100L

    /**
     * One breath for motors with amplitude control: a swell rising through the
     * in-breath (iOS curve 0.10 to 0.62), a small click at the turn, and a longer
     * fall through the out-breath (0.50 to 0.04).
     */
    fun breath(pattern: BreathePattern): Waveform {
        val timings = mutableListOf<Long>()
        val amplitudes = mutableListOf<Int>()
        ramp(pattern.inhaleSeconds, 0.10, 0.62, timings, amplitudes)
        timings += 30
        amplitudes += (0.65 * 255).roundToInt()
        ramp(pattern.exhaleSeconds, 0.50, 0.04, timings, amplitudes, trimMillis = 30)
        return Waveform(timings.toLongArray(), amplitudes.toIntArray())
    }

    /**
     * The same breath for on/off motors, which cannot swell: one long tap to
     * start the in-breath and two short ones to start the out-breath.
     */
    fun breathOnOff(pattern: BreathePattern): Waveform {
        val inhale = (pattern.inhaleSeconds * 1000).roundToLong()
        val exhale = (pattern.exhaleSeconds * 1000).roundToLong()
        return Waveform(
            longArrayOf(160, inhale - 160, 40, 90, 40, exhale - 170),
            intArrayOf(255, 0, 255, 0, 255, 0),
        )
    }

    /** The marker at the start and end of a Press hold. */
    val marker = Waveform(longArrayOf(60), intArrayOf(204))

    private fun ramp(
        seconds: Double,
        from: Double,
        to: Double,
        timings: MutableList<Long>,
        amplitudes: MutableList<Int>,
        trimMillis: Long = 0,
    ) {
        val total = (seconds * 1000).roundToLong() - trimMillis
        val steps = (total / BREATH_STEP_MILLIS).toInt().coerceAtLeast(1)
        for (i in 0 until steps) {
            val t = if (steps == 1) 0.0 else i.toDouble() / (steps - 1)
            val level = from + (to - from) * t
            timings += if (i == steps - 1) total - BREATH_STEP_MILLIS * (steps - 1) else BREATH_STEP_MILLIS
            amplitudes += (level * 255).roundToInt().coerceIn(1, 255)
        }
    }
}
