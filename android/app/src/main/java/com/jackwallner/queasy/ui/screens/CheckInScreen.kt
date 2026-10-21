package com.jackwallner.queasy.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.MedicalInformation
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.queasy.Overlay
import com.jackwallner.queasy.model.CheckIn
import com.jackwallner.queasy.model.FreeTier
import com.jackwallner.queasy.model.NauseaCause
import com.jackwallner.queasy.model.PatternEngine
import com.jackwallner.queasy.model.PulseSpec
import com.jackwallner.queasy.model.PulseStrength
import com.jackwallner.queasy.model.ReliefMode
import com.jackwallner.queasy.ui.LocalGraph
import com.jackwallner.queasy.ui.theme.BreathingBloom
import com.jackwallner.queasy.ui.theme.ChevronCard
import com.jackwallner.queasy.ui.theme.IconNote
import com.jackwallner.queasy.ui.theme.ProgressRing
import com.jackwallner.queasy.ui.theme.SectionLabel
import com.jackwallner.queasy.ui.theme.SymbolDisc
import com.jackwallner.queasy.ui.theme.Tide
import com.jackwallner.queasy.ui.theme.TideButton
import com.jackwallner.queasy.ui.theme.TideCard
import com.jackwallner.queasy.ui.theme.TideType
import com.jackwallner.queasy.ui.theme.icon
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

val severityLabels = listOf("Barely there", "Noticeable", "Uncomfortable", "Really rough", "About to be sick")

/** The "is it still happening" question, worded for the chosen cause. */
fun exposureQuestion(cause: NauseaCause?): Pair<String, String> = when (cause) {
    NauseaCause.MOTION -> "Still moving?" to "In the car, on the boat, or in the air right now."
    NauseaCause.MORNING_SICKNESS -> "Mid-wave?" to "Right in it, or on the way back down."
    NauseaCause.HANGOVER -> "Still feeling rough?" to "At the peak, or on the way down."
    NauseaCause.VERTIGO -> "Still spinning?" to "Room still moving, or starting to settle."
    NauseaCause.ANXIETY -> "Still in the thick of it?" to "In the stressful moment, or winding down."
    NauseaCause.GENERAL, null -> "Feeling it right now?" to "Mid-wave, or easing off."
}

/** `CheckInView.swift`: three questions, then the recommendation. */
@Composable
fun CheckInScreen(prefill: NauseaCause?, onClose: () -> Unit) {
    var cause by remember { mutableStateOf(prefill) }
    var severity by remember { mutableStateOf(if (prefill != null) 4 else null) }
    var stillExposed by remember { mutableStateOf(if (prefill != null) true else null) }
    var recentlyAte by remember { mutableStateOf(if (prefill != null) false else null) }
    var step by remember { mutableIntStateOf(if (prefill != null) 3 else 0) }
    val scope = rememberCoroutineScope()

    BackHandler(enabled = step > 0) { step -= 1 }

    SheetScaffold("", "Cancel", onClose, closeTag = "checkin-cancel") {
        LinearProgressIndicator(
            progress = { (step + 1) / 4f },
            modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(top = 4.dp).clip(RoundedCornerShape(2.dp)),
            color = Tide.aqua,
            trackColor = Tide.paper3,
            drawStopIndicator = {},
        )
        AnimatedContent(
            targetState = step,
            transitionSpec = {
                val forward = targetState > initialState
                (slideInHorizontally(tween(280)) { if (forward) it / 3 else -it / 3 } + fadeIn(tween(200))) togetherWith
                    (slideOutHorizontally(tween(280)) { if (forward) -it / 3 else it / 3 } + fadeOut(tween(160)))
            },
            label = "checkin-step",
            modifier = Modifier.fillMaxSize(),
        ) { current ->
            when (current) {
                0 -> CauseStep(cause) { cause = it; step = 1 }
                1 -> SeverityStep(severity) { severity = it; step = 2 }
                2 -> ContextStep(
                    cause = cause,
                    stillExposed = stillExposed,
                    recentlyAte = recentlyAte,
                    onExposed = { stillExposed = it },
                    onAte = { recentlyAte = it },
                    onComplete = { scope.launch { delay(220); step = 3 } },
                )
                else -> {
                    val c = cause
                    val s = severity
                    if (c != null && s != null) {
                        RecommendationStep(CheckIn(c, s, stillExposed ?: false, recentlyAte ?: false))
                    }
                }
            }
        }
    }
}

@Composable
private fun StepTitle(text: String) {
    Text(text, style = TideType.display(26.sp), textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp))
}

@Composable
private fun CauseStep(selected: NauseaCause?, onPick: (NauseaCause) -> Unit) {
    Column(Modifier.fillMaxSize().padding(top = 22.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        StepTitle("What kind of queasy?")
        Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            NauseaCause.entries.chunked(2).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    row.forEach { candidate ->
                        val on = candidate == selected
                        Column(
                            Modifier
                                .weight(1f)
                                .height(92.dp)
                                .clip(RoundedCornerShape(18.dp))
                                .background(if (on) Tide.aqua else Tide.paper2)
                                .clickable(role = Role.Button) { onPick(candidate) }
                                .testTag("cause-${candidate.raw}"),
                            verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Icon(candidate.icon, null, tint = if (on) Color.White else Tide.aqua, modifier = Modifier.size(28.dp))
                            Text(
                                candidate.label,
                                style = TideType.footnote.copy(fontWeight = FontWeight.SemiBold, color = if (on) Color.White else Tide.ink),
                                textAlign = TextAlign.Center,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SeverityStep(selected: Int?, onPick: (Int) -> Unit) {
    Column(Modifier.fillMaxSize().padding(top = 22.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        StepTitle("How bad is it right now?")
        Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            (1..5).forEach { level ->
                val on = selected == level
                Row(
                    Modifier
                        .fillMaxWidth()
                        .height(54.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(if (on) Tide.severityColor(level) else Tide.paper2)
                        .clickable(role = Role.Button) { onPick(level) }
                        .testTag("severity-$level")
                        .padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        "$level",
                        style = TideType.rounded(20.sp, FontWeight.Bold),
                        color = if (on) Color.White else Tide.severityColor(level),
                        modifier = Modifier.width(34.dp),
                    )
                    Text(severityLabels[level - 1], style = TideType.subheadline.copy(fontWeight = FontWeight.SemiBold, color = if (on) Color.White else Tide.ink))
                }
            }
        }
    }
}

@Composable
private fun ContextStep(
    cause: NauseaCause?,
    stillExposed: Boolean?,
    recentlyAte: Boolean?,
    onExposed: (Boolean) -> Unit,
    onAte: (Boolean) -> Unit,
    onComplete: () -> Unit,
) {
    val (prompt, detail) = exposureQuestion(cause)
    Column(Modifier.fillMaxSize().padding(top = 22.dp), verticalArrangement = Arrangement.spacedBy(22.dp)) {
        StepTitle("Two quick things")
        Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            ContextQuestion(prompt, detail, stillExposed, "exposed") {
                onExposed(it)
                if (recentlyAte != null) onComplete()
            }
            ContextQuestion("Eaten in the last hour?", "We start gentler on a full stomach.", recentlyAte, "ate") {
                onAte(it)
                if (stillExposed != null) onComplete()
            }
        }
    }
}

@Composable
private fun ContextQuestion(prompt: String, detail: String, selection: Boolean?, idPrefix: String, onAnswer: (Boolean) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(prompt, style = TideType.headline)
            Text(detail, style = TideType.caption)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            listOf(true to "Yes", false to "No").forEach { (value, label) ->
                val on = selection == value
                Box(
                    Modifier
                        .weight(1f)
                        .height(50.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(if (on) Tide.aqua else Tide.paper2)
                        .clickable(role = Role.Button) { onAnswer(value) }
                        .testTag("$idPrefix-${label.lowercase()}"),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(label, style = TideType.subheadline.copy(fontWeight = FontWeight.SemiBold, color = if (on) Color.White else Tide.ink))
                }
            }
        }
    }
}

/** `RecommendationView`: the suggested mode, swappable, then start. */
@Composable
private fun RecommendationStep(checkIn: CheckIn) {
    val graph = LocalGraph.current
    val suggested = PatternEngine.suggestedModes(checkIn.cause)
    var chosen by remember { mutableStateOf<ReliefMode?>(null) }
    val mode = chosen ?: suggested[0]
    val plan = graph.settings.resolvedPlan(PatternEngine.recommend(checkIn.copy(mode = mode)))
    val seconds = FreeTier.cappedSeconds(mode, plan.durationMinutes * 60, graph.subscriptions.isPro)
    val capped = seconds < plan.durationMinutes * 60

    LaunchedEffect(plan) { graph.settings.updateLastPlan(plan) }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(top = 16.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            SectionLabel("Suggested for ${checkIn.cause.label.lowercase()}")
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                suggested.forEach { candidate ->
                    val on = candidate == mode
                    Row(
                        Modifier
                            .height(42.dp)
                            .clip(CircleShape)
                            .background(if (on) Tide.aqua else Tide.paper2)
                            .clickable(role = Role.Button) { chosen = candidate }
                            .testTag("mode-${candidate.raw}")
                            .padding(horizontal = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Icon(candidate.icon, null, tint = if (on) Color.White else Tide.ink, modifier = Modifier.size(18.dp))
                        Text(candidate.title, style = TideType.subheadline.copy(fontWeight = FontWeight.SemiBold, color = if (on) Color.White else Tide.ink))
                    }
                }
            }
        }

        TideCard(horizontalAlignment = Alignment.CenterHorizontally) {
            when (mode) {
                ReliefMode.PULSE -> {
                    ProgressRing(plan.intensity / 10f, Modifier.size(130.dp).padding(vertical = 4.dp)) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("${plan.intensity}", style = TideType.rounded(44.sp, FontWeight.Bold), color = Tide.ink)
                            Text("of 10", style = TideType.caption.copy(color = Tide.ink3))
                        }
                    }
                    Text(specDescription(plan.spec), style = TideType.subheadline)
                }
                ReliefMode.BREATHE -> {
                    BreathingBloom(plan.breathe, anchorMillis = null, modifier = Modifier.fillMaxWidth().height(130.dp))
                    Text("${plan.breathe.label} · about ${plan.breathe.breathsPerMinute} breaths a minute", style = TideType.subheadline)
                }
                ReliefMode.TONE -> {
                    SymbolDisc(mode.icon, size = 130.dp)
                    Text("100 Hz · one minute · headphones", style = TideType.subheadline)
                }
                ReliefMode.PRESS -> {
                    SymbolDisc(mode.icon, size = 130.dp, iconSize = 50.dp)
                    Text("Three minutes of steady pressure", style = TideType.subheadline)
                }
            }
            Text(mode.blurb, style = TideType.footnote.copy(color = Tide.ink3), textAlign = TextAlign.Center)
            Text(
                when (mode) {
                    ReliefMode.TONE -> "One minute, then it stops on its own"
                    ReliefMode.PRESS -> "Three minutes, timed for you"
                    else -> if (capped) "${seconds / 60} minutes on the free plan" else "${seconds / 60} minutes"
                },
                style = TideType.caption.copy(fontWeight = FontWeight.SemiBold, color = Tide.ink3),
            )
        }

        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
            TideButton(mode.startLabel, onClick = { graph.startSession(plan) }, icon = mode.icon, tag = "use-phone")
            if (mode.needsHeadphones) Text("Put headphones in first, and keep the volume low.", style = TideType.caption2)
        }
        if (capped) {
            ChevronCard(
                icon = Icons.Rounded.Timer,
                title = null,
                detail = "Free sessions run ${FreeTier.SESSION_SECONDS / 60} minutes. Pro runs the full ${plan.durationMinutes}.",
                onClick = { graph.navigator.push(Overlay.Paywall("queasy_session_length")) },
                tag = "unlock-length",
            )
        }
        checkIn.cause.safetyNote?.let { IconNote(Icons.Rounded.MedicalInformation, it, tint = Tide.ink2, inCard = true) }
        if (plan.tips.isNotEmpty()) {
            TideCard(spacing = 10.dp) {
                SectionLabel("While it runs")
                plan.tips.forEach { tip ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Rounded.AutoAwesome, null, tint = Tide.aqua, modifier = Modifier.padding(top = 2.dp).size(12.dp))
                        Text(tip, style = TideType.footnote)
                    }
                }
            }
        }
        Text(
            "Queasy is a set of drug-free comfort techniques you run yourself. It is not a medical device, it does not diagnose or treat anything, and it may not change how you feel.",
            style = TideType.caption2,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(top = 2.dp),
        )
    }
}

fun specDescription(spec: PulseSpec): String {
    val taps = if (spec.burstCount == 1) "Single tap" else "${spec.burstCount}-tap burst"
    val strength = when (spec.strength) {
        PulseStrength.SOFT -> "soft"
        PulseStrength.MEDIUM -> "medium"
        PulseStrength.STRONG -> "strong"
    }
    return "$taps, $strength, every ${"%.1f".format(java.util.Locale.US, spec.interval)}s"
}
