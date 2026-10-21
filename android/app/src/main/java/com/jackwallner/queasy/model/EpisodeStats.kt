package com.jackwallner.queasy.model

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** Pure aggregation over episodes for the History header. Ports `EpisodeStats.swift`. */
object EpisodeStats {
    data class Summary(
        val totalSessions: Int,
        val sessionsThisWeek: Int,
        /** Mean of (before - after) across rated episodes; null when none rated. */
        val averageReliefDelta: Double?,
        /** Cause with the best average relief delta (min 2 rated episodes). */
        val bestCause: NauseaCause?,
        /** Mode the user tends to come out of feeling better (min 2 rated). */
        val bestMode: ReliefMode?,
    )

    data class Entry(
        val startedAt: Instant,
        val cause: NauseaCause,
        val mode: ReliefMode = ReliefMode.PULSE,
        val severityBefore: Int,
        val severityAfter: Int?,
    )

    fun summarize(entries: List<Entry>, now: Instant = Instant.now(), zone: ZoneId = ZoneId.systemDefault()): Summary {
        val weekStart = now.atZone(zone).toLocalDate().minusDays(6).atStartOfDay(zone).toInstant()
        val thisWeek = entries.count { !it.startedAt.isBefore(weekStart) }

        val rated = entries.mapNotNull { e -> e.severityAfter?.let { Triple(e.cause, e.mode, e.severityBefore - it) } }
        val avg = if (rated.isEmpty()) null else rated.sumOf { it.third }.toDouble() / rated.size

        return Summary(
            totalSessions = entries.size,
            sessionsThisWeek = thisWeek,
            averageReliefDelta = avg,
            bestCause = best(rated.groupBy({ it.first }, { it.third })),
            bestMode = best(rated.groupBy({ it.second }, { it.third })),
        )
    }

    /** The key with the highest mean delta among keys with at least two rated sessions. */
    private fun <K> best(groups: Map<K, List<Int>>): K? = groups
        .filterValues { it.size >= 2 }
        .maxByOrNull { (_, deltas) -> deltas.sum().toDouble() / deltas.size }
        ?.key

    /** One cell per calendar day in the lookback window. */
    data class HeatmapDay(
        val date: LocalDate,
        val count: Int,
        /** Worst check-in severity that day (1-5); null on calm days. */
        val peakSeverity: Int?,
    )

    /**
     * The day grid for the last [days] days, starting no earlier than the first
     * logged episode (earlier days would imply data we don't have).
     */
    fun heatmap(
        entries: List<Entry>,
        days: Int = 90,
        endingAt: Instant = Instant.now(),
        zone: ZoneId = ZoneId.systemDefault(),
    ): List<HeatmapDay> {
        val today = endingAt.atZone(zone).toLocalDate()
        val windowStart = today.minusDays((days - 1).toLong())
        val firstEpisode = entries.minOfOrNull { it.startedAt } ?: return emptyList()
        val firstDay = firstEpisode.atZone(zone).toLocalDate()
        val start = maxOf(windowStart, minOf(firstDay, today))

        val byDay = mutableMapOf<LocalDate, Pair<Int, Int>>()
        for (entry in entries) {
            val day = entry.startedAt.atZone(zone).toLocalDate()
            if (day.isBefore(start) || day.isAfter(today)) continue
            val (count, peak) = byDay[day] ?: (0 to 0)
            byDay[day] = (count + 1) to maxOf(peak, entry.severityBefore)
        }

        val out = mutableListOf<HeatmapDay>()
        var cursor = start
        while (!cursor.isAfter(today)) {
            val cell = byDay[cursor]
            out += HeatmapDay(cursor, cell?.first ?: 0, cell?.second)
            cursor = cursor.plusDays(1)
        }
        return out
    }
}
