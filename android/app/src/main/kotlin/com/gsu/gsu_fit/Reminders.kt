package com.gsu.gsu_fit

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * Local reminders without a plugin: schedules are kept in SharedPreferences,
 * each one has a single pending alarm, and when it fires the next occurrence
 * is scheduled. Inexact alarms are used, so no exact-alarm permission is
 * needed (a reminder may arrive a few minutes late in deep sleep).
 */
object Reminders {
    private const val CHANNEL_ID = "reminders"
    private const val PREFS = "gsu_fit_reminders"
    private const val KEY_ITEMS = "items"
    const val EXTRA_ID = "reminder_id"

    data class Reminder(
        val id: Int,
        val title: String,
        val body: String,
        val hour: Int,
        val minute: Int,
        /** ISO weekdays, 1 = Monday … 7 = Sunday; empty = every day. */
        val weekdays: List<Int>,
        /** Epoch millis for a one-shot reminder, 0 for repeating ones. */
        val atMillis: Long,
    ) {
        fun toJson(): JSONObject = JSONObject().apply {
            put("id", id)
            put("title", title)
            put("body", body)
            put("hour", hour)
            put("minute", minute)
            put("weekdays", JSONArray(weekdays))
            put("atMillis", atMillis)
        }

        companion object {
            fun fromJson(json: JSONObject): Reminder {
                val days = json.optJSONArray("weekdays") ?: JSONArray()
                return Reminder(
                    id = json.getInt("id"),
                    title = json.optString("title"),
                    body = json.optString("body"),
                    hour = json.optInt("hour"),
                    minute = json.optInt("minute"),
                    weekdays = (0 until days.length()).map { days.getInt(it) },
                    atMillis = json.optLong("atMillis"),
                )
            }
        }
    }

    fun notificationsAllowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        return context.getSystemService(NotificationManager::class.java).areNotificationsEnabled()
    }

    fun schedule(context: Context, reminder: Reminder) {
        val all = load(context).filter { it.id != reminder.id } + reminder
        save(context, all)
        setAlarm(context, reminder)
    }

    fun cancel(context: Context, id: Int) {
        save(context, load(context).filter { it.id != id })
        alarmManager(context).cancel(pendingIntent(context, id))
    }

    fun cancelAll(context: Context) {
        val manager = alarmManager(context)
        load(context).forEach { manager.cancel(pendingIntent(context, it.id)) }
        save(context, emptyList())
    }

    /** Called after a reboot or an app update, when all alarms are gone. */
    fun rescheduleAll(context: Context) {
        val now = System.currentTimeMillis()
        val remaining = load(context).filter { it.atMillis == 0L || it.atMillis > now }
        save(context, remaining)
        remaining.forEach { setAlarm(context, it) }
    }

    fun onAlarm(context: Context, id: Int) {
        val reminder = load(context).firstOrNull { it.id == id } ?: return
        show(context, reminder)
        if (reminder.atMillis > 0L) {
            save(context, load(context).filter { it.id != id })
        } else {
            setAlarm(context, reminder)
        }
    }

    private fun setAlarm(context: Context, reminder: Reminder) {
        val triggerAt = if (reminder.atMillis > 0L) reminder.atMillis else nextTrigger(reminder)
        alarmManager(context).setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAt,
            pendingIntent(context, reminder.id),
        )
    }

    private fun nextTrigger(reminder: Reminder): Long {
        val now = Calendar.getInstance()
        val candidate = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, reminder.hour)
            set(Calendar.MINUTE, reminder.minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (!candidate.after(now)) candidate.add(Calendar.DAY_OF_YEAR, 1)
        if (reminder.weekdays.isNotEmpty()) {
            var guard = 0
            while (isoWeekday(candidate) !in reminder.weekdays && guard < 7) {
                candidate.add(Calendar.DAY_OF_YEAR, 1)
                guard++
            }
        }
        return candidate.timeInMillis
    }

    /** Calendar uses Sunday = 1 … Saturday = 7; convert to Monday = 1. */
    private fun isoWeekday(calendar: Calendar): Int =
        ((calendar.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1

    private fun show(context: Context, reminder: Reminder) {
        if (!notificationsAllowed(context)) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    context.getString(R.string.reminder_channel_name),
                    NotificationManager.IMPORTANCE_DEFAULT,
                ),
            )
        }
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val contentIntent = launch?.let {
            PendingIntent.getActivity(
                context,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val notification = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle(reminder.title)
            .setContentText(reminder.body)
            .setAutoCancel(true)
            .apply { if (contentIntent != null) setContentIntent(contentIntent) }
            .build()
        manager.notify(reminder.id, notification)
    }

    private fun alarmManager(context: Context): AlarmManager =
        context.getSystemService(AlarmManager::class.java)

    private fun pendingIntent(context: Context, id: Int): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).putExtra(EXTRA_ID, id)
        return PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun load(context: Context): List<Reminder> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_ITEMS, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).map { Reminder.fromJson(array.getJSONObject(it)) }
        } catch (error: Exception) {
            emptyList()
        }
    }

    private fun save(context: Context, reminders: List<Reminder>) {
        val array = JSONArray()
        reminders.forEach { array.put(it.toJson()) }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ITEMS, array.toString())
            .apply()
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(Reminders.EXTRA_ID, -1)
        if (id >= 0) Reminders.onAlarm(context, id)
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED ->
                Reminders.rescheduleAll(context)
        }
    }
}
