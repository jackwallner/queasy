package com.jackwallner.queasy.model

import java.time.Instant
import java.util.UUID

enum class EpisodeSource(val raw: String) {
    WATCH("watch"),
    PHONE("phone");

    companion object {
        fun from(raw: String?): EpisodeSource = entries.firstOrNull { it.raw == raw } ?: PHONE
    }
}

/** One relief session: check-in severity going in, how the user felt coming out. */
data class ReliefEpisode(
    /** Stable across rewrites so an update replaces rather than duplicates. */
    val uuid: String = UUID.randomUUID().toString(),
    val startedAt: Instant,
    val endedAt: Instant? = null,
    val causeRaw: String,
    val severityBefore: Int,
    val severityAfter: Int? = null,
    val intensity: Int,
    val plannedMinutes: Int,
    val sourceRaw: String = EpisodeSource.PHONE.raw,
    /** Null on episodes written before the four-mode rebuild; those were all Pulse. */
    val modeRaw: String? = ReliefMode.PULSE.raw,
) {
    val cause: NauseaCause get() = NauseaCause.from(causeRaw) ?: NauseaCause.GENERAL
    val source: EpisodeSource get() = EpisodeSource.from(sourceRaw)
    val mode: ReliefMode get() = ReliefMode.from(modeRaw) ?: ReliefMode.PULSE

    /** Positive when the user felt better after the session. */
    val reliefDelta: Int? get() = severityAfter?.let { severityBefore - it }

    val actualMinutes: Int
        get() {
            val end = endedAt ?: return 0
            return maxOf(0, ((end.toEpochMilli() - startedAt.toEpochMilli()) / 60_000).toInt())
        }

    fun toEntry() = EpisodeStats.Entry(startedAt, cause, mode, severityBefore, severityAfter)
}
