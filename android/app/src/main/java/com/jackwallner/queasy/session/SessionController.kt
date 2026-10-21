package com.jackwallner.queasy.session

import android.content.Context
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.queasy.data.EpisodeStore
import com.jackwallner.queasy.model.BreathePattern
import com.jackwallner.queasy.model.EpisodeSource
import com.jackwallner.queasy.model.HapticPatterns
import com.jackwallner.queasy.model.PatternEngine
import com.jackwallner.queasy.model.PulseSpec
import com.jackwallner.queasy.model.ReliefEpisode
import com.jackwallner.queasy.model.ReliefMode
import com.jackwallner.queasy.model.ReliefPlan
import com.jackwallner.queasy.model.Waveform
import java.time.Instant
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/** The vibration motor, behind an interface so the session logic tests on the JVM. */
interface Haptics {
    val isAvailable: Boolean
    fun play(waveform: Waveform, repeat: Boolean)
    fun stop()
}

class AndroidHaptics(context: Context) : Haptics {
    private val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= 31) {
        context.getSystemService(VibratorManager::class.java)?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Vibrator::class.java)
    }

    override val isAvailable: Boolean get() = vibrator?.hasVibrator() == true

    val hasAmplitudeControl: Boolean get() = vibrator?.hasAmplitudeControl() == true

    override fun play(waveform: Waveform, repeat: Boolean) {
        val vibrator = vibrator ?: return
        val amplitudes = if (hasAmplitudeControl) waveform.amplitudes else waveform.amplitudes.map { if (it > 0) 255 else 0 }.toIntArray()
        val effect = VibrationEffect.createWaveform(waveform.timings, amplitudes, if (repeat) 0 else -1)
        // Media usage: this is playback the user started, governed by the media-vibration setting.
        if (Build.VERSION.SDK_INT >= 33) {
            vibrator.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_MEDIA))
        } else {
            vibrator.vibrate(effect)
        }
    }

    override fun stop() {
        vibrator?.cancel()
    }
}

/** The 100 Hz tone, behind an interface for the same reason. */
interface TonePlayer {
    fun start()
    fun stop()
}

class AudioTonePlayer : TonePlayer {
    private val generator = ToneGenerator()
    override fun start() = generator.start()
    override fun stop() = generator.stop()
}

/**
 * Runs a session on the phone. Pulse and Breathe come out of the vibration
 * motor, Tone out of the speaker or headphones, and Press is a timer for
 * pressure you apply yourself. Ports `PhoneSessionController.swift`.
 */
class SessionController(
    private val haptics: Haptics,
    private val tone: TonePlayer,
    private val episodes: EpisodeStore,
    private val scope: CoroutineScope,
    private val clock: () -> Instant = Instant::now,
    /** On/off motors can't swell, so Breathe falls back to start-of-phase taps. */
    private val breathWaveform: (BreathePattern) -> Waveform = HapticPatterns::breath,
) {
    enum class Phase { IDLE, RUNNING, RATING }

    var phase by mutableStateOf(Phase.IDLE)
        private set
    var plan by mutableStateOf(ReliefPlan.QUICK_START)
        private set
    var intensity by mutableIntStateOf(5)
        private set
    var startedAt: Instant by mutableStateOf(Instant.EPOCH)
        private set
    var remainingSeconds by mutableIntStateOf(0)
        private set
    var totalSeconds by mutableIntStateOf(0)
        private set
    var toneEnabled by mutableStateOf(false)
        private set

    val mode: ReliefMode get() = plan.mode
    val hapticsAvailable: Boolean get() = haptics.isAvailable

    private var sessionUuid = UUID.randomUUID().toString()
    private var ticker: Job? = null

    /** [seconds] is the length actually granted, after the free-tier cap. */
    fun start(plan: ReliefPlan, seconds: Int? = null) {
        if (phase == Phase.RUNNING) return
        this.plan = plan
        intensity = plan.intensity
        startedAt = clock()
        sessionUuid = UUID.randomUUID().toString()
        totalSeconds = seconds ?: (plan.durationMinutes * 60)
        remainingSeconds = totalSeconds
        phase = Phase.RUNNING
        startPattern()
        startTicking()
        if (plan.mode == ReliefMode.TONE || toneEnabled) tone.start()
    }

    fun adjustIntensity(delta: Int) {
        if (phase != Phase.RUNNING || mode != ReliefMode.PULSE) return
        val next = (intensity + delta).coerceIn(PatternEngine.MIN_INTENSITY, PatternEngine.MAX_INTENSITY)
        if (next == intensity) return
        intensity = next
        startPattern()
    }

    fun updateToneEnabled(enabled: Boolean) {
        toneEnabled = enabled
        if (phase != Phase.RUNNING || mode == ReliefMode.TONE) return
        if (enabled) tone.start() else tone.stop()
    }

    /**
     * Stops the outputs and moves to the rating step. The episode is saved
     * unrated right away so History still has it if the rating never happens.
     */
    fun finish() {
        if (phase != Phase.RUNNING) return
        stopOutputs()
        phase = Phase.RATING
        persist(null)
    }

    /** Rating completed (or skipped with null): updates the saved episode. */
    fun complete(severityAfter: Int?): ReliefEpisode {
        val episode = persist(severityAfter)
        phase = Phase.IDLE
        return episode
    }

    fun cancel() {
        val elapsed = clock().toEpochMilli() - startedAt.toEpochMilli()
        val wasRunning = phase == Phase.RUNNING
        stopOutputs()
        // A real session that gets cancelled still belongs in History.
        if (wasRunning && elapsed >= MIN_RECORDED_MS) persist(null)
        phase = Phase.IDLE
    }

    /** Wall-clock countdown, so a paused frame never stretches the session. */
    internal fun tick() {
        if (phase != Phase.RUNNING) return
        val elapsed = ((clock().toEpochMilli() - startedAt.toEpochMilli()) / 1000).toInt()
        remainingSeconds = maxOf(totalSeconds - elapsed, 0)
        if (remainingSeconds <= 0) {
            if (mode == ReliefMode.PRESS) haptics.play(HapticPatterns.marker, repeat = false)
            finish()
        }
    }

    private fun persist(severityAfter: Int?): ReliefEpisode {
        val existing = episodes.episodes.firstOrNull { it.uuid == sessionUuid }
        val episode = existing?.copy(severityAfter = severityAfter, intensity = intensity) ?: ReliefEpisode(
            uuid = sessionUuid,
            startedAt = startedAt,
            endedAt = clock(),
            causeRaw = plan.cause.raw,
            severityBefore = plan.severityBefore,
            severityAfter = severityAfter,
            intensity = intensity,
            plannedMinutes = maxOf(totalSeconds / 60, 1),
            sourceRaw = EpisodeSource.PHONE.raw,
            modeRaw = plan.mode.raw,
        )
        episodes.upsert(episode)
        return episode
    }

    private fun startPattern() {
        when (mode) {
            ReliefMode.PULSE -> haptics.play(HapticPatterns.pulse(PulseSpec.forLevel(intensity)), repeat = true)
            ReliefMode.BREATHE -> haptics.play(breathWaveform(plan.breathe), repeat = true)
            // Just a marker so you know the hold has started; the pressure is yours.
            ReliefMode.PRESS -> haptics.play(HapticPatterns.marker, repeat = false)
            ReliefMode.TONE -> Unit
        }
    }

    private fun startTicking() {
        ticker?.cancel()
        ticker = scope.launch {
            while (isActive && phase == Phase.RUNNING) {
                delay(250)
                tick()
            }
        }
    }

    private fun stopOutputs() {
        ticker?.cancel()
        ticker = null
        haptics.stop()
        tone.stop()
    }

    companion object {
        /** Cancelled sessions shorter than this are treated as accidental taps. */
        const val MIN_RECORDED_MS = 60_000L
    }
}
