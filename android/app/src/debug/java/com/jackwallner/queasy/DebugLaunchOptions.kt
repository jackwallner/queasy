package com.jackwallner.queasy

import android.content.Intent
import com.jackwallner.queasy.data.PackageKind
import com.jackwallner.queasy.data.PeriodUnit
import com.jackwallner.queasy.data.Plan
import com.jackwallner.queasy.data.PlanPeriod
import com.jackwallner.queasy.model.BreathePattern
import com.jackwallner.queasy.model.FreeTier
import com.jackwallner.queasy.model.NauseaCause
import com.jackwallner.queasy.model.ReliefEpisode
import com.jackwallner.queasy.model.ReliefMode
import com.jackwallner.queasy.model.ReliefPlan
import java.time.Instant
import kotlin.random.Random

/**
 * Debug-only launch extras, the Android side of the iOS launch arguments.
 * None of this is compiled into a release or QA build.
 *
 *     adb shell am start -n com.jackwallner.queasy/.MainActivity \
 *         --ez onboarded true --ez seedDemo true --ez demoPro true --es tab history
 *
 * `screen`: mode-<mode>, session-<mode>, checkin, recommend-<cause>, paywall.
 */
object DebugLaunchOptions {
    var learnCard: String? = null
        private set

    fun apply(graph: AppGraph, intent: Intent?) {
        val extras = intent?.extras ?: return
        if (extras.getBoolean("uiTest")) graph.review.isAutomationRun = true
        if (extras.getBoolean("resetAll")) {
            graph.defaults.keys().forEach(graph.defaults::remove)
            graph.episodes.replaceAll(emptyList())
        }
        if (extras.getBoolean("onboarded")) graph.settings.completeOnboarding()
        if (extras.getBoolean("demoPro")) graph.subscriptions.setLocalOverride(true)
        if (extras.getBoolean("previewStore")) {
            graph.subscriptions.loadPreviewPlans(previewPlans(), trialUsed = extras.getBoolean("previewTrialUsed"))
        }
        if (extras.getBoolean("seedDemo")) seed(graph)
        if (extras.getBoolean("heatmap")) graph.settings.updateShowHistoryHeatmap(true)
        if (extras.containsKey("launchCount")) graph.review.appLaunchCount = extras.getInt("launchCount")
        learnCard = extras.getString("learnCard")
        when (extras.getString("tab")) {
            "history" -> graph.navigator.tab = 1
            "learn" -> graph.navigator.tab = 2
            "settings" -> graph.navigator.tab = 3
        }
        openScreen(graph, extras.getString("screen") ?: return)
    }

    private fun openScreen(graph: AppGraph, screen: String) {
        val nav = graph.navigator
        when {
            screen == "checkin" -> nav.push(Overlay.CheckIn())
            screen == "paywall" -> nav.push(Overlay.Paywall("queasy_settings"))
            screen.startsWith("recommend-") -> nav.push(Overlay.CheckIn(NauseaCause.from(screen.removePrefix("recommend-"))))
            screen.startsWith("mode-") -> ReliefMode.from(screen.removePrefix("mode-"))?.let { nav.push(Overlay.ModeStart(it)) }
            screen.startsWith("session-") -> ReliefMode.from(screen.removePrefix("session-"))?.let { mode ->
                val plan = ReliefPlan.quickStart(mode).copy(breathe = BreathePattern.RELAXED)
                val seconds = when (mode) {
                    ReliefMode.TONE -> 60
                    ReliefMode.PRESS -> 180
                    else -> FreeTier.SESSION_SECONDS
                }
                graph.session.start(plan, seconds)
                nav.showSession()
            }
        }
    }

    /** A believable month of history (varied causes and modes, mostly improved), as iOS's seed. */
    private fun seed(graph: AppGraph) {
        val script = listOf(
            Seed(0, NauseaCause.MOTION, ReliefMode.TONE, 4, 2), Seed(1, NauseaCause.MOTION, ReliefMode.BREATHE, 3, 1),
            Seed(2, NauseaCause.ANXIETY, ReliefMode.BREATHE, 3, 2), Seed(4, NauseaCause.MOTION, ReliefMode.PULSE, 4, 2),
            Seed(5, NauseaCause.VERTIGO, ReliefMode.BREATHE, 3, 3), Seed(7, NauseaCause.MOTION, ReliefMode.TONE, 5, 2),
            Seed(8, NauseaCause.HANGOVER, ReliefMode.PULSE, 4, 2), Seed(10, NauseaCause.MOTION, ReliefMode.BREATHE, 3, 1),
            Seed(12, NauseaCause.GENERAL, ReliefMode.PRESS, 4, 2), Seed(13, NauseaCause.ANXIETY, ReliefMode.BREATHE, 3, 2),
            Seed(15, NauseaCause.MOTION, ReliefMode.TONE, 4, 1), Seed(17, NauseaCause.GENERAL, ReliefMode.PULSE, 3, 2),
            Seed(19, NauseaCause.MOTION, ReliefMode.BREATHE, 4, 2), Seed(21, NauseaCause.VERTIGO, ReliefMode.PULSE, 4, 3),
            Seed(22, NauseaCause.MOTION, ReliefMode.TONE, 3, 1), Seed(25, NauseaCause.HANGOVER, ReliefMode.BREATHE, 5, 3),
            Seed(27, NauseaCause.MOTION, ReliefMode.PULSE, 4, 2), Seed(29, NauseaCause.MOTION, ReliefMode.PRESS, 3, null),
        )
        val random = Random(7)
        val now = Instant.now()
        graph.episodes.replaceAll(script.map { s ->
            val start = now.minusSeconds(s.daysAgo * 86_400L + random.nextLong(0, 6 * 3600L))
            val minutes = when (s.mode) {
                ReliefMode.TONE -> 1
                ReliefMode.PRESS -> 3
                else -> 18
            }
            ReliefEpisode(
                startedAt = start,
                endedAt = start.plusSeconds(minutes * 60L),
                causeRaw = s.cause.raw,
                severityBefore = s.before,
                severityAfter = s.after,
                intensity = minOf(s.before * 2, 10),
                plannedMinutes = minutes,
                modeRaw = s.mode.raw,
            )
        })
    }

    private data class Seed(val daysAgo: Int, val cause: NauseaCause, val mode: ReliefMode, val before: Int, val after: Int?)

    /** The iOS US ladder with the 1-week trial, so the real paywall renders without a store. */
    private fun previewPlans(): List<Plan> {
        val trial = PlanPeriod(1, PeriodUnit.WEEK)
        return listOf(
            Plan("\$rc_annual", "com.jackwallner.queasy.pro.yearly", PackageKind.YEARLY, 14_990_000, "$14.99", "USD", PlanPeriod(1, PeriodUnit.YEAR), trial, "Queasy Pro Yearly"),
            Plan("\$rc_monthly", "com.jackwallner.queasy.pro.monthly", PackageKind.MONTHLY, 2_990_000, "$2.99", "USD", PlanPeriod(1, PeriodUnit.MONTH), trial, "Queasy Pro Monthly"),
            Plan("\$rc_lifetime", "com.jackwallner.queasy.pro.lifetime", PackageKind.LIFETIME, 29_990_000, "$29.99", "USD", null, null, "Queasy Pro Lifetime"),
        )
    }
}
