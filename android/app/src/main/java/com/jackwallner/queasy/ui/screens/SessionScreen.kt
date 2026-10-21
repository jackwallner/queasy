package com.jackwallner.queasy.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material.icons.rounded.SentimentDissatisfied
import androidx.compose.material.icons.rounded.SentimentNeutral
import androidx.compose.material.icons.rounded.SentimentSatisfied
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.queasy.Overlay
import com.jackwallner.queasy.model.FreeTier
import com.jackwallner.queasy.model.PatternEngine
import com.jackwallner.queasy.model.PulseSpec
import com.jackwallner.queasy.model.ReliefFeeling
import com.jackwallner.queasy.model.ReliefMode
import com.jackwallner.queasy.session.SessionController
import com.jackwallner.queasy.ui.LocalGraph
import com.jackwallner.queasy.ui.theme.BreathingBloom
import com.jackwallner.queasy.ui.theme.ProgressRing
import com.jackwallner.queasy.ui.theme.QuietButton
import com.jackwallner.queasy.ui.theme.RipplePulse
import com.jackwallner.queasy.ui.theme.SymbolDisc
import com.jackwallner.queasy.ui.theme.Tide
import com.jackwallner.queasy.ui.theme.TideButton
import com.jackwallner.queasy.ui.theme.TideType
import com.jackwallner.queasy.ui.theme.icon
import com.jackwallner.queasy.ui.theme.tideCard
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * `PhoneSessionView.swift`: the stage swaps per mode (ripple, breathing bloom,
 * waveform, hold timer), then the same three-choice rating as iOS.
 */
@Composable
fun SessionScreen(onClose: () -> Unit) {
    val graph = LocalGraph.current
    val session = graph.session
    // The screen stays on while a session runs, as iOS disables the idle timer.
    val view = LocalView.current
    DisposableEffect(session.phase) {
        view.keepScreenOn = session.phase == SessionController.Phase.RUNNING
        onDispose { view.keepScreenOn = false }
    }
    LaunchedEffect(session.phase) {
        if (session.phase == SessionController.Phase.IDLE) onClose()
    }
    Box(Modifier.fillMaxSize().background(Tide.tideWash).statusBarsPadding().navigationBarsPadding()) {
        when (session.phase) {
            SessionController.Phase.RUNNING -> Running(onClose)
            SessionController.Phase.RATING -> Rating(onClose)
            SessionController.Phase.IDLE -> Unit
        }
    }
}

@Composable
private fun Running(onClose: () -> Unit) {
    val graph = LocalGraph.current
    val session = graph.session
    val mode = session.mode
    Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(22.dp)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(44.dp).clip(CircleShape).clickable(role = Role.Button) {
                    session.cancel()
                    onClose()
                }.semantics { contentDescription = "Cancel session" }.testTag("cancel-session"),
                contentAlignment = Alignment.Center,
            ) {
                Box(Modifier.size(30.dp).background(Tide.paper2, CircleShape), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Close, null, tint = Tide.ink2, modifier = Modifier.size(18.dp))
                }
            }
            Spacer(Modifier.weight(1f))
            Text(timeString(session.remainingSeconds), style = TideType.rounded(17.sp), color = Tide.ink2, modifier = Modifier.testTag("session-remaining"))
        }
        Spacer(Modifier.weight(1f))
        Stage(mode)
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                when (mode) {
                    ReliefMode.PULSE -> "Level ${session.intensity}"
                    ReliefMode.BREATHE -> "Follow the breath"
                    ReliefMode.TONE -> "100 Hz"
                    ReliefMode.PRESS -> "Keep the pressure on"
                },
                style = TideType.display(28.sp),
                modifier = Modifier.testTag("session-headline"),
            )
            Text(guidance(mode), style = TideType.footnote, textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 28.dp))
            if (mode.needsHaptics && !session.hapticsAvailable) {
                Text(
                    "This device has no vibration motor, so it cannot play a pattern you can feel. Tone still works here.",
                    style = TideType.caption.copy(color = Tide.coral),
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 28.dp),
                )
            }
        }
        if (mode == ReliefMode.PULSE) {
            Row(horizontalArrangement = Arrangement.spacedBy(26.dp)) {
                IntensityButton(Icons.Rounded.Remove, "Decrease intensity", session.intensity > PatternEngine.MIN_INTENSITY, "intensity-down") {
                    session.adjustIntensity(-1)
                }
                IntensityButton(Icons.Rounded.Add, "Increase intensity", session.intensity < PatternEngine.MAX_INTENSITY, "intensity-up") {
                    session.adjustIntensity(1)
                }
            }
        }
        if (mode == ReliefMode.PULSE || mode == ReliefMode.BREATHE) {
            Row(
                Modifier.padding(horizontal = 20.dp).fillMaxWidth().tideCard(16.dp)
                    .clickable(role = Role.Switch) { session.updateToneEnabled(!session.toneEnabled) }
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text("Add the 100 Hz tone", style = TideType.subheadline.copy(fontWeight = FontWeight.SemiBold, color = Tide.ink))
                    Text("Headphones recommended", style = TideType.caption)
                }
                Switch(
                    checked = session.toneEnabled,
                    onCheckedChange = session::updateToneEnabled,
                    modifier = Modifier.testTag("tone-toggle"),
                    colors = SwitchDefaults.colors(checkedTrackColor = Tide.aqua, checkedThumbColor = Color.White),
                )
            }
        }
        Spacer(Modifier.weight(1f))
        TideButton("I'm Done", onClick = session::finish, modifier = Modifier.padding(horizontal = 20.dp).padding(bottom = 16.dp), tag = "end-session")
    }
}

@Composable
private fun Stage(mode: ReliefMode) {
    val session = LocalGraph.current.session
    val stage = Modifier.size(240.dp)
    when (mode) {
        ReliefMode.PULSE -> RipplePulse(PulseSpec.forLevel(session.intensity).interval, Tide.aqua, stage)
        ReliefMode.BREATHE -> BreathingBloom(session.plan.breathe, anchorMillis = session.startedAt.toEpochMilli(), modifier = stage)
        ReliefMode.TONE -> Box(stage, contentAlignment = Alignment.Center) { SymbolDisc(mode.icon, size = 200.dp, iconSize = 74.dp) }
        ReliefMode.PRESS -> {
            val total = session.totalSeconds
            val done = total - session.remainingSeconds
            ProgressRing(if (total > 0) done.toFloat() / total else 0f, stage) {
                Icon(Icons.Rounded.TouchApp, null, tint = Tide.aqua, modifier = Modifier.size(64.dp))
            }
        }
    }
}

private fun guidance(mode: ReliefMode): String = when (mode) {
    ReliefMode.PULSE -> "Hold your phone against the inside of your wrist, or rest it where you can feel the taps."
    ReliefMode.BREATHE -> "Long swell in, longer fade out. Rest the phone on you and shut your eyes if you like."
    ReliefMode.TONE -> "Keep the volume low. It should sit under the noise around you, not over it."
    ReliefMode.PRESS -> "Thumb or band on the spot, steady pressure, three finger-widths below the wrist crease."
}

@Composable
private fun IntensityButton(icon: ImageVector, label: String, enabled: Boolean, tag: String, onClick: () -> Unit) {
    Box(
        Modifier
            .size(58.dp)
            .background(Tide.paper2, CircleShape)
            .border(1.dp, Tide.ink.copy(alpha = 0.06f), CircleShape)
            .clip(CircleShape)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .semantics { contentDescription = label }
            .testTag(tag),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, tint = if (enabled) Tide.aqua else Tide.ink3, modifier = Modifier.size(28.dp))
    }
}

@Composable
private fun Rating(onClose: () -> Unit) {
    val graph = LocalGraph.current
    val session = graph.session

    fun save(severityAfter: Int?) {
        // The session hit the free ceiling if the plan asked for more than it was given.
        val wasCapped = FreeTier.isCapped(session.mode, session.plan.durationMinutes * 60, graph.subscriptions.isPro)
        val episode = session.complete(severityAfter)
        val count = graph.settings.incrementCompletedSessions()
        if (graph.upgrades.shouldPrompt(graph.subscriptions.isPro, wasCapped, count)) {
            graph.upgrades.recordPrompt()
            // Wait for the session cover to clear before the paywall slides up.
            graph.scope.launch {
                delay(600)
                graph.navigator.push(Overlay.Paywall("queasy_after_session"))
            }
        } else if ((episode.reliefDelta ?: 0) >= 0) {
            graph.review.recordPositiveMoment()
            graph.navigator.recordPositiveMoment()
        }
        onClose()
    }

    Column(
        Modifier.fillMaxSize().padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(22.dp, Alignment.CenterVertically),
    ) {
        Text("How do you feel now?", style = TideType.display(28.sp))
        Text("Compared to when you started.", style = TideType.subheadline)
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            FeelingButton("Better", Icons.Rounded.SentimentSatisfied, Tide.aqua, ReliefFeeling.BETTER) {
                save(ReliefFeeling.BETTER.severityAfter(session.plan.severityBefore))
            }
            FeelingButton("The same", Icons.Rounded.SentimentNeutral, Tide.sand, ReliefFeeling.SAME) {
                save(ReliefFeeling.SAME.severityAfter(session.plan.severityBefore))
            }
            FeelingButton("Worse", Icons.Rounded.SentimentDissatisfied, Tide.coral, ReliefFeeling.WORSE) {
                save(ReliefFeeling.WORSE.severityAfter(session.plan.severityBefore))
            }
        }
        QuietButton("Skip", onClick = { save(null) }, color = Tide.ink3, tag = "rating-skip")
    }
}

@Composable
private fun FeelingButton(label: String, icon: ImageVector, tint: Color, feeling: ReliefFeeling, onClick: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .height(56.dp)
            .clip(shape)
            .background(Tide.paper2)
            .border(1.dp, tint.copy(alpha = 0.25f), shape)
            .clickable(role = Role.Button, onClick = onClick)
            .testTag("after-feeling-${feeling.raw}")
            .padding(horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(icon, null, tint = tint, modifier = Modifier.width(30.dp).size(26.dp))
        Text(label, style = TideType.body.copy(fontWeight = FontWeight.SemiBold))
    }
}
