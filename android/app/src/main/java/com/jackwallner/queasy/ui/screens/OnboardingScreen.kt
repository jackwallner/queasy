package com.jackwallner.queasy.ui.screens

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Assignment
import androidx.compose.material.icons.rounded.GridView
import androidx.compose.material.icons.rounded.PhoneAndroid
import androidx.compose.material.icons.rounded.Vibration
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.queasy.ui.LocalGraph
import com.jackwallner.queasy.ui.theme.SymbolDisc
import com.jackwallner.queasy.ui.theme.Tide
import com.jackwallner.queasy.ui.theme.TideButton
import com.jackwallner.queasy.ui.theme.TideType
import kotlinx.coroutines.launch

private data class OnboardPage(val icon: ImageVector, val title: String, val text: String)

/**
 * `OnboardingView.swift`, four pages. The iOS last page is the Apple Watch
 * gate; Android has no watch app, so it says plainly that the phone's own
 * vibration plays the sessions.
 */
private val pages = listOf(
    OnboardPage(
        Icons.Rounded.GridView,
        "Four things to try\nwhen you feel sick",
        "A steady tap you feel. A paced breath you feel rather than watch. A one-minute 100 Hz tone. A timed hold on the spot an acupressure band sits on. All drug-free, all free to use.",
    ),
    OnboardPage(
        Icons.AutoMirrored.Rounded.Assignment,
        "Or answer three\nquick questions",
        "Tell Queasy what kind of queasy moment you are in and how strong it feels. It picks a mode, a level and a length, and shows you what each one leans on so you can judge it yourself.",
    ),
    OnboardPage(
        Icons.Rounded.PhoneAndroid,
        "Rest your phone on\nthe inside of your wrist",
        "For Pulse, hold the phone against the inside of your wrist, three finger-widths below the crease, where an acupressure band's stud sits. Breathe works wherever you can feel it.",
    ),
    OnboardPage(
        Icons.Rounded.Vibration,
        "Your phone does\nthe tapping",
        "Pulse and Breathe play through your phone's own vibration, and the screen stays on while a session runs. Tone needs headphones. Press times a hold you do with your own thumb.",
    ),
)

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun OnboardingScreen() {
    val graph = LocalGraph.current
    val pager = rememberPagerState { pages.size }
    val scope = rememberCoroutineScope()
    val last = pager.currentPage == pages.lastIndex

    Column(Modifier.fillMaxSize().background(Tide.tideWash).statusBarsPadding().navigationBarsPadding()) {
        HorizontalPager(pager, Modifier.weight(1f).fillMaxWidth()) { index ->
            Page(pages[index])
        }
        Row(Modifier.fillMaxWidth().padding(bottom = 16.dp), horizontalArrangement = Arrangement.Center) {
            pages.indices.forEach { i ->
                Box(
                    Modifier.padding(horizontal = 4.dp).size(7.dp)
                        .background(if (i == pager.currentPage) Tide.ink2 else Tide.ink3.copy(alpha = 0.35f), CircleShape),
                )
            }
        }
        Column(
            Modifier.padding(horizontal = 24.dp).padding(bottom = 14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            TideButton(
                text = if (last) "Get Started" else "Continue",
                onClick = {
                    if (last) graph.settings.completeOnboarding()
                    else scope.launch { pager.animateScrollToPage(pager.currentPage + 1) }
                },
                tag = "onboarding-continue",
            )
            Text(
                "Queasy is a set of comfort techniques, not a medical device. It does not diagnose, treat or cure anything, and it may not change how you feel. If symptoms are severe or persistent, talk to a doctor.",
                style = TideType.caption2,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun Page(page: OnboardPage) {
    Column(
        Modifier.fillMaxSize().padding(horizontal = 30.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(26.dp, Alignment.CenterVertically),
    ) {
        SymbolDisc(page.icon, size = 150.dp, iconSize = 60.dp)
        Text(page.title, style = TideType.display(30.sp).copy(lineHeight = 36.sp), textAlign = TextAlign.Center)
        Text(page.text, style = TideType.callout, textAlign = TextAlign.Center)
        Spacer(Modifier.size(40.dp))
    }
}
