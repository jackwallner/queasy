package com.jackwallner.queasy.model

/**
 * What Queasy does without Pro. Every mode works, forever, unlimited times.
 * Pro buys length, tailoring and memory. Ports `Shared/Services/FreeTier.swift`.
 */
object FreeTier {
    /** Free Pulse and Breathe sessions run this long. */
    const val SESSION_SECONDS = 120

    /** Free history goes back this far. */
    const val HISTORY_DAYS = 7

    const val SESSION_MINUTES_LABEL = "2-minute"

    /** Fixed-protocol modes (Tone's minute, Press's three) are never shortened. */
    fun cappedSeconds(mode: ReliefMode, requested: Int, isPro: Boolean): Int {
        if (isPro || !mode.hasVariableDuration) return requested
        return minOf(requested, SESSION_SECONDS)
    }

    fun isCapped(mode: ReliefMode, requested: Int, isPro: Boolean): Boolean =
        cappedSeconds(mode, requested, isPro) < requested
}

/**
 * What Pro unlocks, in the order it is worth paying for. The paywall reads
 * this list, so the bullets and the gates cannot drift apart. The check-in and
 * live intensity control are deliberately free.
 */
enum class ProFeature {
    FULL_LENGTH_SESSIONS,
    FULL_HISTORY,
    OWN_RHYTHM,
    PRESS_REMINDERS;

    val title: String
        get() = when (this) {
            FULL_LENGTH_SESSIONS -> "Sessions as long as you need"
            FULL_HISTORY -> "Your whole history, and what helps"
            OWN_RHYTHM -> "Pick your own rhythm and level"
            PRESS_REMINDERS -> "Press reminders through the day"
        }

    val detail: String
        get() = when (this) {
            FULL_LENGTH_SESSIONS ->
                "Pulse and Breathe run up to ${PatternEngine.MAX_DURATION} minutes instead of ${FreeTier.SESSION_MINUTES_LABEL} sessions."
            FULL_HISTORY ->
                "Every session kept, not just the last ${FreeTier.HISTORY_DAYS} days, with which mode you tend to come out of feeling better."
            OWN_RHYTHM ->
                "Set the breathing rhythm and the pulse level yourself, and save the one that suits you as your default."
            PRESS_REMINDERS ->
                "A nudge to run a hold a few times a day, the way the wristband trials spaced them."
        }
}
