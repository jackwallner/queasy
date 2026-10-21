package com.jackwallner.queasy

import android.app.Application
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.setValue
import com.jackwallner.queasy.data.AppSettings
import com.jackwallner.queasy.data.AtomicEpisodeFile
import com.jackwallner.queasy.data.ConversionDiagnostics
import com.jackwallner.queasy.data.EpisodeStore
import com.jackwallner.queasy.data.PressReminders
import com.jackwallner.queasy.data.ReviewPromptTracker
import com.jackwallner.queasy.data.SharedPreferencesStore
import com.jackwallner.queasy.data.SubscriptionService
import com.jackwallner.queasy.data.UpgradePromptTracker
import com.jackwallner.queasy.model.HapticPatterns
import com.jackwallner.queasy.model.NauseaCause
import com.jackwallner.queasy.model.ReliefMode
import com.jackwallner.queasy.session.AndroidHaptics
import com.jackwallner.queasy.session.AudioTonePlayer
import com.jackwallner.queasy.session.SessionController
import kotlinx.coroutines.MainScope

class QueasyApplication : Application() {
    lateinit var graph: AppGraph
        private set

    override fun onCreate() {
        super.onCreate()
        graph = AppGraph(this)
    }
}

/** Every long-lived object the screens share, built once per process. */
class AppGraph(context: Context) {
    val appContext: Context = context.applicationContext
    val scope = MainScope()
    val defaults = SharedPreferencesStore(appContext)
    val settings = AppSettings(defaults)
    val episodes = EpisodeStore(AtomicEpisodeFile(appContext.filesDir))
    val review = ReviewPromptTracker(defaults)
    val upgrades = UpgradePromptTracker(defaults)
    val diagnostics = ConversionDiagnostics(defaults)
    val subscriptions = SubscriptionService(appContext, defaults, diagnostics)
    val reminders = PressReminders(appContext, defaults)
    private val haptics = AndroidHaptics(appContext)
    val session = SessionController(
        haptics = haptics,
        tone = AudioTonePlayer(),
        episodes = episodes,
        scope = scope,
        breathWaveform = { if (haptics.hasAmplitudeControl) HapticPatterns.breath(it) else HapticPatterns.breathOnOff(it) },
    )
    val navigator = Navigator()
}

/** What sits over the tabs, top of the stack last. The iOS sheets and full-screen covers. */
sealed interface Overlay {
    data class CheckIn(val prefill: NauseaCause? = null) : Overlay
    data class ModeStart(val mode: ReliefMode) : Overlay
    data object Session : Overlay
    data class Paywall(val impressionId: String, val closable: Boolean = true) : Overlay
}

class Navigator {
    var tab by mutableIntStateOf(0)
    val overlays = mutableStateListOf<Overlay>()

    /** Bumped by a finished session the user didn't rate as worse; the root asks for a rating once clear. */
    var positiveMoments by mutableIntStateOf(0)
        private set

    fun recordPositiveMoment() {
        positiveMoments += 1
    }

    val top: Overlay? get() = overlays.lastOrNull()

    fun push(overlay: Overlay) {
        if (top != overlay) overlays.add(overlay)
    }

    fun pop() {
        if (overlays.isNotEmpty()) overlays.removeAt(overlays.lastIndex)
    }

    fun remove(overlay: Overlay) {
        overlays.remove(overlay)
    }

    /** A session starting from a sheet closes the sheet and covers the screen, as on iOS. */
    fun showSession() {
        overlays.removeAll { it is Overlay.CheckIn || it is Overlay.ModeStart }
        push(Overlay.Session)
    }
}
