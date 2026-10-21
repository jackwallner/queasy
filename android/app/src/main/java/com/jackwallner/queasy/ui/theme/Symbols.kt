package com.jackwallner.queasy.ui.theme

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ShowChart
import androidx.compose.material.icons.rounded.Air
import androidx.compose.material.icons.rounded.DirectionsCar
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material.icons.rounded.MedicalServices
import androidx.compose.material.icons.rounded.NotificationsActive
import androidx.compose.material.icons.rounded.Psychology
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material.icons.rounded.Tornado
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.Vibration
import androidx.compose.material.icons.rounded.WbTwilight
import androidx.compose.material.icons.rounded.WineBar
import androidx.compose.ui.graphics.vector.ImageVector
import com.jackwallner.queasy.model.NauseaCause
import com.jackwallner.queasy.model.ProFeature
import com.jackwallner.queasy.model.ReliefMode

/** Material Symbols standing in for the iOS SF Symbols, one per concept. */
val ReliefMode.icon: ImageVector
    get() = when (this) {
        ReliefMode.PULSE -> Icons.Rounded.Vibration
        ReliefMode.BREATHE -> Icons.Rounded.Air
        ReliefMode.TONE -> Icons.Rounded.GraphicEq
        ReliefMode.PRESS -> Icons.Rounded.TouchApp
    }

val NauseaCause.icon: ImageVector
    get() = when (this) {
        NauseaCause.MOTION -> Icons.Rounded.DirectionsCar
        NauseaCause.MORNING_SICKNESS -> Icons.Rounded.WbTwilight
        NauseaCause.HANGOVER -> Icons.Rounded.WineBar
        NauseaCause.VERTIGO -> Icons.Rounded.Tornado
        NauseaCause.ANXIETY -> Icons.Rounded.Psychology
        NauseaCause.GENERAL -> Icons.Rounded.MedicalServices
    }

val ProFeature.icon: ImageVector
    get() = when (this) {
        ProFeature.FULL_LENGTH_SESSIONS -> Icons.Rounded.Timer
        ProFeature.FULL_HISTORY -> Icons.AutoMirrored.Rounded.ShowChart
        ProFeature.OWN_RHYTHM -> Icons.Rounded.Tune
        ProFeature.PRESS_REMINDERS -> Icons.Rounded.NotificationsActive
    }
