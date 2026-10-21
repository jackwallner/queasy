package com.jackwallner.queasy.ui

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.MenuBook
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Vibration
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.key
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.android.play.core.review.ReviewManagerFactory
import com.jackwallner.queasy.AppGraph
import com.jackwallner.queasy.Overlay
import com.jackwallner.queasy.ui.screens.CheckInScreen
import com.jackwallner.queasy.ui.screens.HistoryScreen
import com.jackwallner.queasy.ui.screens.LearnScreen
import com.jackwallner.queasy.ui.screens.ModeStartScreen
import com.jackwallner.queasy.ui.screens.OnboardingScreen
import com.jackwallner.queasy.ui.screens.PaywallScreen
import com.jackwallner.queasy.ui.screens.RelieveHomeScreen
import com.jackwallner.queasy.ui.screens.SessionScreen
import com.jackwallner.queasy.ui.screens.SettingsScreen
import com.jackwallner.queasy.ui.theme.Tide
import com.jackwallner.queasy.ui.theme.TideType
import kotlinx.coroutines.delay

val LocalGraph = staticCompositionLocalOf<AppGraph> { error("AppGraph not provided") }

/** Onboarding, or the four tabs with their sheets on top. No paywall on the way in. */
@Composable
fun RootScreen(activity: Activity) {
    val graph = LocalGraph.current
    Box(Modifier.fillMaxSize().background(Tide.paper)) {
        if (!graph.settings.hasCompletedOnboarding) {
            OnboardingScreen()
        } else {
            // Under a sheet the tabs are neither readable by TalkBack nor tappable.
            val covered = graph.navigator.overlays.isNotEmpty()
            Box(if (covered) Modifier.clearAndSetSemantics {} else Modifier) { Tabs(graph) }
            Overlays(graph)
        }
        graph.episodes.saveFailure?.let { message ->
            AlertDialog(
                onDismissRequest = { graph.episodes.saveFailure = null },
                confirmButton = { TextButton(onClick = { graph.episodes.saveFailure = null }) { Text("OK") } },
                title = { Text("Not saved") },
                text = { Text(message) },
            )
        }
    }
    // Ask for a rating the moment the session cover has closed, if nothing else is up.
    LaunchedEffect(graph.navigator.overlays.size, graph.navigator.positiveMoments) {
        if (graph.navigator.positiveMoments == 0 || graph.navigator.overlays.isNotEmpty()) return@LaunchedEffect
        delay(3_000)
        if (graph.navigator.overlays.isNotEmpty()) return@LaunchedEffect
        if (!graph.review.shouldRequestAfterPositiveMoment(graph.settings.hasCompletedOnboarding)) return@LaunchedEffect
        graph.review.markShown()
        requestPlayReview(activity)
    }
}

/** Play's In-App Review card, with no question in front of it. Quota may silently show nothing. */
private fun requestPlayReview(activity: Activity) {
    val manager = ReviewManagerFactory.create(activity)
    manager.requestReviewFlow().addOnCompleteListener { request ->
        if (request.isSuccessful) manager.launchReviewFlow(activity, request.result)
    }
}

fun Activity.openUrl(url: String) {
    runCatching { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
}

@Composable
private fun Tabs(graph: AppGraph) {
    val nav = graph.navigator
    BackHandler(enabled = nav.tab != 0 && nav.overlays.isEmpty()) { nav.tab = 0 }
    Column(Modifier.fillMaxSize()) {
        Box(Modifier.weight(1f).fillMaxWidth()) {
            when (nav.tab) {
                0 -> RelieveHomeScreen()
                1 -> HistoryScreen()
                2 -> LearnScreen()
                else -> SettingsScreen()
            }
        }
        NavigationBar(containerColor = Tide.paper2, tonalElevation = 0.dp) {
            TabItems.forEachIndexed { index, item ->
                NavigationBarItem(
                    selected = nav.tab == index,
                    onClick = { nav.tab = index },
                    icon = { Icon(item.icon, null) },
                    label = { Text(item.title) },
                    modifier = Modifier.testTag("tab-${item.title.lowercase()}"),
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = Tide.aqua,
                        selectedTextColor = Tide.aquaDeep,
                        indicatorColor = Tide.aquaTint,
                        unselectedIconColor = Tide.ink3,
                        unselectedTextColor = Tide.ink3,
                    ),
                )
            }
        }
    }
}

private data class TabItem(val title: String, val icon: ImageVector)

private val TabItems = listOf(
    TabItem("Relieve", Icons.Rounded.Vibration),
    TabItem("History", Icons.Rounded.History),
    TabItem("Learn", Icons.AutoMirrored.Rounded.MenuBook),
    TabItem("Settings", Icons.Rounded.Settings),
)

/** Every overlay in the stack, drawn bottom to top; each slides up like an iOS sheet. */
@Composable
private fun Overlays(graph: AppGraph) {
    val nav = graph.navigator
    nav.overlays.forEachIndexed { index, overlay ->
        key(overlay) { OverlayHost(overlay, isTop = index == nav.overlays.lastIndex) }
    }
}

@Composable
private fun OverlayHost(overlay: Overlay, isTop: Boolean) {
    val graph = LocalGraph.current
    // Registered before the content so a screen's own back handling (check-in steps) wins.
    // Back leaves a running session going; the Relieve tab's card brings it back.
    BackHandler(enabled = isTop) { graph.navigator.remove(overlay) }
    // Slides up like an iOS sheet; removal is immediate so back never waits on an animation.
    val visible = remember { MutableTransitionState(false).apply { targetState = true } }
    AnimatedVisibility(visibleState = visible, enter = slideInVertically(tween(320)) { it / 4 } + fadeIn(tween(220))) {
        Box(Modifier.fillMaxSize().background(Tide.paper).blockTouchesBelow()) {
            when (overlay) {
                is Overlay.CheckIn -> CheckInScreen(overlay.prefill, onClose = { graph.navigator.remove(overlay) })
                is Overlay.ModeStart -> ModeStartScreen(overlay.mode, onClose = { graph.navigator.remove(overlay) })
                is Overlay.Session -> SessionScreen(onClose = { graph.navigator.remove(overlay) })
                is Overlay.Paywall -> PaywallScreen(overlay.impressionId, overlay.closable, onClose = { graph.navigator.remove(overlay) })
            }
        }
    }
}

/** A sheet swallows every touch its content leaves unhandled, so nothing reaches the tabs behind it. */
private fun Modifier.blockTouchesBelow() = pointerInput(Unit) {
    awaitPointerEventScope {
        while (true) awaitPointerEvent().changes.forEach { it.consume() }
    }
}

/** The iOS inline navigation title: ritual serif, centred, on every tab. */
@Composable
fun TideTopBar(title: String, modifier: Modifier = Modifier, leading: @Composable (() -> Unit)? = null, trailing: @Composable (() -> Unit)? = null) {
    Box(modifier.fillMaxWidth().statusBarsPadding().height(52.dp).padding(horizontal = 8.dp)) {
        Text(title, style = TideType.display(22.sp), textAlign = TextAlign.Center, modifier = Modifier.align(Alignment.Center))
        if (leading != null) Row(Modifier.align(Alignment.CenterStart)) { leading() }
        if (trailing != null) Row(Modifier.align(Alignment.CenterEnd)) { trailing() }
    }
}
