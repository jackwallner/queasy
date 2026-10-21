package com.jackwallner.queasy.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Assignment
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.PhoneAndroid
import androidx.compose.material.icons.rounded.Vibration
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.queasy.Overlay
import com.jackwallner.queasy.model.PressProtocol
import com.jackwallner.queasy.model.ReliefMode
import com.jackwallner.queasy.session.SessionController
import com.jackwallner.queasy.ui.LocalGraph
import com.jackwallner.queasy.ui.TideTopBar
import com.jackwallner.queasy.ui.theme.BreathingBloom
import com.jackwallner.queasy.ui.theme.ChevronCard
import com.jackwallner.queasy.ui.theme.RipplePulse
import com.jackwallner.queasy.ui.theme.Tide
import com.jackwallner.queasy.ui.theme.TideButton
import com.jackwallner.queasy.ui.theme.TideCard
import com.jackwallner.queasy.ui.theme.TideType
import com.jackwallner.queasy.ui.theme.icon
import com.jackwallner.queasy.ui.theme.tideCard

/** `RelieveHomeView.swift`: quick start, the check-in, and the four mode cards. */
@Composable
fun RelieveHomeScreen() {
    val graph = LocalGraph.current
    val session = graph.session
    Column(Modifier.fillMaxSize().background(Tide.tideWash)) {
        TideTopBar("Queasy")
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 18.dp).padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("Feeling queasy?", style = TideType.display(30.sp))
                Text(
                    "Four drug-free things to try, through your phone's vibration or in your ear. Start one now, or answer three questions first.",
                    style = TideType.subheadline,
                )
            }
            if (session.phase != SessionController.Phase.IDLE) ActiveSessionCard()
            QuickStartCard()
            ChevronCard(
                icon = Icons.AutoMirrored.Rounded.Assignment,
                title = "Match to my symptoms",
                detail = "Three questions pick the mode, level and length for you.",
                onClick = { graph.navigator.push(Overlay.CheckIn()) },
                tag = "start-checkin",
            )
            ModeGrid()
            HoldHintCard()
        }
    }
}

@Composable
private fun QuickStartCard() {
    val graph = LocalGraph.current
    val plan = graph.quickPlan()
    val seconds = effectiveSeconds(plan, graph.subscriptions.isPro)
    TideCard(horizontalAlignment = Alignment.CenterHorizontally) {
        if (plan.mode == ReliefMode.BREATHE) {
            BreathingBloom(plan.breathe, anchorMillis = null, showsLabel = false, modifier = Modifier.fillMaxWidth().height(96.dp))
        } else {
            RipplePulse(1.4, Tide.aqua, Modifier.fillMaxWidth().height(96.dp))
        }
        TideButton(
            text = plan.mode.startLabel,
            icon = plan.mode.icon,
            hero = true,
            onClick = { graph.startSession(plan) },
            tag = "quick-start",
        )
        Text(
            when (plan.mode) {
                ReliefMode.TONE -> "100 Hz, one minute, headphones in"
                ReliefMode.PRESS -> "${PressProtocol.HOLD_SECONDS / 60} minutes of steady pressure, timed"
                ReliefMode.PULSE -> "Level ${plan.intensity} · ${seconds / 60} min on this phone"
                ReliefMode.BREATHE -> "${plan.breathe.label} · ${seconds / 60} min on this phone"
            },
            style = TideType.footnote.copy(color = Tide.ink3),
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun ModeGrid() {
    val graph = LocalGraph.current
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        ReliefMode.entries.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                row.forEach { mode ->
                    Column(
                        Modifier
                            .weight(1f)
                            .heightIn(min = 132.dp)
                            .tideCard(20.dp)
                            .clickable(role = Role.Button) { graph.navigator.push(Overlay.ModeStart(mode)) }
                            .testTag("mode-card-${mode.raw}")
                            .padding(14.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Icon(mode.icon, null, tint = Tide.aqua, modifier = Modifier.size(24.dp))
                        Text(mode.title, style = TideType.rounded(17.sp, FontWeight.Bold), color = Tide.ink)
                        Text(mode.tagline, style = TideType.caption2)
                    }
                }
            }
        }
    }
}

@Composable
private fun ActiveSessionCard() {
    val graph = LocalGraph.current
    val session = graph.session
    Row(
        Modifier
            .fillMaxWidth()
            .tideCard(18.dp)
            .clickable(role = Role.Button) { graph.navigator.push(Overlay.Session) }
            .testTag("active-session")
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.Rounded.Vibration, null, tint = Tide.aqua, modifier = Modifier.size(26.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                if (session.phase == SessionController.Phase.RUNNING) "${session.mode.title} running" else "How do you feel?",
                style = TideType.headline,
            )
            Text("${timeString(session.remainingSeconds)} left", style = TideType.caption)
        }
        Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = Tide.ink3)
    }
}

/** iOS `wearHintCard`, for a phone held where the band would sit. */
@Composable
private fun HoldHintCard() {
    Row(
        Modifier.fillMaxWidth().tideCard(18.dp).padding(16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.Rounded.PhoneAndroid, null, tint = Tide.ink2, modifier = Modifier.size(24.dp))
        Text(
            buildAnnotatedString {
                append("For Pulse, hold your phone against the ")
                withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append("inside") }
                append(" of your wrist, three finger-widths below the crease. That is where an acupressure band sits.")
            },
            style = TideType.caption,
        )
    }
}
