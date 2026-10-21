package com.jackwallner.queasy.data

import java.time.Instant

typealias Clock = () -> Instant

/**
 * Rating-ask eligibility, under the iOS keys. On Android the ask is Play's
 * In-App Review card with no question in front of it (Play's review policy and
 * App Review 5.6.1 agree on this).
 */
class ReviewPromptTracker(private val defaults: KeyValueStore, private val clock: Clock = Instant::now) {
    enum class Outcome(val raw: String) { OPENED_WRITE_REVIEW("openedWriteReview"), SUBMITTED_FEEDBACK("submittedFeedback") }

    /** UI tests and screenshot runs never count launches or ask. */
    var isAutomationRun = false

    var appLaunchCount: Int
        get() = maxOf(defaults.getInt(LAUNCH_COUNT), 0)
        set(value) = defaults.putInt(LAUNCH_COUNT, value)

    var lastShown: Instant?
        get() = if (defaults.contains(LAST_SHOWN)) Instant.ofEpochMilli(defaults.getLong(LAST_SHOWN)) else null
        set(value) = if (value == null) defaults.remove(LAST_SHOWN) else defaults.putLong(LAST_SHOWN, value.toEpochMilli())

    var outcome: Outcome?
        get() = defaults.getString(OUTCOME)?.let { raw -> Outcome.entries.firstOrNull { it.raw == raw } }
        set(value) = if (value == null) defaults.remove(OUTCOME) else defaults.putString(OUTCOME, value.raw)

    var hasPendingPositiveMoment: Boolean
        get() = defaults.getBoolean(PENDING)
        set(value) = defaults.putBoolean(PENDING, value)

    fun recordAppLaunch() {
        if (isAutomationRun) return
        appLaunchCount += 1
    }

    fun recordPositiveMoment() {
        if (isAutomationRun) return
        hasPendingPositiveMoment = true
    }

    fun passivePromptAllowed(now: Instant = clock()): Boolean {
        if (outcome == Outcome.OPENED_WRITE_REVIEW) return false
        val last = lastShown ?: return true
        return now.toEpochMilli() - last.toEpochMilli() >= COOLDOWN_DAYS * DAY_MS
    }

    fun canRequestReview(hasCompletedSetup: Boolean, now: Instant = clock()): Boolean {
        if (isAutomationRun || !hasCompletedSetup || !passivePromptAllowed(now)) return false
        return appLaunchCount >= MINIMUM_LAUNCH_COUNT
    }

    fun shouldRequestAfterPositiveMoment(hasCompletedSetup: Boolean, now: Instant = clock()): Boolean =
        hasPendingPositiveMoment && canRequestReview(hasCompletedSetup, now)

    fun markShown(now: Instant = clock()) {
        lastShown = now
        hasPendingPositiveMoment = false
    }

    fun markOpenedWriteReview() {
        outcome = Outcome.OPENED_WRITE_REVIEW
        markShown()
    }

    /** Never overwrites the review-page outcome: feedback must not reopen the asks it ended. */
    fun markFeedbackSubmitted() {
        if (outcome != Outcome.OPENED_WRITE_REVIEW) outcome = Outcome.SUBMITTED_FEEDBACK
    }

    companion object {
        const val MINIMUM_LAUNCH_COUNT = 2
        const val COOLDOWN_DAYS = 30L
        private const val LAUNCH_COUNT = "reviewPrompt.launchCount"
        private const val LAST_SHOWN = "reviewPrompt.lastShownDate"
        private const val OUTCOME = "reviewPrompt.outcome"
        private const val PENDING = "reviewPrompt.pendingPositiveMoment"
    }
}

/**
 * When to offer Pro after a session: only when the session ran into the free
 * ceiling, at a few completed-session milestones, with a cooldown.
 */
class UpgradePromptTracker(private val defaults: KeyValueStore, private val clock: Clock = Instant::now) {
    fun shouldPrompt(isPro: Boolean, sessionWasCapped: Boolean, sessionCount: Int, now: Instant = clock()): Boolean {
        if (isPro || !sessionWasCapped || sessionCount !in MILESTONES) return false
        if (defaults.contains(LAST_PROMPT)) {
            val last = defaults.getLong(LAST_PROMPT)
            if (last > 0 && now.toEpochMilli() - last < COOLDOWN_MS) return false
        }
        return true
    }

    fun recordPrompt(now: Instant = clock()) = defaults.putLong(LAST_PROMPT, now.toEpochMilli())

    companion object {
        val MILESTONES = setOf(3, 8, 20)
        const val COOLDOWN_MS = 5 * DAY_MS
        private const val LAST_PROMPT = "lastUpgradePromptAt"
    }
}

const val DAY_MS = 86_400_000L
