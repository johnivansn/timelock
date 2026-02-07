package com.example.timelock.monitoring

import android.app.usage.UsageStatsManager
import android.content.Context
import android.util.Log
import com.example.timelock.database.AppDatabase
import com.example.timelock.database.DailyUsage
import com.example.timelock.database.getDailyQuotaForDay
import com.example.timelock.notifications.PillNotificationHelper
import com.example.timelock.utils.AppUtils
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.ceil
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class UsageStatsMonitor(private val context: Context) {
  private val usageStatsManager =
          context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
  private val database = AppDatabase.getDatabase(context)
  private val dateFormat = AppUtils.newDateFormat()
  private val scope = CoroutineScope(Dispatchers.IO)
  private val pillNotification = PillNotificationHelper(context)

  private val notified50Percent = mutableSetOf<String>()
  private val notified75Percent = mutableSetOf<String>()
  private val notifiedLastMinute = mutableSetOf<String>()

  fun getUsageToday(packageName: String): Long {
    val calendar = Calendar.getInstance()
    calendar.set(Calendar.HOUR_OF_DAY, 0)
    calendar.set(Calendar.MINUTE, 0)
    calendar.set(Calendar.SECOND, 0)
    calendar.set(Calendar.MILLISECOND, 0)
    val startTime = calendar.timeInMillis
    val endTime = System.currentTimeMillis()

    val events = usageStatsManager.queryEvents(startTime, endTime)
    if (events == null) {
      Log.w(TAG, "queryEvents devolvió null - permiso denegado")
      return 0L
    }

    var appInForeground = false
    var lastForegroundTime = 0L
    var totalTime = 0L

    while (events.hasNextEvent()) {
      val event = android.app.usage.UsageEvents.Event()
      events.getNextEvent(event)

      if (event.packageName == packageName) {
        when (event.eventType) {
          android.app.usage.UsageEvents.Event.ACTIVITY_RESUMED,
          android.app.usage.UsageEvents.Event.MOVE_TO_FOREGROUND -> {
            if (!appInForeground) {
              appInForeground = true
              lastForegroundTime = event.timeStamp
            }
          }
          android.app.usage.UsageEvents.Event.ACTIVITY_PAUSED,
          android.app.usage.UsageEvents.Event.ACTIVITY_STOPPED,
          android.app.usage.UsageEvents.Event.MOVE_TO_BACKGROUND -> {
            if (appInForeground) {
              val sessionTime = event.timeStamp - lastForegroundTime
              if (sessionTime > 0) {
                totalTime += sessionTime
              }
              appInForeground = false
            }
          }
        }
      }
    }

    if (appInForeground && lastForegroundTime > 0) {
      val currentSessionTime = endTime - lastForegroundTime
      if (currentSessionTime > 0) {
        totalTime += currentSessionTime
      }
    }

    Log.d(TAG, "$packageName: ${totalTime}ms total (${totalTime/60000} min)")
    return totalTime
  }

  fun updateAllUsage() {
    scope.launch {
      val restrictions = database.appRestrictionDao().getEnabled()
      val today = dateFormat.format(Date())

      Log.d(TAG, "Actualizando uso para ${restrictions.size} apps")

      for (restriction in restrictions) {
        val usageMillis = getUsageToday(restriction.packageName)
        val usageMinutes = (usageMillis / 60000).toInt()

        Log.d(
                TAG,
                "${restriction.packageName}: $usageMinutes min usados hoy (cuota: ${restriction.dailyQuotaMinutes} min)"
        )

        var dailyUsage = database.dailyUsageDao().getUsage(restriction.packageName, today)

        if (dailyUsage == null) {
          dailyUsage =
                  DailyUsage(
                          id = UUID.randomUUID().toString(),
                          packageName = restriction.packageName,
                          date = today,
                          usedMinutes = usageMinutes,
                          isBlocked = false,
                          lastUpdated = System.currentTimeMillis()
                  )
          database.dailyUsageDao().insert(dailyUsage)
          Log.d(TAG, "Creado nuevo registro de uso para ${restriction.packageName}")
        } else {
          dailyUsage =
                  dailyUsage.copy(
                          usedMinutes = usageMinutes,
                          lastUpdated = System.currentTimeMillis()
                  )
          database.dailyUsageDao().update(dailyUsage)
          Log.d(TAG, "Actualizado registro de uso para ${restriction.packageName}")
        }

        val quotaMinutes =
                if (restriction.limitType == "weekly") restriction.weeklyQuotaMinutes
                else restriction.getDailyQuotaForDay(Calendar.getInstance().get(Calendar.DAY_OF_WEEK))

        val usedForLimitMinutes =
                if (restriction.limitType == "weekly") {
                  val weekStart = AppUtils.getWeekStartDate(restriction.weeklyResetDay)
                  val weekUsages =
                          database.dailyUsageDao()
                                  .getUsageSince(restriction.packageName, weekStart)
                  weekUsages.sumOf { it.usedMinutes }
                } else {
                  usageMinutes
                }

        if (quotaMinutes > 0) {
          checkAndNotifyQuota(
                  restriction.packageName,
                  restriction.appName,
                  if (restriction.limitType == "weekly") usedForLimitMinutes * 60000L
                  else usageMillis,
                  quotaMinutes
          )
        }

        val exceeded =
                if (restriction.limitType == "weekly") {
                  usedForLimitMinutes >= quotaMinutes
                } else {
                  usageMillis >= quotaMinutes * 60000L
                }

        if (quotaMinutes > 0 && exceeded && !dailyUsage.isBlocked) {
          dailyUsage = dailyUsage.copy(isBlocked = true)
          database.dailyUsageDao().update(dailyUsage)
          pillNotification.notifyAppBlocked(
                  restriction.appName,
                  restriction.packageName,
                  PillNotificationHelper.BlockReason.QUOTA_EXCEEDED
          )
          Log.i(TAG, "${restriction.packageName} BLOQUEADA - cuota alcanzada")

          sendBlockSignal(restriction.packageName)
        }
      }
    }
  }

  private fun sendBlockSignal(packageName: String) {
    try {
      val intent = android.content.Intent("com.example.timelock.BLOCK_APP")
      intent.putExtra("packageName", packageName)
      intent.setPackage("com.example.timelock")
      context.sendBroadcast(intent)
      Log.i(TAG, "Señal de bloqueo enviada para $packageName")
    } catch (e: Exception) {
      Log.e(TAG, "Error enviando señal de bloqueo", e)
    }
  }

  private fun checkAndNotifyQuota(
          packageName: String,
          appName: String,
          usedMillis: Long,
          quotaMinutes: Int
  ) {
    val quotaMillis = quotaMinutes * 60000L
    val remainingMillis = quotaMillis - usedMillis
    val remainingMinutes = ceil(remainingMillis / 60000.0).toInt()

    when {
      remainingMinutes == 1 && !notifiedLastMinute.contains(packageName) -> {
        pillNotification.notifyLastMinute(appName, packageName)
        notifiedLastMinute.add(packageName)
        Log.i(TAG, "Notificado último minuto para $packageName")
      }
      usedMillis >= (quotaMillis * 0.75).toLong() &&
              remainingMinutes > 1 &&
              !notified75Percent.contains(packageName) -> {
        pillNotification.notifyQuota75(appName, packageName, remainingMinutes)
        notified75Percent.add(packageName)
        Log.i(TAG, "Notificado 75% para $packageName")
      }
      usedMillis >= (quotaMillis * 0.5).toLong() &&
              usedMillis < (quotaMillis * 0.75).toLong() &&
              !notified50Percent.contains(packageName) -> {
        pillNotification.notifyQuota50(appName, packageName, remainingMinutes)
        notified50Percent.add(packageName)
        Log.i(TAG, "Notificado 50% para $packageName")
      }
    }
  }

  fun resetNotificationFlags() {
    notified50Percent.clear()
    notified75Percent.clear()
    notifiedLastMinute.clear()
    Log.i(TAG, "Flags de notificación reseteadas")
  }

  companion object {
    private const val TAG = "UsageStatsMonitor"
  }
}
