package com.jackwallner.queasy.ui.screens

import androidx.activity.compose.LocalActivity
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Link
import androidx.compose.material.icons.rounded.PhoneAndroid
import androidx.compose.material.icons.rounded.WbTwilight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.jackwallner.queasy.DebugLaunchOptions
import com.jackwallner.queasy.content.LearnCard
import com.jackwallner.queasy.content.LearnContent
import com.jackwallner.queasy.ui.TideTopBar
import com.jackwallner.queasy.ui.openUrl
import com.jackwallner.queasy.ui.theme.Tide
import com.jackwallner.queasy.ui.theme.TideType
import com.jackwallner.queasy.ui.theme.icon
import com.jackwallner.queasy.ui.theme.tideCard

/** `LearnView.swift`: a list of topics, one open at a time, each expanding in place. */
@Composable
fun LearnScreen() {
    var expanded by remember { mutableStateOf(DebugLaunchOptions.learnCard) }
    Column(Modifier.fillMaxSize().background(Tide.tideWash)) {
        TideTopBar("Learn")
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 18.dp).padding(top = 4.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            LearnContent.cards.forEach { card ->
                LearnRow(card, expanded == card.id) { expanded = if (expanded == card.id) null else card.id }
            }
            Column(
                Modifier.fillMaxWidth().padding(top = 4.dp).background(Tide.paper3, RoundedCornerShape(16.dp)).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(Icons.Rounded.Info, null, tint = Tide.ink2, modifier = Modifier.size(18.dp))
                    Text("Not a medical device", style = TideType.subheadline.copy(fontWeight = FontWeight.SemiBold))
                }
                Text(LearnContent.DISCLAIMER, style = TideType.caption.copy(color = Tide.ink3))
            }
        }
    }
}

@Composable
private fun LearnRow(card: LearnCard, isExpanded: Boolean, onTap: () -> Unit) {
    val activity = LocalActivity.current
    val rotation by animateFloatAsState(if (isExpanded) 180f else 0f, label = "chevron")
    Column(
        Modifier
            .fillMaxWidth()
            .tideCard()
            .animateContentSize(spring(dampingRatio = 0.85f, stiffness = Spring.StiffnessMediumLow))
            .padding(Tide.cardPadding),
    ) {
        Row(
            Modifier.fillMaxWidth().clickable(role = Role.Button, onClick = onTap).testTag("learn-${card.id}"),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(Modifier.size(38.dp).background(Tide.aquaTint, CircleShape), contentAlignment = Alignment.Center) {
                Icon(
                    card.mode?.icon ?: if (card.id == "morning") Icons.Rounded.WbTwilight else Icons.Rounded.PhoneAndroid,
                    null,
                    tint = Tide.aqua,
                    modifier = Modifier.size(20.dp),
                )
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(card.title, style = TideType.headline)
                Text(card.hook, style = TideType.subheadline)
            }
            Icon(Icons.Rounded.ExpandMore, null, tint = Tide.ink3, modifier = Modifier.padding(top = 8.dp).rotate(rotation))
        }
        // Fade in place: a slide moves multiline text under the header while the card springs open.
        AnimatedVisibility(isExpanded, enter = fadeIn(), exit = fadeOut()) {
            Column(Modifier.padding(top = 12.dp, start = 50.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(card.detail, style = TideType.subheadline)
                if (card.sources.isNotEmpty()) {
                    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Text("Sources", style = TideType.caption.copy(fontWeight = FontWeight.SemiBold, color = Tide.ink3))
                        card.sources.forEach { source ->
                            Row(
                                Modifier.clickable(role = Role.Button) { activity?.openUrl(source.url) }.padding(vertical = 4.dp),
                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                            ) {
                                Icon(Icons.Rounded.Link, null, tint = Tide.aquaDeep, modifier = Modifier.size(16.dp))
                                Text(source.title, style = TideType.caption.copy(color = Tide.aquaDeep))
                            }
                        }
                    }
                }
            }
        }
    }
}
