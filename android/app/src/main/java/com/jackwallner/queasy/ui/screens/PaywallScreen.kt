package com.jackwallner.queasy.ui.screens

import androidx.activity.compose.LocalActivity
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.LockOpen
import androidx.compose.material.icons.rounded.NightsStay
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material.icons.rounded.Spa
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.WifiOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.queasy.content.Links
import com.jackwallner.queasy.data.PackageKind
import com.jackwallner.queasy.data.Plan
import com.jackwallner.queasy.data.PurchaseException
import com.jackwallner.queasy.data.PurchaseOutcome
import com.jackwallner.queasy.data.SubscriptionService
import com.jackwallner.queasy.data.capitalizeWords
import com.jackwallner.queasy.model.FreeTier
import com.jackwallner.queasy.model.PatternEngine
import com.jackwallner.queasy.model.ProFeature
import com.jackwallner.queasy.ui.LocalGraph
import com.jackwallner.queasy.ui.openUrl
import com.jackwallner.queasy.ui.theme.Tide
import com.jackwallner.queasy.ui.theme.TideButton
import com.jackwallner.queasy.ui.theme.TideType
import com.jackwallner.queasy.ui.theme.icon
import kotlinx.coroutines.launch

/**
 * `PaywallView.swift`: every price, period and trial comes from the store.
 * The Android copy differs only where Play does (where to cancel, no Apple EULA).
 */
@Composable
fun PaywallScreen(impressionId: String, closable: Boolean, onClose: () -> Unit) {
    val graph = LocalGraph.current
    val subs = graph.subscriptions
    var selectedId by remember { mutableStateOf<String?>(null) }
    val plans = subs.plans
    val selected = plans.firstOrNull { it.packageId == selectedId }

    LaunchedEffect(Unit) {
        subs.trackPaywallImpression(impressionId)
        if (subs.plans.isEmpty()) subs.fetchProducts()
    }
    LaunchedEffect(plans) {
        if (selectedId == null && plans.isNotEmpty()) {
            selectedId = (plans.firstOrNull { it.kind == PackageKind.YEARLY } ?: plans.first()).packageId
        }
    }
    LaunchedEffect(subs.isPro) { if (subs.isPro) onClose() }

    Box(Modifier.fillMaxSize().background(Tide.paper).statusBarsPadding().navigationBarsPadding().testTag("paywall")) {
        when {
            subs.isLoadingProducts && plans.isEmpty() -> Loading()
            plans.isEmpty() -> Empty()
            else -> Content(selected, onSelect = { selectedId = it.packageId }, closable = closable)
        }
        if (closable) {
            Box(
                Modifier.align(Alignment.TopEnd).padding(6.dp).size(44.dp).clip(CircleShape)
                    .clickable(role = Role.Button, onClick = onClose)
                    .semantics { contentDescription = "Close" }
                    .testTag("paywall-close"),
                contentAlignment = Alignment.Center,
            ) {
                Box(Modifier.size(30.dp).background(Tide.paper2, CircleShape), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Close, null, tint = Tide.ink2, modifier = Modifier.size(18.dp))
                }
            }
        }
    }
}

@Composable
private fun Loading() {
    Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterVertically)) {
        CircularProgressIndicator(color = Tide.aqua)
        Text("loading plans…", style = TideType.rounded(15.sp, FontWeight.Normal), color = Tide.ink2)
        LegalFooter(onRestoreMessage = {})
    }
}

@Composable
private fun Empty() {
    val graph = LocalGraph.current
    val scope = rememberCoroutineScope()
    Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically)) {
        Icon(Icons.Rounded.WifiOff, null, tint = Tide.ink3, modifier = Modifier.size(40.dp))
        Text("couldn't load plans", style = TideType.rounded(17.sp, FontWeight.Bold), color = Tide.ink2)
        Text(
            graph.subscriptions.lastError ?: "Check your connection and try again.",
            style = TideType.subheadline.copy(color = Tide.ink3),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 8.dp),
        )
        Text(
            "try again",
            style = TideType.rounded(15.sp, FontWeight.Bold),
            color = Tide.aqua,
            modifier = Modifier.clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) {
                scope.launch { graph.subscriptions.fetchProducts() }
            }.padding(12.dp).testTag("paywall-retry"),
        )
        LegalFooter(onRestoreMessage = {})
    }
}

@Composable
private fun Content(selected: Plan?, onSelect: (Plan) -> Unit, closable: Boolean) {
    val graph = LocalGraph.current
    val subs = graph.subscriptions
    val activity = LocalActivity.current
    val scope = rememberCoroutineScope()
    var purchasing by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var note by remember { mutableStateOf<String?>(null) }
    val trialLabel = selected?.takeIf { it.kind != PackageKind.LIFETIME && subs.isEligibleForIntroOffer(it) }?.introOfferLabel
    val yearly = subs.plans.firstOrNull { it.kind == PackageKind.YEARLY }
    val monthly = subs.plans.firstOrNull { it.kind == PackageKind.MONTHLY }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 22.dp)
            .padding(top = if (closable) 48.dp else 20.dp, bottom = 14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        // Header
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("QUEASY PRO", style = TideType.caption2.copy(fontWeight = FontWeight.SemiBold, letterSpacing = 2.sp))
            val headlinePlan = selected ?: yearly
            val headlineTrial = headlinePlan?.takeIf { subs.isEligibleForIntroOffer(it) }?.introOfferLabel
            Text(
                if (headlineTrial != null) "Try Queasy Pro\n$headlineTrial." else "Sessions as long as\nyou actually need.",
                style = TideType.display(26.sp).copy(lineHeight = 31.sp),
                modifier = Modifier.testTag("paywall-headline"),
            )
            Text(
                if (selected != null && trialLabel != null) "Then ${selected.priceLabel}, cancel anytime."
                else "Free sessions run ${FreeTier.SESSION_SECONDS / 60} minutes. Pro runs up to ${PatternEngine.MAX_DURATION}.",
                style = TideType.footnote,
            )
        }
        TrustStrip()
        if (trialLabel != null) TrialTimeline(trialLabel) else FeatureList()

        subs.plans.forEach { plan ->
            PlanCard(
                plan = plan,
                isSelected = plan.packageId == selected?.packageId,
                showsTrial = subs.isEligibleForIntroOffer(plan),
                savings = plan.savingsPercent(monthly),
                onTap = { onSelect(plan) },
            )
        }

        Spacer(Modifier.height(4.dp))
        if (trialLabel != null) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.CheckCircle, null, tint = Tide.aqua, modifier = Modifier.size(14.dp))
                Text(" No payment due now", style = TideType.caption.copy(fontWeight = FontWeight.SemiBold, color = Tide.ink))
            }
        }
        TideButton(
            text = when {
                selected == null -> "Continue"
                selected.kind == PackageKind.LIFETIME -> "Unlock Lifetime"
                trialLabel != null -> "Start My ${trialLabel.capitalizeWords()}"
                else -> "Start Queasy Pro"
            },
            enabled = selected != null && !purchasing,
            tag = "paywall-cta",
            onClick = {
                val plan = selected ?: return@TideButton
                val host = activity ?: return@TideButton
                error = null
                note = null
                purchasing = true
                scope.launch {
                    try {
                        when (subs.purchase(host, plan)) {
                            PurchaseOutcome.PURCHASED -> Unit
                            PurchaseOutcome.PENDING -> note = SubscriptionService.PENDING_MESSAGE
                            PurchaseOutcome.CANCELLED -> Unit
                        }
                    } catch (e: PurchaseException) {
                        error = e.message
                    } finally {
                        purchasing = false
                    }
                }
            },
            content = if (purchasing) ({ CircularProgressIndicator(color = Color.White, modifier = Modifier.size(22.dp), strokeWidth = 2.dp) }) else null,
        )
        selected?.let { plan ->
            Text(
                disclosure(plan, trialLabel),
                style = TideType.caption2,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().heightIn(min = 44.dp).testTag("paywall-disclosure"),
            )
        }
        error?.let { Text(it, style = TideType.caption.copy(color = Tide.coral), textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth()) }
        note?.let { Text(it, style = TideType.caption, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth()) }
        LegalFooter(onRestoreMessage = { note = it })
    }
}

/** Plan name, price and period, trial and what follows it, auto-renewal, and where to cancel. */
fun disclosure(plan: Plan, trialLabel: String?): String {
    if (plan.kind == PackageKind.LIFETIME) return "${plan.priceLabel}. One-time purchase. Lifetime access, no subscription."
    return if (trialLabel != null) "${trialLabel.capitalizeWords()}, then ${plan.priceLabel}. ${SubscriptionService.AUTO_RENEW_DISCLOSURE}"
    else "${plan.priceLabel}. ${SubscriptionService.AUTO_RENEW_DISCLOSURE}"
}

@Composable
private fun TrustStrip() {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
        TrustItem(Icons.Rounded.Spa, "Drug-free")
        Box(Modifier.width(1.dp).height(14.dp).background(Tide.ink3.copy(alpha = 0.3f)))
        TrustItem(Icons.Rounded.Shield, "Private")
        Box(Modifier.width(1.dp).height(14.dp).background(Tide.ink3.copy(alpha = 0.3f)))
        TrustItem(Icons.Rounded.NightsStay, "No ads, ever")
    }
}

@Composable
private fun TrustItem(icon: ImageVector, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        Icon(icon, null, tint = Tide.aqua, modifier = Modifier.size(13.dp))
        Text(label, style = TideType.caption2.copy(fontWeight = FontWeight.Medium, color = Tide.ink2))
    }
}

@Composable
private fun TrialTimeline(trialLabel: String) {
    Column(Modifier.fillMaxWidth().background(Tide.aquaTint.copy(alpha = 0.5f), RoundedCornerShape(16.dp)).padding(14.dp)) {
        TimelineRow(Icons.Rounded.LockOpen, "Today", "Unlock full-length sessions and your whole history, free.", true)
        TimelineRow(Icons.Rounded.Notifications, "Day 5", "Check History. How do you feel?", true)
        TimelineRow(Icons.Rounded.Star, if ("7" in trialLabel) "Day 7" else "Trial ends", "First charge, only if you keep it. Cancel before then and pay nothing.", false)
    }
}

@Composable
private fun TimelineRow(icon: ImageVector, title: String, text: String, showsLine: Boolean) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Box(Modifier.size(24.dp).background(Tide.aqua, CircleShape), contentAlignment = Alignment.Center) {
                Icon(icon, null, tint = Color.White, modifier = Modifier.size(13.dp))
            }
            if (showsLine) Box(Modifier.width(2.dp).height(14.dp).background(Tide.aqua.copy(alpha = 0.35f), RoundedCornerShape(1.dp)))
        }
        Column(Modifier.padding(bottom = if (showsLine) 6.dp else 0.dp), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Text(title, style = TideType.caption.copy(fontWeight = FontWeight.Bold, color = Tide.ink))
            Text(text, style = TideType.caption2.copy(color = Tide.ink2))
        }
    }
}

/** Driven off [ProFeature], so the bullets and the gates cannot drift. */
@Composable
private fun FeatureList() {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        ProFeature.entries.forEach { feature ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon(feature.icon, null, tint = Tide.aqua, modifier = Modifier.width(24.dp).size(18.dp))
                Text(feature.title, style = TideType.subheadline.copy(color = Tide.ink))
            }
        }
        Text(
            "Every mode stays free, unlimited, with no account. Pro buys length, memory and reminders. Queasy is a set of comfort techniques, not a medical device, and it makes no treatment claims.",
            style = TideType.caption2,
            modifier = Modifier.padding(top = 2.dp),
        )
    }
}

@Composable
private fun PlanCard(plan: Plan, isSelected: Boolean, showsTrial: Boolean, savings: Int?, onTap: () -> Unit) {
    val shape = RoundedCornerShape(14.dp)
    val secondary = buildList {
        if (showsTrial) plan.introOfferLabel?.let { add(it.capitalizeWords()) }
        plan.perMonthLabel?.let { add(it) }
    }.joinToString(" · ").ifEmpty { if (plan.kind == PackageKind.LIFETIME) "Pay once · never renews" else "" }
    Row(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Tide.paper2)
            .border(if (isSelected) 2.dp else 1.dp, if (isSelected) Tide.aqua else Tide.paper3, shape)
            .clickable(role = Role.RadioButton, onClick = onTap)
            .semantics { this.selected = isSelected }
            .testTag("plan-${plan.kind.name.lowercase()}")
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(Modifier.size(22.dp).border(2.dp, if (isSelected) Tide.aqua else Tide.ink3.copy(alpha = 0.4f), CircleShape), contentAlignment = Alignment.Center) {
            if (isSelected) Box(Modifier.size(12.dp).background(Tide.aqua, CircleShape))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(plan.displayName, style = TideType.subheadline.copy(fontWeight = FontWeight.SemiBold, color = Tide.ink))
                val badge = savings?.let { "SAVE $it%" } ?: if (plan.kind == PackageKind.YEARLY) "BEST VALUE" else null
                badge?.let {
                    Text(
                        it,
                        style = TideType.rounded(9.sp, FontWeight.Bold),
                        color = Color.White,
                        modifier = Modifier.background(Tide.aqua, CircleShape).padding(horizontal = 6.dp, vertical = 2.dp),
                    )
                }
            }
            if (secondary.isNotEmpty()) Text(secondary, style = TideType.caption2.copy(fontWeight = FontWeight.Medium))
        }
        Text(plan.priceLabel, style = TideType.subheadline.copy(fontWeight = FontWeight.SemiBold, color = Tide.ink))
    }
}

/** Restore and the legal links, in every paywall state. */
@Composable
private fun LegalFooter(onRestoreMessage: (String) -> Unit) {
    val graph = LocalGraph.current
    val activity = LocalActivity.current
    val scope = rememberCoroutineScope()
    var restoring by remember { mutableStateOf(false) }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
        FooterLink(if (restoring) "Restoring…" else "Restore Purchases", Tide.ink2, "paywall-restore") {
            if (restoring) return@FooterLink
            restoring = true
            scope.launch {
                graph.subscriptions.restorePurchases()
                if (!graph.subscriptions.isPro) onRestoreMessage(graph.subscriptions.lastError ?: "No purchases found to restore.")
                restoring = false
            }
        }
        FooterLink("Terms of Use", Tide.ink3, "paywall-terms") { activity?.openUrl(Links.TERMS) }
        FooterLink("Privacy Policy", Tide.ink3, "paywall-privacy") { activity?.openUrl(Links.PRIVACY) }
    }
}

@Composable
private fun FooterLink(text: String, color: Color, tag: String, onClick: () -> Unit) {
    Text(
        text,
        style = TideType.caption2.copy(fontWeight = FontWeight.SemiBold, color = color),
        modifier = Modifier.clip(RoundedCornerShape(8.dp)).clickable(role = Role.Button, onClick = onClick).padding(vertical = 12.dp, horizontal = 2.dp).testTag(tag),
    )
}
