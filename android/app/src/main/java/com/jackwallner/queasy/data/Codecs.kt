package com.jackwallner.queasy.data

import com.jackwallner.queasy.model.BreathePattern
import com.jackwallner.queasy.model.NauseaCause
import com.jackwallner.queasy.model.ReliefEpisode
import com.jackwallner.queasy.model.ReliefMode
import com.jackwallner.queasy.model.ReliefPlan
import java.time.Instant
import org.json.JSONArray
import org.json.JSONObject

/**
 * JSON shapes shared with iOS's `Codable` output, so a plan stored under
 * `lastPlanJSON` reads the same on both platforms. Missing `mode`, `breathe`
 * and `tips` decode to the iOS defaults, exactly as `ReliefPlan.init(from:)`.
 */
object PlanCodec {
    fun encode(plan: ReliefPlan): String = JSONObject().apply {
        put("cause", plan.cause.raw)
        put("mode", plan.mode.raw)
        put("intensity", plan.intensity)
        put("breathe", JSONObject().put("inhaleSeconds", plan.breathe.inhaleSeconds).put("exhaleSeconds", plan.breathe.exhaleSeconds))
        put("durationMinutes", plan.durationMinutes)
        put("severityBefore", plan.severityBefore)
        put("tips", JSONArray(plan.tips))
    }.toString()

    fun decode(json: String): ReliefPlan? = runCatching {
        val o = JSONObject(json)
        val breathe = o.optJSONObject("breathe")?.let {
            BreathePattern(it.getDouble("inhaleSeconds"), it.getDouble("exhaleSeconds"))
        } ?: BreathePattern.RELAXED
        val tips = o.optJSONArray("tips")?.let { a -> List(a.length()) { a.getString(it) } } ?: emptyList()
        ReliefPlan(
            cause = NauseaCause.from(o.getString("cause")) ?: return null,
            mode = ReliefMode.from(o.optString("mode", "")) ?: ReliefMode.PULSE,
            intensity = o.getInt("intensity"),
            breathe = breathe,
            durationMinutes = o.getInt("durationMinutes"),
            severityBefore = o.getInt("severityBefore"),
            tips = tips,
        )
    }.getOrNull()
}

object EpisodeCodec {
    fun encode(episodes: List<ReliefEpisode>): String = JSONArray().apply {
        episodes.forEach { e ->
            put(JSONObject().apply {
                put("uuid", e.uuid)
                put("startedAt", e.startedAt.toEpochMilli())
                e.endedAt?.let { put("endedAt", it.toEpochMilli()) }
                put("cause", e.causeRaw)
                put("severityBefore", e.severityBefore)
                e.severityAfter?.let { put("severityAfter", it) }
                put("intensity", e.intensity)
                put("plannedMinutes", e.plannedMinutes)
                put("source", e.sourceRaw)
                e.modeRaw?.let { put("mode", it) }
            })
        }
    }.toString()

    /** Skips a corrupt row rather than losing the whole log. */
    fun decode(json: String): List<ReliefEpisode> {
        val array = runCatching { JSONArray(json) }.getOrNull() ?: return emptyList()
        return (0 until array.length()).mapNotNull { i ->
            runCatching {
                val o = array.getJSONObject(i)
                ReliefEpisode(
                    uuid = o.getString("uuid"),
                    startedAt = Instant.ofEpochMilli(o.getLong("startedAt")),
                    endedAt = if (o.has("endedAt")) Instant.ofEpochMilli(o.getLong("endedAt")) else null,
                    causeRaw = o.getString("cause"),
                    severityBefore = o.getInt("severityBefore"),
                    severityAfter = if (o.has("severityAfter")) o.getInt("severityAfter") else null,
                    intensity = o.getInt("intensity"),
                    plannedMinutes = o.getInt("plannedMinutes"),
                    sourceRaw = o.optString("source", "phone"),
                    modeRaw = if (o.has("mode")) o.getString("mode") else null,
                )
            }.getOrNull()
        }
    }
}
