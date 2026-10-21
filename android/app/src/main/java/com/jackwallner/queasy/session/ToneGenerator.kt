package com.jackwallner.queasy.session

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlin.math.PI
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * The 100 Hz sine tone from the 2025 Nagoya study, at the iOS amplitude.
 * 100 Hz divides 44.1 kHz exactly (441 samples a cycle), so a static buffer of
 * whole cycles loops with no click at the seam.
 */
class ToneGenerator {
    private var track: AudioTrack? = null

    val isPlaying: Boolean get() = track != null

    fun start() {
        if (track != null) return
        val samples = buffer()
        val built = runCatching {
            AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(SAMPLE_RATE)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                )
                .setTransferMode(AudioTrack.MODE_STATIC)
                .setBufferSizeInBytes(samples.size * 2)
                .build()
                .apply {
                    write(samples, 0, samples.size)
                    setLoopPoints(0, samples.size, -1)
                    play()
                }
        }.getOrNull()
        track = built
    }

    fun stop() {
        val current = track ?: return
        track = null
        runCatching {
            current.stop()
            current.release()
        }
    }

    companion object {
        const val FREQUENCY = 100.0
        const val AMPLITUDE = 0.18
        const val SAMPLE_RATE = 44_100
        const val CYCLES = 20

        /** [CYCLES] whole periods of the sine, as 16-bit PCM. */
        fun buffer(): ShortArray {
            val perCycle = (SAMPLE_RATE / FREQUENCY).roundToInt()
            return ShortArray(perCycle * CYCLES) { i ->
                (sin(2 * PI * FREQUENCY * i / SAMPLE_RATE) * AMPLITUDE * Short.MAX_VALUE).roundToInt().toShort()
            }
        }
    }
}
