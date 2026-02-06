package com.example.timelock.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.example.timelock.MainActivity
import com.example.timelock.R

class NotificationHelper(private val context: Context) {
  private val notificationManager =
          context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
  private val prefs = com.example.timelock.preferences.NotificationPreferences(context)

  companion object {
    private const val CHANNEL_QUOTA_50 = "quota_50_warning"
    private const val CHANNEL_QUOTA_75 = "quota_75_warning"
    private const val CHANNEL_LAST_MINUTE = "last_minute_warning"
    private const val CHANNEL_APP_BLOCKED = "app_blocked"
    private const val CHANNEL_SCHEDULE = "schedule_warnings"

    private const val NOTIFICATION_ID_QUOTA_50 = 1005
    private const val NOTIFICATION_ID_QUOTA_75 = 1006
    private const val NOTIFICATION_ID_LAST_MINUTE = 1007
    private const val NOTIFICATION_ID_BLOCKED = 1003
    private const val NOTIFICATION_ID_SCHEDULE = 1004
  }

  init {
    createNotificationChannels()
  }

  private fun createNotificationChannels() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val quota50Channel =
              NotificationChannel(
                              CHANNEL_QUOTA_50,
                              "Advertencia 50% consumido",
                              NotificationManager.IMPORTANCE_HIGH
                      )
                      .apply {
                        description = "Notificación cuando has usado la mitad de tu tiempo"
                        enableVibration(true)
                      }

      val quota75Channel =
              NotificationChannel(
                              CHANNEL_QUOTA_75,
                              "Advertencia 75% consumido",
                              NotificationManager.IMPORTANCE_HIGH
                      )
                      .apply {
                        description = "Notificación cuando queda poco tiempo disponible"
                        enableVibration(true)
                      }

      val lastMinuteChannel =
              NotificationChannel(
                              CHANNEL_LAST_MINUTE,
                              "Último minuto",
                              NotificationManager.IMPORTANCE_HIGH
                      )
                      .apply {
                        description = "Notificación en el último minuto disponible"
                        enableVibration(true)
                      }

      val blockedChannel =
              NotificationChannel(
                              CHANNEL_APP_BLOCKED,
                              "Aplicaciones Bloqueadas",
                              NotificationManager.IMPORTANCE_HIGH
                      )
                      .apply {
                        description = "Notificaciones cuando una app es bloqueada"
                        enableVibration(true)
                      }

      val scheduleChannel =
              NotificationChannel(
                              CHANNEL_SCHEDULE,
                              "Horarios de Bloqueo",
                              NotificationManager.IMPORTANCE_DEFAULT
                      )
                      .apply {
                        description = "Notificaciones sobre bloqueos programados"
                        enableVibration(true)
                      }

      notificationManager.createNotificationChannel(quota50Channel)
      notificationManager.createNotificationChannel(quota75Channel)
      notificationManager.createNotificationChannel(lastMinuteChannel)
      notificationManager.createNotificationChannel(blockedChannel)
      notificationManager.createNotificationChannel(scheduleChannel)
    }
  }

  private fun createHeadsUpNotification(channelId: String): NotificationCompat.Builder {
    val intent =
            Intent(context, MainActivity::class.java).apply {
              flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
    val pendingIntent =
            PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

    return NotificationCompat.Builder(context, channelId)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
  }

  fun notifyQuota50(appName: String, remainingMinutes: Int) {
    if (!prefs.quota50Enabled) return

    val notification =
            createHeadsUpNotification(CHANNEL_QUOTA_50)
                    .setSmallIcon(android.R.drawable.ic_dialog_info)
                    .setContentTitle("⏳ Mitad del tiempo usado")
                    .setContentText("$appName: 50% consumido, quedan ${remainingMinutes}m")
                    .build()

    notificationManager.notify(NOTIFICATION_ID_QUOTA_50, notification)
  }

  fun notifyQuota75(appName: String, remainingMinutes: Int) {
    if (!prefs.quota75Enabled) return

    val notification =
            createHeadsUpNotification(CHANNEL_QUOTA_75)
                    .setSmallIcon(android.R.drawable.ic_dialog_alert)
                    .setContentTitle("⚠️ Quedan pocos minutos")
                    .setContentText("$appName: 75% consumido, quedan ${remainingMinutes}m")
                    .build()

    notificationManager.notify(NOTIFICATION_ID_QUOTA_75, notification)
  }

  fun notifyLastMinute(appName: String) {
    if (!prefs.lastMinuteEnabled) return

    val notification =
            createHeadsUpNotification(CHANNEL_LAST_MINUTE)
                    .setSmallIcon(android.R.drawable.ic_dialog_alert)
                    .setContentTitle("🚨 Último minuto disponible")
                    .setContentText("$appName: Solo queda 1 minuto")
                    .build()

    notificationManager.notify(NOTIFICATION_ID_LAST_MINUTE, notification)
  }

  fun notifyAppBlocked(appName: String, reason: BlockReason) {
    if (!prefs.blockedEnabled) return

    val intent =
            Intent(context, MainActivity::class.java).apply {
              flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
    val pendingIntent =
            PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

    val message =
            when (reason) {
              BlockReason.QUOTA_EXCEEDED -> "Cuota diaria consumida. Se desbloqueará a medianoche."
              BlockReason.WIFI_BLOCKED -> "Bloqueada en esta red WiFi."
              BlockReason.SCHEDULE_BLOCKED -> "Bloqueada por horario programado."
              BlockReason.MANUAL -> "Bloqueada manualmente."
            }

    val notification =
            NotificationCompat.Builder(context, CHANNEL_APP_BLOCKED)
                    .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
                    .setContentTitle("🔒 $appName bloqueada")
                    .setContentText(message)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setContentIntent(pendingIntent)
                    .setAutoCancel(true)
                    .build()

    notificationManager.notify(NOTIFICATION_ID_BLOCKED, notification)
  }

  fun notifyScheduleUpcoming(appName: String, minutes: Int) {
    if (!prefs.scheduleEnabled) return

    val intent =
            Intent(context, MainActivity::class.java).apply {
              flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
    val pendingIntent =
            PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

    val notification =
            NotificationCompat.Builder(context, CHANNEL_SCHEDULE)
                    .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                    .setContentTitle("⏰ Bloqueo próximo")
                    .setContentText("$appName se bloqueará en ${minutes}m")
                    .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                    .setContentIntent(pendingIntent)
                    .setAutoCancel(true)
                    .build()

    notificationManager.notify(NOTIFICATION_ID_SCHEDULE, notification)
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
