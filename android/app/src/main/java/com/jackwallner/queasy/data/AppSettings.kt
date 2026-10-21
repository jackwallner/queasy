package com.jackwallner.queasy.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.queasy.model.BreathePattern
import com.jackwallner.queasy.model.ReliefPlan

/** Preferences, under the same keys as iOS's `AppSettings`. */
class AppSettings(private val defaults: KeyValueStore) {
    var hasCompletedOnboarding by mutableStateOf(defaults.getBoolean(Keys.ONBOARDED))
        private set

    /** Null lets the engine pick per check-in. */
    var defaultDurationMinutes by mutableStateOf(defaults.intOrNull(Keys.DURATION))
        private set

    /** Index into `BreathePattern.ALL`, or null to let the check-in pick. */
    var defaultBreatheIndex by mutableStateOf(defaults.intOrNull(Keys.BREATHE_INDEX))
        private set

    var showHistoryHeatmap by mutableStateOf(defaults.getBoolean(Keys.HEATMAP))
        private set

    var completedSessionCount by mutableStateOf(defaults.getInt(Keys.SESSION_COUNT))
        private set

    var lastPlan by mutableStateOf(defaults.getString(Keys.LAST_PLAN)?.let(PlanCodec::decode))
        private set

    fun completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.putBoolean(Keys.ONBOARDED, true)
    }

    fun updateDefaultDuration(minutes: Int?) {
        defaultDurationMinutes = minutes
        if (minutes == null) defaults.remove(Keys.DURATION) else defaults.putInt(Keys.DURATION, minutes)
    }

    fun updateDefaultBreatheIndex(index: Int?) {
        defaultBreatheIndex = index
        if (index == null) defaults.remove(Keys.BREATHE_INDEX) else defaults.putInt(Keys.BREATHE_INDEX, index)
    }

    fun updateShowHistoryHeatmap(value: Boolean) {
        showHistoryHeatmap = value
        defaults.putBoolean(Keys.HEATMAP, value)
    }

    fun incrementCompletedSessions(): Int {
        completedSessionCount += 1
        defaults.putInt(Keys.SESSION_COUNT, completedSessionCount)
        return completedSessionCount
    }

    fun updateLastPlan(plan: ReliefPlan?) {
        lastPlan = plan
        if (plan == null) defaults.remove(Keys.LAST_PLAN) else defaults.putString(Keys.LAST_PLAN, PlanCodec.encode(plan))
    }

    val defaultBreathePattern: BreathePattern?
        get() = defaultBreatheIndex?.let { BreathePattern.ALL.getOrNull(it) }

    /** Applies the user's overrides on top of an engine plan. */
    fun resolvedPlan(plan: ReliefPlan): ReliefPlan {
        var resolved = plan
        defaultDurationMinutes?.let { resolved = resolved.copy(durationMinutes = it) }
        defaultBreathePattern?.let { resolved = resolved.copy(breathe = it) }
        return resolved
    }

    private object Keys {
        const val ONBOARDED = "hasCompletedOnboarding"
        const val DURATION = "defaultDurationMinutes"
        const val LAST_PLAN = "lastPlanJSON"
        const val SESSION_COUNT = "completedSessionCount"
        const val HEATMAP = "showHistoryHeatmap"
        const val BREATHE_INDEX = "defaultBreatheIndex"
    }
}

fun KeyValueStore.intOrNull(key: String): Int? = if (contains(key)) getInt(key) else null
