package com.example.timelock.monitoring

import android.app.usage.UsageStatsManager
import android.content.Context
import android.util.Log
import com.example.timelock.database.AppDatabase
import com.example.timelock.database.DailyUsage
import com.example.timelock.notifications.NotificationHelper
import com.example.timelock.preferences.ProfilePreferences
import java.text.SimpleDateFormat
import java.util.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class UsageStatsMonitor(private val context: Context) {
  private val usageStatsManager =
          context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
  private val database = AppDatabase.getDatabase(context)
  private val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
  private val scope = CoroutineScope(Dispatchers.IO)
  private val notificationHelper = NotificationHelper(context)
  private val profilePrefs = ProfilePreferences(context)

  private val notified25Percent = mutableSetOf<String>()
  private val notified10Percent = mutableSetOf<String>()

  fun getUsageToday(packageName: String): Long {
    val calendar = Calendar.getInstance()
    calendar.set(Calendar.HOUR_OF_DAY, 0)
    calendar.set(Calendar.MINUTE, 0)
    calendar.set(Calendar.SECOND, 0)
    calendar.set(Calendar.MILLISECOND, 0)
    val startTime = calendar.timeInMillis
    val endTime = System.currentTimeMillis()

    val stats =
            usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
                    ?: run {
                      Log.w(
                              "UsageStatsMonitor",
                              "queryUsageStats returned null - permission not granted?"
                      )
                      return 0L
                    }

    val appStats = stats.find { it.packageName == packageName }
    return appStats?.totalTimeInForeground ?: 0L
  }

  fun updateAllUsage() {
    scope.launch {
      val profileId = profilePrefs.activeProfileId
      val restrictions = database.appRestrictionDao().getEnabledForProfile(profileId)
      val today = dateFormat.format(Date())

      Log.d(
              "UsageStatsMonitor",
              "Updating usage for ${restrictions.size} apps (profile: $profileId)"
      )

      for (restriction in restrictions) {
        val usageMillis = getUsageToday(restriction.packageName)
        val usageMinutes = (usageMillis / 60000).toInt()

        Log.d(
                "UsageStatsMonitor",
                "${restriction.packageName}: $usageMinutes min used today (quota: ${restriction.dailyQuotaMinutes} min)"
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
        } else {
          dailyUsage =
                  dailyUsage.copy(
                          usedMinutes = usageMinutes,
                          lastUpdated = System.currentTimeMillis()
                  )
          database.dailyUsageDao().update(dailyUsage)
        }

        checkAndNotifyQuota(
                restriction.packageName,
                restriction.appName,
                usageMinutes,
                restriction.dailyQuotaMinutes
        )

        if (usageMinutes >= restriction.dailyQuotaMinutes && !dailyUsage.isBlocked) {
          dailyUsage = dailyUsage.copy(isBlocked = true)
          database.dailyUsageDao().update(dailyUsage)
          notificationHelper.notifyAppBlocked(
                  restriction.appName,
                  NotificationHelper.BlockReason.QUOTA_EXCEEDED
          )
          Log.i("UsageStatsMonitor", "${restriction.packageName} BLOCKED - quota reached")
        }
      }
    }
  }

  private fun checkAndNotifyQuota(
          packageName: String,
          appName: String,
          usedMinutes: Int,
          quotaMinutes: Int
  ) {
    val remainingMinutes = quotaMinutes - usedMinutes
    val percentageUsed = (usedMinutes.toFloat() / quotaMinutes.toFloat()) * 100

    when {
      percentageUsed >= 90 && !notified10Percent.contains(packageName) -> {
        notificationHelper.notifyQuota10(appName, remainingMinutes)
        notified10Percent.add(packageName)
        Log.i("UsageStatsMonitor", "Notified 10% remaining for $packageName")
      }
      percentageUsed >= 75 && !notified25Percent.contains(packageName) -> {
        notificationHelper.notifyQuota25(appName, remainingMinutes)
        notified25Percent.add(packageName)
        Log.i("UsageStatsMonitor", "Notified 25% remaining for $packageName")
      }
    }
  }

  fun resetNotificationFlags() {
    notified25Percent.clear()
    notified10Percent.clear()
    Log.i("UsageStatsMonitor", "Notification flags reset")
  }
}
