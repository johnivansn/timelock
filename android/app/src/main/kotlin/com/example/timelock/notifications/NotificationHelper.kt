package com.example.timelock.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.example.timelock.MainActivity

class NotificationHelper(private val context: Context) {
  private val notificationManager =
          context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
  private val prefs = com.example.timelock.preferences.NotificationPreferences(context)

  companion object {
    private const val CHANNEL_QUOTA_WARNINGS = "quota_warnings"
    private const val CHANNEL_APP_BLOCKED = "app_blocked"
    private const val CHANNEL_SCHEDULE = "schedule_warnings"

    private const val NOTIFICATION_ID_QUOTA = 1005
    private const val NOTIFICATION_ID_BLOCKED = 1003
    private const val NOTIFICATION_ID_SCHEDULE = 1004
  }

  init {
    createNotificationChannels()
  }

  private fun createNotificationChannels() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val quotaChannel =
              NotificationChannel(
                              CHANNEL_QUOTA_WARNINGS,
                              "Recordatorios de tiempo",
                              NotificationManager.IMPORTANCE_HIGH
                      )
                      .apply {
                        description = "Alertas de uso de apps"
                        setShowBadge(false)
                        enableVibration(false)
                        setSound(null, null)
                        enableLights(false)
                      }

      val blockedChannel =
              NotificationChannel(
                              CHANNEL_APP_BLOCKED,
                              "Apps bloqueadas",
                              NotificationManager.IMPORTANCE_HIGH
                      )
                      .apply {
                        description = "Notificaciones de bloqueo"
                        setShowBadge(false)
                        enableVibration(false)
                        setSound(null, null)
                        enableLights(false)
                      }

      val scheduleChannel =
              NotificationChannel(
                              CHANNEL_SCHEDULE,
                              "Horarios programados",
                              NotificationManager.IMPORTANCE_DEFAULT
                      )
                      .apply {
                        description = "Pausas programadas"
                        setShowBadge(false)
                        enableVibration(false)
                        setSound(null, null)
                        enableLights(false)
                      }

      notificationManager.apply {
        createNotificationChannel(quotaChannel)
        createNotificationChannel(blockedChannel)
        createNotificationChannel(scheduleChannel)
      }
    }
  }

  private fun createChipNotification(
          channelId: String,
          importance: Int = NotificationCompat.PRIORITY_HIGH
  ): NotificationCompat.Builder {
    val intent = Intent(context, MainActivity::class.java)
    val pendingIntent =
            PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

    return NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(importance)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setLocalOnly(true)
            .setTimeoutAfter(4000)
  }

  fun notifyQuota50(appName: String, remainingMinutes: Int) {
    if (!prefs.quota50Enabled) return

    val timeText = formatTimeShort(remainingMinutes)

    val notification =
            createChipNotification(CHANNEL_QUOTA_WARNINGS)
                    .setContentText("$appName: quedan $timeText")
                    .build()

    notificationManager.notify(NOTIFICATION_ID_QUOTA + appName.hashCode(), notification)
  }

  fun notifyQuota75(appName: String, remainingMinutes: Int) {
    if (!prefs.quota75Enabled) return

    val timeText = formatTimeShort(remainingMinutes)

    val notification =
            createChipNotification(CHANNEL_QUOTA_WARNINGS)
                    .setContentText("$appName: quedan $timeText")
                    .build()

    notificationManager.notify(NOTIFICATION_ID_QUOTA + appName.hashCode(), notification)
  }

  fun notifyLastMinute(appName: String) {
    if (!prefs.lastMinuteEnabled) return

    val notification =
            createChipNotification(CHANNEL_QUOTA_WARNINGS)
                    .setContentText("$appName: último minuto")
                    .build()

    notificationManager.notify(NOTIFICATION_ID_QUOTA + appName.hashCode(), notification)
  }

  fun notifyAppBlocked(appName: String, reason: BlockReason) {
    if (!prefs.blockedEnabled) return

    val text =
            when (reason) {
              BlockReason.QUOTA_EXCEEDED -> "$appName: límite alcanzado"
              BlockReason.WIFI_BLOCKED -> "$appName: bloqueada en WiFi"
              BlockReason.SCHEDULE_BLOCKED -> "$appName: fuera de horario"
              BlockReason.MANUAL -> "$appName: bloqueada"
            }

    val notification =
            createChipNotification(CHANNEL_APP_BLOCKED)
                    .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
                    .setContentText(text)
                    .build()

    notificationManager.notify(NOTIFICATION_ID_BLOCKED + appName.hashCode(), notification)
  }

  fun notifyScheduleUpcoming(appName: String, minutes: Int) {
    if (!prefs.scheduleEnabled) return

    val timeText = if (minutes == 1) "1 min" else "${minutes} min"

    val notification =
            createChipNotification(CHANNEL_SCHEDULE, NotificationCompat.PRIORITY_DEFAULT)
                    .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                    .setContentText("$appName se pausará en $timeText")
                    .build()

    notificationManager.notify(NOTIFICATION_ID_SCHEDULE + appName.hashCode(), notification)
  }

  private fun formatTimeShort(minutes: Int): String {
    return when {
      minutes >= 60 -> {
        val hours = minutes / 60
        val mins = minutes % 60
        if (mins == 0) "${hours}h" else "${hours}h ${mins}m"
      }
      else -> "${minutes}m"
    }
  }

  fun cancelAll() {
    notificationManager.cancelAll()
  }

  enum class BlockReason {
    QUOTA_EXCEEDED,
    WIFI_BLOCKED,
    SCHEDULE_BLOCKED,
    MANUAL
  }
}
