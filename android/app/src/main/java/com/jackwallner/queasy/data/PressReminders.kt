package com.jackwallner.queasy.data

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.jackwallner.queasy.MainActivity
import com.jackwallner.queasy.QueasyApplication
import com.jackwallner.queasy.R
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/**
 * Daily nudges to run a Press hold at 8, 14 and 20 o'clock, the way the
 * wristband trials spaced their holds. Ports `PressReminderService.swift`.
 * Inexact alarms (a 15-minute window) so no exact-alarm declaration is needed;
 * each delivery re-arms the next day's alarm for that hour.
 */
class PressReminders(private val context: Context, private val defaults: KeyValueStore) {
    var isEnabled by mutableStateOf(defaults.getBoolean(ENABLED_KEY))
        private set
    var authorizationDenied by mutableStateOf(false)
        private set

    /** Bridge to the activity's permission launcher; resumes with the user's answer. */
    var requestPermission: (suspend () -> Boolean)? = null

    suspend fun setEnabled(enabled: Boolean): Boolean {
        if (!enabled) {
            cancelAll()
            store(false)
            return false
        }
        if (!hasPermission() && !(requestPermission?.invoke() ?: false)) {
            authorizationDenied = true
            store(false)
            return false
        }
        authorizationDenied = false
        scheduleAll()
        store(true)
        return true
    }

    /** Re-lays the schedule on launch; a permission revoked in system settings turns the toggle off. */
    fun refresh() {
        if (!isEnabled) return
        if (!hasPermission()) {
            cancelAll()
            store(false)
            return
        }
        scheduleAll()
    }

    /** Pro lapsed: reminders stop, but the preference stays so resubscribing restores them. */
    fun suspendForNonSubscriber() = cancelAll()

    val scheduleLabel: String
        get() {
            val format = DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT)
            return HOURS.joinToString(", ") { LocalTime.of(it, 0).format(format) }
        }

    fun hasPermission(): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    fun scheduleAll() = HOURS.forEach { schedule(context, it) }

    private fun cancelAll() {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        HOURS.forEach { alarms.cancel(pendingIntent(context, it)) }
    }

    private fun store(enabled: Boolean) {
        isEnabled = enabled
        defaults.putBoolean(ENABLED_KEY, enabled)
    }

    companion object {
        val HOURS = listOf(8, 14, 20)
        const val ENABLED_KEY = "pressRemindersEnabled"
        private const val CHANNEL_ID = "press-reminders"
        private const val EXTRA_HOUR = "hour"
        private const val WINDOW_MS = 15 * 60_000L

        /** The next time [hour] o'clock comes round, strictly after [now]. */
        fun nextTrigger(hour: Int, now: ZonedDateTime): ZonedDateTime {
            val today = ZonedDateTime.of(LocalDateTime.of(now.toLocalDate(), LocalTime.of(hour, 0)), now.zone)
            return if (today.isAfter(now)) today else today.plusDays(1)
        }

        fun schedule(context: Context, hour: Int) {
            val alarms = context.getSystemService(AlarmManager::class.java) ?: return
            val at = nextTrigger(hour, ZonedDateTime.now(ZoneId.systemDefault())).toInstant().toEpochMilli()
            alarms.setWindow(AlarmManager.RTC_WAKEUP, at, WINDOW_MS, pendingIntent(context, hour))
        }

        private fun pendingIntent(context: Context, hour: Int): PendingIntent = PendingIntent.getBroadcast(
            context,
            hour,
            Intent(context, PressReminderReceiver::class.java).putExtra(EXTRA_HOUR, hour),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        fun post(context: Context, hour: Int) {
            val manager = context.getSystemService(NotificationManager::class.java) ?: return
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, context.getString(R.string.reminder_channel), NotificationManager.IMPORTANCE_DEFAULT),
            )
            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE,
            )
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle("Time for a hold")
                .setContentText("Three minutes of steady pressure on the inside of your wrist.")
                .setContentIntent(open)
                .setAutoCancel(true)
                .build()
            runCatching { NotificationManagerCompat.from(context).notify(1000 + hour, notification) }
        }
    }
}

/** One reminder fired: post it (when still enabled and Pro) and arm tomorrow's. */
class PressReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val hour = intent.getIntExtra("hour", -1).takeIf { it in PressReminders.HOURS } ?: return
        val graph = (context.applicationContext as QueasyApplication).graph
        if (!graph.reminders.isEnabled || !graph.subscriptions.isPro) return
        PressReminders.post(context, hour)
        PressReminders.schedule(context, hour)
    }
}

/** Alarms do not survive a reboot, an update or a clock change; lay them again. */
class PressReminderRescheduler : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val graph = (context.applicationContext as QueasyApplication).graph
        if (graph.subscriptions.isPro) graph.reminders.refresh()
    }
}
