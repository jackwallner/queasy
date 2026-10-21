package com.jackwallner.queasy.model

import kotlin.math.roundToInt

/**
 * The four things Queasy can do. Each mode is something the user does,
 * described by what it literally is (`docs/positioning.md`). Ports
 * `Shared/Models/ReliefMode.swift`; Android runs every mode on the phone, so
 * the copy that says "your watch" on iOS says "your phone" here.
 */
enum class ReliefMode(val raw: String) {
    PULSE("pulse"),
    BREATHE("breathe"),
    TONE("tone"),
    PRESS("press");

    val title: String
        get() = when (this) {
            PULSE -> "Pulse"
            BREATHE -> "Breathe"
            TONE -> "Tone"
            PRESS -> "Press"
        }

    /** One line, on the card. States what happens, never what it will do to you. */
    val tagline: String
        get() = when (this) {
            PULSE -> "A steady tap on the inside of your wrist"
            BREATHE -> "Slow the breath, paced by a tap you feel"
            TONE -> "A 100 Hz tone through your headphones"
            PRESS -> "Find the spot a band sits on, and hold it"
        }

    /** Two or three lines, on the mode's own screen. */
    val blurb: String
        get() = when (this) {
            PULSE -> "An unhurried, regular tap you can rest your attention on while a wave passes. Nudge the level until it is clear but not annoying."
            BREATHE -> "Your phone taps the rhythm so you can keep your eyes shut: a long swell in, a longer one out. Breathing out for longer than you breathe in is the whole technique."
            TONE -> "A pure 100 Hz tone at a low volume. Headphones, one minute, eyes wherever you like."
            PRESS -> "The inside of the wrist, three finger-widths below the crease, between the two tendons. Press with your thumb, or line up the stud on a band you already own."
        }

    val needsHeadphones: Boolean get() = this == TONE

    /** Pulse and Breathe come out of the vibration motor; Tone and Press do not depend on it. */
    val needsHaptics: Boolean get() = this == PULSE || this == BREATHE

    /**
     * Modes whose length the user (or the check-in) chooses. Tone and Press run
     * a fixed protocol instead, so they are the same length free or paid.
     */
    val hasVariableDuration: Boolean get() = this == PULSE || this == BREATHE

    /** What the mode leans on, in the source's own hedged words. */
    val evidenceNote: String?
        get() = when (this) {
            PULSE -> null
            BREATHE -> "Trials of slow diaphragmatic breathing during chemotherapy and after surgery have reported lower nausea scores. The studies are small."
            TONE -> "A 2025 Nagoya University study is titled \"Just 1-min exposure to a pure tone at 100 Hz with daily exposable sound pressure levels may improve motion sickness\"."
            PRESS -> "Pressure at this spot has been trialled for travel, post-surgery and pregnancy sickness. The Cochrane review of early-pregnancy trials calls the evidence limited and inconsistent."
        }

    val sourceUrl: String?
        get() = when (this) {
            PULSE -> null
            BREATHE -> "https://pubmed.ncbi.nlm.nih.gov/41811802/"
            TONE -> "https://doi.org/10.1265/ehpm.24-00247"
            PRESS -> "https://www.cochranelibrary.com/cdsr/doi/10.1002/14651858.CD007575.pub4/full"
        }

    val startLabel: String
        get() = when (this) {
            PULSE -> "Start the Pulse"
            BREATHE -> "Start Breathing"
            TONE -> "Play the Tone"
            PRESS -> "Start the Hold"
        }

    companion object {
        fun from(raw: String?): ReliefMode? = entries.firstOrNull { it.raw == raw }
    }
}

/** A paced-breathing rhythm. Exhale longer than inhale; that is the technique. */
data class BreathePattern(val inhaleSeconds: Double, val exhaleSeconds: Double) {
    val cycleSeconds: Double get() = inhaleSeconds + exhaleSeconds

    val label: String get() = "${inhaleSeconds.toInt()} in · ${exhaleSeconds.toInt()} out"

    val breathsPerMinute: Int get() = (60.0 / cycleSeconds).roundToInt()

    companion object {
        val RELAXED = BreathePattern(4.0, 6.0)
        val SLOWER = BreathePattern(4.0, 8.0)
        val GENTLE = BreathePattern(3.0, 5.0)

        val ALL: List<BreathePattern> = listOf(GENTLE, RELAXED, SLOWER)
    }
}

/**
 * How Press is dosed: a few minutes of steady pressure, repeated through the
 * day, the way the wristband trials ran it.
 */
object PressProtocol {
    const val HOLD_SECONDS = 180
    const val SUGGESTED_DAILY_HOLDS = 3

    /** Deliberately physical instructions with no claim about what happens once you are there. */
    val steps: List<String> = listOf(
        "Turn one hand palm up.",
        "Lay three fingers of the other hand across the wrist, just below the crease.",
        "The spot is under the edge of your third finger, in the dip between the two tendons.",
        "Press firmly with your thumb, or sit the stud of an acupressure band there.",
        "Do the same on the other wrist if you have a second band.",
    )
}
