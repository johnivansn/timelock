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
import com.example.timelock.database.AppDatabase
import java.text.SimpleDateFormat
import java.util.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class PersistentNotification(private val context: Context) {
  private val notificationManager =
          context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
  private val database = AppDatabase.getDatabase(context)
  private val scope = CoroutineScope(Dispatchers.IO)

  companion object {
    private const val CHANNEL_ID = "persistent_status"
    private const val NOTIFICATION_ID = 2000
    private const val ACTION_OPEN_APP = "com.example.timelock.OPEN_APP"
  }

  init {
    createNotificationChannel()
  }

  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel =
              NotificationChannel(
                              CHANNEL_ID,
                              "Estado Persistente",
                              NotificationManager.IMPORTANCE_LOW
                      )
                      .apply {
                        description = "Muestra el estado actual de tus apps monitoreadas"
                        setShowBadge(false)
                      }
      notificationManager.createNotificationChannel(channel)
    }
  }

  fun show() {
    scope.launch {
      val restrictions = database.appRestrictionDao().getEnabled()
      val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
      val today = dateFormat.format(Date())

      var totalUsed = 0
      var totalQuota = 0
      var blockedCount = 0

      for (restriction in restrictions) {
        val usage = database.dailyUsageDao().getUsage(restriction.packageName, today)
        totalUsed += usage?.usedMinutes ?: 0
        totalQuota += restriction.dailyQuotaMinutes
        if (usage?.isBlocked == true) blockedCount++
      }

      val remaining = (totalQuota - totalUsed).coerceAtLeast(0)

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
              NotificationCompat.Builder(context, CHANNEL_ID)
                      .setSmallIcon(android.R.drawable.ic_menu_info_details)
                      .setContentTitle("${restrictions.size} apps monitoreadas")
                      .setContentText(
                              "${formatTime(remaining)} restantes" +
                                      if (blockedCount > 0)
                                              " • $blockedCount bloqueada${if (blockedCount > 1) "s" else ""}"
                                      else ""
                      )
                      .setPriority(NotificationCompat.PRIORITY_LOW)
                      .setOngoing(true)
                      .setContentIntent(pendingIntent)
                      .setStyle(
                              NotificationCompat.BigTextStyle()
                                      .bigText(buildDetailedText(restrictions, today))
                      )
                      .build()

      notificationManager.notify(NOTIFICATION_ID, notification)
    }
  }

  private suspend fun buildDetailedText(
          restrictions: List<com.example.timelock.database.AppRestriction>,
          today: String
  ): String {
    val lines = mutableListOf<String>()
    val top3 = restrictions.take(3)

    for (restriction in top3) {
      val usage = database.dailyUsageDao().getUsage(restriction.packageName, today)
      val used = usage?.usedMinutes ?: 0
      val quota = restriction.dailyQuotaMinutes
      val remaining = (quota - used).coerceAtLeast(0)
      val status =
              when {
                usage?.isBlocked == true -> "🔒"
                remaining <= 5 -> "⚠️"
                else -> "✓"
              }
      lines.add("$status ${restriction.appName}: ${formatTime(remaining)} restantes")
    }

    if (restrictions.size > 3) {
      lines.add("... y ${restrictions.size - 3} más")
    }

    return lines.joinToString("\n")
  }

  private fun formatTime(minutes: Int): String {
    return if (minutes >= 60) {
      val h = minutes / 60
      val m = minutes % 60
      if (m == 0) "${h}h" else "${h}h ${m}m"
    } else {
      "${minutes}m"
    }
  }

  fun hide() {
    notificationManager.cancel(NOTIFICATION_ID)
  }
}
