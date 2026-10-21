package com.jackwallner.queasy.ui.screens

import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.OpenInNew
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.queasy.Overlay
import com.jackwallner.queasy.model.FreeTier
import com.jackwallner.queasy.model.PatternEngine
import com.jackwallner.queasy.model.PressProtocol
import com.jackwallner.queasy.model.ReliefMode
import com.jackwallner.queasy.ui.LocalGraph
import com.jackwallner.queasy.ui.TideTopBar
import com.jackwallner.queasy.ui.openUrl
import com.jackwallner.queasy.ui.theme.BreathingBloom
import com.jackwallner.queasy.ui.theme.ChevronCard
import com.jackwallner.queasy.ui.theme.QuietButton
import com.jackwallner.queasy.ui.theme.SectionLabel
import com.jackwallner.queasy.ui.theme.SymbolDisc
import com.jackwallner.queasy.ui.theme.Tide
import com.jackwallner.queasy.ui.theme.TideButton
import com.jackwallner.queasy.ui.theme.TideCard
import com.jackwallner.queasy.ui.theme.TideType
import com.jackwallner.queasy.ui.theme.icon

/** A full-height sheet: a close action, a serif title, and a scrolling body on the tide wash. */
@Composable
fun SheetScaffold(
    title: String,
    closeLabel: String,
    onClose: () -> Unit,
    closeTag: String = "sheet-close",
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(Modifier.fillMaxSize().background(Tide.tideWash).navigationBarsPadding()) {
        TideTopBar(title, leading = { QuietButton(closeLabel, onClose, tag = closeTag) })
        content()
    }
}

/** `ModeStartView.swift`: one mode, explained and started. */
@Composable
fun ModeStartScreen(mode: ReliefMode, onClose: () -> Unit) {
    val graph = LocalGraph.current
    val activity = LocalActivity.current
    val isPro = graph.subscriptions.isPro
    val plan = graph.modePlan(mode)
    val seconds = effectiveSeconds(plan, isPro)
    val capped = FreeTier.isCapped(mode, plan.durationMinutes * 60, isPro)

    SheetScaffold(mode.title, "Close", onClose) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(top = 12.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            TideCard(horizontalAlignment = Alignment.CenterHorizontally) {
                if (mode == ReliefMode.BREATHE) {
                    BreathingBloom(plan.breathe, anchorMillis = null, modifier = Modifier.fillMaxWidth().height(140.dp))
                } else {
                    SymbolDisc(mode.icon)
                }
                Text(mode.blurb, style = TideType.callout, textAlign = TextAlign.Center)
                Text(
                    when (mode) {
                        ReliefMode.TONE -> "One minute, then it stops on its own"
                        ReliefMode.PRESS -> "${PressProtocol.HOLD_SECONDS / 60} minutes, timed for you"
                        else -> "${seconds / 60} minutes"
                    },
                    style = TideType.caption.copy(fontWeight = FontWeight.SemiBold, color = Tide.ink3),
                )
            }
            if (mode == ReliefMode.PRESS) PressSteps()
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                TideButton(mode.startLabel, onClick = { graph.startSession(plan) }, icon = mode.icon, tag = "mode-start-phone")
                if (mode.needsHeadphones) Text("Headphones in, volume low. It is meant to be quiet.", style = TideType.caption2)
            }
            if (capped) {
                ChevronCard(
                    icon = Icons.Rounded.Timer,
                    title = null,
                    detail = "Free sessions run ${FreeTier.SESSION_SECONDS / 60} minutes. Pro goes up to ${PatternEngine.MAX_DURATION}.",
                    onClick = { graph.navigator.push(Overlay.Paywall("queasy_mode_length")) },
                    tag = "mode-unlock-length",
                )
            }
            mode.evidenceNote?.let { note ->
                TideCard(spacing = 8.dp) {
                    SectionLabel("What this leans on")
                    Text(note, style = TideType.caption)
                    mode.sourceUrl?.let { url ->
                        QuietButton(
                            "Read the source",
                            onClick = { activity?.openUrl(url) },
                            color = Tide.aqua,
                            icon = Icons.AutoMirrored.Rounded.OpenInNew,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PressSteps() {
    TideCard {
        SectionLabel("Finding the spot")
        PressProtocol.steps.forEachIndexed { index, step ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.size(22.dp).background(Tide.aqua, CircleShape), contentAlignment = Alignment.Center) {
                    Text("${index + 1}", style = TideType.rounded(13.sp, FontWeight.Bold), color = Color.White)
                }
                Text(step, style = TideType.footnote, modifier = Modifier.weight(1f))
            }
        }
    }
}
