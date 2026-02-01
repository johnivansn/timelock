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
    private const val CHANNEL_QUOTA_WARNINGS = "quota_warnings"
    private const val CHANNEL_APP_BLOCKED = "app_blocked"

    private const val NOTIFICATION_ID_QUOTA_25 = 1001
    private const val NOTIFICATION_ID_QUOTA_10 = 1002
    private const val NOTIFICATION_ID_BLOCKED = 1003
  }

  init {
    createNotificationChannels()
  }

  private fun createNotificationChannels() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val quotaChannel =
              NotificationChannel(
                              CHANNEL_QUOTA_WARNINGS,
                              "Advertencias de Cuota",
                              NotificationManager.IMPORTANCE_DEFAULT
                      )
                      .apply {
                        description = "Notificaciones cuando te queda poco tiempo disponible"
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

      notificationManager.createNotificationChannel(quotaChannel)
      notificationManager.createNotificationChannel(blockedChannel)
    }
  }

  fun notifyQuota25(appName: String, remainingMinutes: Int) {
    if (!prefs.quota25Enabled) return

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
            NotificationCompat.Builder(context, CHANNEL_QUOTA_WARNINGS)
                    .setSmallIcon(android.R.drawable.ic_dialog_info)
                    .setContentTitle("⚠️ Queda 25% de tiempo")
                    .setContentText("$appName: ${remainingMinutes}m restantes hoy")
                    .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                    .setContentIntent(pendingIntent)
                    .setAutoCancel(true)
                    .build()

    notificationManager.notify(NOTIFICATION_ID_QUOTA_25, notification)
  }

  fun notifyQuota10(appName: String, remainingMinutes: Int) {
    if (!prefs.quota10Enabled) return

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
            NotificationCompat.Builder(context, CHANNEL_QUOTA_WARNINGS)
                    .setSmallIcon(android.R.drawable.ic_dialog_alert)
                    .setContentTitle("🚨 Últimos minutos disponibles")
                    .setContentText("$appName: solo ${remainingMinutes}m restantes")
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setContentIntent(pendingIntent)
                    .setAutoCancel(true)
                    .build()

    notificationManager.notify(NOTIFICATION_ID_QUOTA_10, notification)
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

  fun cancelAll() {
    notificationManager.cancelAll()
  }

  enum class BlockReason {
    QUOTA_EXCEEDED,
    WIFI_BLOCKED,
    MANUAL
  }
}
