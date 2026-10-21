package com.jackwallner.queasy.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.UnfoldMore
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import com.jackwallner.queasy.BuildConfig
import com.jackwallner.queasy.Overlay
import com.jackwallner.queasy.content.Links
import com.jackwallner.queasy.model.BreathePattern
import com.jackwallner.queasy.model.FreeTier
import com.jackwallner.queasy.ui.LocalGraph
import com.jackwallner.queasy.ui.TideTopBar
import com.jackwallner.queasy.ui.openUrl
import com.jackwallner.queasy.ui.theme.Tide
import com.jackwallner.queasy.ui.theme.TideType
import kotlinx.coroutines.launch

/** `SettingsView.swift`, as grouped cards. The iOS watch pulse cap has no Android counterpart. */
@Composable
fun SettingsScreen() {
    val graph = LocalGraph.current
    val settings = graph.settings
    val subscriptions = graph.subscriptions
    val reminders = graph.reminders
    val context = LocalContext.current
    val activity = LocalActivity.current
    val scope = rememberCoroutineScope()
    var restoring by remember { mutableStateOf(false) }
    var restoreMessage by remember { mutableStateOf<String?>(null) }
    var showReviewCode by remember { mutableStateOf(false) }

    // Reminders are Pro: a lapsed subscription stops them, the preference stays for a resubscribe.
    LaunchedEffect(subscriptions.isPro) {
        if (subscriptions.isPro) reminders.refresh() else reminders.suspendForNonSubscriber()
    }

    Column(Modifier.fillMaxSize().background(Tide.tideWash)) {
        TideTopBar("Settings")
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 18.dp).padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Section(
                "Session",
                footer = if (!subscriptions.isPro) {
                    "Pulse and Breathe run ${FreeTier.SESSION_SECONDS / 60} minutes on the free plan, however long you set here. Tone and Press always run their full length."
                } else null,
            ) {
                PickerRow(
                    "Session length",
                    options = listOf<Int?>(null, 10, 15, 20, 30),
                    selected = settings.defaultDurationMinutes,
                    label = { it?.let { m -> "$m minutes" } ?: "Match my symptoms" },
                    tag = "setting-length",
                    onSelect = settings::updateDefaultDuration,
                )
                RowDivider()
                PickerRow(
                    "Breathing rhythm",
                    options = listOf<Int?>(null) + BreathePattern.ALL.indices,
                    selected = settings.defaultBreatheIndex,
                    label = { it?.let { i -> BreathePattern.ALL[i].label } ?: "Match my symptoms" },
                    tag = "setting-rhythm",
                    onSelect = settings::updateDefaultBreatheIndex,
                )
            }

            Section(
                "Press",
                footer = when {
                    reminders.authorizationDenied -> "Notifications are off for Queasy. Turn them on in Android Settings to use reminders."
                    subscriptions.isPro -> "A nudge at ${reminders.scheduleLabel} to run a three-minute hold, the way the wristband trials spaced them."
                    else -> "Queasy Pro nudges you a few times a day to run a hold, the way the wristband trials spaced them."
                },
            ) {
                ToggleRow("Press reminders", reminders.isEnabled && subscriptions.isPro, tag = "press-reminders") { wanted ->
                    if (!subscriptions.isPro) graph.navigator.push(Overlay.Paywall("queasy_settings"))
                    else scope.launch { reminders.setEnabled(wanted) }
                }
            }

            Section("History", footer = "Shows a day-by-day grid on the History tab.") {
                ToggleRow("Calendar heatmap", settings.showHistoryHeatmap, tag = "setting-heatmap", onChange = settings::updateShowHistoryHeatmap)
            }

            Section("Queasy Pro") {
                if (subscriptions.isPro) {
                    Row(Modifier.heightIn(min = 48.dp).padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Rounded.Verified, null, tint = Tide.aqua, modifier = Modifier.size(20.dp))
                        Text("Active", style = TideType.body.copy(color = Tide.aqua), modifier = Modifier.testTag("pro-active"))
                    }
                    if (!subscriptions.hasReviewAccess) {
                        RowDivider()
                        LinkRow("Manage subscription") { activity?.openUrl(Links.manageSubscription(null)) }
                    }
                } else {
                    LinkRow("See Queasy Pro", color = Tide.aqua, icon = { Icon(Icons.Rounded.AutoAwesome, null, tint = Tide.aqua, modifier = Modifier.size(20.dp)) }, tag = "settings-see-pro") {
                        graph.navigator.push(Overlay.Paywall("queasy_settings"))
                    }
                }
                RowDivider()
                LinkRow(if (restoring) "Restoring…" else "Restore Purchases", tag = "settings-restore") {
                    if (restoring) return@LinkRow
                    restoring = true
                    restoreMessage = null
                    scope.launch {
                        subscriptions.restorePurchases()
                        restoreMessage = if (subscriptions.isPro) "Restored." else subscriptions.lastError ?: "No purchases found."
                        restoring = false
                    }
                }
                restoreMessage?.let {
                    Text(it, style = TideType.caption.copy(color = Tide.ink3), modifier = Modifier.padding(horizontal = 16.dp).padding(bottom = 12.dp))
                }
            }

            Section("About") {
                // Separate rating and feedback rows, with no question in front of either.
                LinkRow("Rate Queasy", tag = "settings-rate") {
                    graph.review.markOpenedWriteReview()
                    activity?.openUrl(Links.PLAY_LISTING)
                }
                RowDivider()
                LinkRow("Send Feedback", tag = "settings-feedback") {
                    graph.review.markFeedbackSubmitted()
                    runCatching {
                        context.startActivity(Intent(Intent.ACTION_SENDTO, ("mailto:${Links.SUPPORT_EMAIL}?subject=" + Uri.encode("Queasy feedback (Android)")).toUri()))
                    }
                }
                RowDivider()
                LinkRow("Privacy Policy") { activity?.openUrl(Links.PRIVACY) }
                RowDivider()
                LinkRow("Terms of Use") { activity?.openUrl(Links.TERMS) }
                RowDivider()
                VersionRow(onLongPress = { showReviewCode = true })
            }

            Text(
                "Queasy is a set of comfort techniques you run yourself, not a medical device, and it holds no clearance. It does not diagnose, treat, cure or prevent anything, and it may not change how you feel. If nausea is severe or persistent, talk to a doctor.",
                style = TideType.caption.copy(color = Tide.ink3),
                modifier = Modifier.padding(horizontal = 4.dp, vertical = 12.dp),
            )

            if (BuildConfig.DEBUG) {
                Section("Debug") {
                    ToggleRow("Pro override", subscriptions.isPro, tag = "debug-pro") { subscriptions.setLocalOverride(it) }
                }
            }
        }
    }

    if (showReviewCode) ReviewCodeDialog(onDismiss = { showReviewCode = false })
}

@Composable
private fun Section(title: String, footer: String? = null, content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.padding(top = 14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title.uppercase(), style = TideType.caption.copy(color = Tide.ink3), modifier = Modifier.padding(horizontal = 16.dp))
        Column(Modifier.fillMaxWidth().background(Tide.paper2, RoundedCornerShape(14.dp)), content = content)
        footer?.let { Text(it, style = TideType.caption.copy(color = Tide.ink3), modifier = Modifier.padding(horizontal = 16.dp)) }
    }
}

@Composable
private fun RowDivider() = HorizontalDivider(Modifier.padding(start = 16.dp), color = Tide.ink.copy(alpha = 0.08f))

@Composable
private fun LinkRow(title: String, color: Color = Tide.ink, tag: String? = null, icon: (@Composable () -> Unit)? = null, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(role = Role.Button, onClick = onClick)
            .then(if (tag != null) Modifier.testTag(tag) else Modifier).padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        icon?.invoke()
        Text(title, style = TideType.body.copy(color = color))
    }
}

@Composable
private fun ToggleRow(title: String, checked: Boolean, tag: String, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(role = Role.Switch) { onChange(!checked) }.padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = TideType.body, modifier = Modifier.weight(1f))
        Switch(
            checked = checked,
            onCheckedChange = onChange,
            modifier = Modifier.testTag(tag),
            colors = SwitchDefaults.colors(checkedTrackColor = Tide.aqua, checkedThumbColor = Color.White),
        )
    }
}

@Composable
private fun <T> PickerRow(title: String, options: List<T>, selected: T, label: (T) -> String, tag: String, onSelect: (T) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(role = Role.DropdownList) { open = true }.testTag(tag).padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(title, style = TideType.body, modifier = Modifier.weight(1f))
            Text(label(selected), style = TideType.body.copy(color = Tide.ink2))
            Icon(Icons.Rounded.UnfoldMore, null, tint = Tide.ink3, modifier = Modifier.padding(start = 4.dp).size(18.dp))
        }
        DropdownMenu(open, onDismissRequest = { open = false }, modifier = Modifier.background(Tide.paper2)) {
            options.forEach { option ->
                DropdownMenuItem(
                    text = { Text(label(option), fontWeight = if (option == selected) FontWeight.SemiBold else FontWeight.Normal) },
                    onClick = {
                        onSelect(option)
                        open = false
                    },
                )
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun VersionRow(onLongPress: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 48.dp)
            .combinedClickable(onClick = {}, onLongClick = onLongPress, onLongClickLabel = "Enter a review code")
            .testTag("settings-version").padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("Version", style = TideType.body, modifier = Modifier.weight(1f))
        Text("${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})", style = TideType.body.copy(color = Tide.ink2))
    }
}

/** Play reviewers unlock Pro with a code from App access; the app ships only its SHA-256. */
@OptIn(ExperimentalComposeUiApi::class)
@Composable
private fun ReviewCodeDialog(onDismiss: () -> Unit) {
    val graph = LocalGraph.current
    var code by remember { mutableStateOf("") }
    var failed by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Review access") },
        text = {
            // A dialog is its own window: test tags need re-exposing as resource ids here.
            Column(Modifier.semantics { testTagsAsResourceId = true }, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Enter the code from the Play Console app access instructions.", style = TideType.footnote)
                OutlinedTextField(
                    value = code,
                    onValueChange = { code = it; failed = false },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    isError = failed,
                    modifier = Modifier.testTag("review-code-field"),
                )
                if (failed) Text("That code didn't match.", style = TideType.caption.copy(color = Tide.coral))
            }
        },
        confirmButton = {
            TextButton(onClick = {
                if (graph.subscriptions.activateReviewAccess(code)) onDismiss() else failed = true
            }, modifier = Modifier.testTag("review-code-submit")) { Text("Unlock") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}
