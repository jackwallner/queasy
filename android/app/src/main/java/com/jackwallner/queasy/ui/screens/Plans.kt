package com.jackwallner.queasy.ui.screens

import com.jackwallner.queasy.AppGraph
import com.jackwallner.queasy.model.FreeTier
import com.jackwallner.queasy.model.PatternEngine
import com.jackwallner.queasy.model.PressProtocol
import com.jackwallner.queasy.model.ReliefMode
import com.jackwallner.queasy.model.ReliefPlan

/** The length a session will actually run: Tone's minute, Press's hold, or the plan after the free cap. */
fun effectiveSeconds(plan: ReliefPlan, isPro: Boolean): Int = when (plan.mode) {
    ReliefMode.TONE -> 60
    ReliefMode.PRESS -> PressProtocol.HOLD_SECONDS
    ReliefMode.PULSE, ReliefMode.BREATHE -> FreeTier.cappedSeconds(plan.mode, plan.durationMinutes * 60, isPro)
}

/** Quick start reuses the last plan when there is one, otherwise Pulse at level 5 for 15 minutes. */
fun AppGraph.quickPlan(): ReliefPlan = settings.lastPlan ?: ReliefPlan.QUICK_START

/** `ModeStartView.plan`: the last plan with Settings overrides, switched to [mode]. */
fun AppGraph.modePlan(mode: ReliefMode): ReliefPlan {
    var base = settings.resolvedPlan(settings.lastPlan ?: ReliefPlan.QUICK_START).copy(mode = mode)
    if (base.durationMinutes < PatternEngine.MIN_DURATION) base = base.copy(durationMinutes = PatternEngine.MIN_DURATION)
    // Tone and Press are fixed protocols, not a length anyone chose.
    if (mode == ReliefMode.PRESS) base = base.copy(durationMinutes = PressProtocol.HOLD_SECONDS / 60)
    if (mode == ReliefMode.TONE) base = base.copy(durationMinutes = 1)
    return base
}

/** Starts a phone session and covers the screen with it. */
fun AppGraph.startSession(plan: ReliefPlan) {
    settings.updateLastPlan(plan)
    session.start(plan, effectiveSeconds(plan, subscriptions.isPro))
    navigator.showSession()
}

fun timeString(seconds: Int): String {
    val clamped = maxOf(seconds, 0)
    return "%d:%02d".format(clamped / 60, clamped % 60)
}
