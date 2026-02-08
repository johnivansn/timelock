package com.example.timelock.blocking

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import com.example.timelock.database.AppDatabase
import com.example.timelock.monitoring.ScheduleMonitor
import com.example.timelock.notifications.PillNotificationHelper
import com.example.timelock.utils.AppUtils
import java.util.*

class BlockingEngine(private val context: Context) {
  private val database = AppDatabase.getDatabase(context)
  private val dateFormat = AppUtils.newDateFormat()
  private val pillNotification = PillNotificationHelper(context)
  private val scheduleMonitor = ScheduleMonitor()

  sealed class BlockReason {
    object TimeQuota : BlockReason()
    object ScheduleBlocked : BlockReason()
    object DateBlocked : BlockReason()
    object Combined : BlockReason()
  }

  suspend fun shouldBlock(packageName: String): Boolean {
    val restriction = database.appRestrictionDao().getByPackage(packageName) ?: return false
    if (!restriction.isEnabled) return false
    return isQuotaBlocked(packageName) || isScheduleBlocked(packageName) || isDateBlocked(packageName)
  }

  suspend fun shouldBlockSync(packageName: String): BlockReason? {
    val restriction = database.appRestrictionDao().getByPackage(packageName) ?: return null
    if (!restriction.isEnabled) return null

    val quotaBlocked = isQuotaBlocked(packageName)
    val scheduleBlocked = isScheduleBlocked(packageName)
    val dateBlocked = isDateBlocked(packageName)
    val activeCount = listOf(quotaBlocked, scheduleBlocked, dateBlocked).count { it }

    return when {
      activeCount == 0 -> null
      activeCount > 1 -> BlockReason.Combined
      quotaBlocked -> BlockReason.TimeQuota
      scheduleBlocked -> BlockReason.ScheduleBlocked
      else -> BlockReason.DateBlocked
    }
  }

  suspend fun isQuotaBlocked(packageName: String): Boolean {
    val restriction = database.appRestrictionDao().getByPackage(packageName) ?: return false
    val today = dateFormat.format(Date())
    val usage = database.dailyUsageDao().getUsage(packageName, today) ?: return false
    return usage.usedMinutes >= restriction.dailyQuotaMinutes
  }

  suspend fun isScheduleBlocked(packageName: String): Boolean {
    val schedules = database.appScheduleDao().getByPackage(packageName)
    return scheduleMonitor.isCurrentlyBlocked(schedules)
  }

  suspend fun isDateBlocked(packageName: String): Boolean {
    val today = dateFormat.format(Date())
    return database.dateBlockDao().getActiveForDate(packageName, today).isNotEmpty()
  }

  suspend fun getDateBlockRemainingDays(packageName: String): Int? {
    val today = dateFormat.format(Date())
    val active = database.dateBlockDao().getActiveForDate(packageName, today)
    if (active.isEmpty()) return null

    val todayDate = dateFormat.parse(today) ?: return null
    val minDays =
            active.mapNotNull { block ->
              val end = dateFormat.parse(block.endDate) ?: return@mapNotNull null
              val diffMillis = end.time - todayDate.time
              (diffMillis / 86400000L).toInt().coerceAtLeast(0)
            }.minOrNull()
    return minDays
  }

  suspend fun getDateBlockRangeSummary(packageName: String): String? {
    val today = dateFormat.format(Date())
    val active = database.dateBlockDao().getActiveForDate(packageName, today)
    if (active.isEmpty()) return null

    val earliestStart = active.minByOrNull { it.startDate }?.startDate ?: return null
    val latestEnd = active.maxByOrNull { it.endDate }?.endDate ?: return null
    return "Del $earliestStart al $latestEnd"
  }

  suspend fun blockApp(packageName: String, reason: BlockReason): Boolean {
    val today = dateFormat.format(Date())
    val usage = database.dailyUsageDao().getUsage(packageName, today) ?: return false
    val restriction = database.appRestrictionDao().getByPackage(packageName) ?: return false

    if (usage.isBlocked) return true

    database.dailyUsageDao().update(usage.copy(isBlocked = true))

    val notificationReason =
            when (reason) {
              BlockReason.TimeQuota -> PillNotificationHelper.BlockReason.QUOTA_EXCEEDED
              BlockReason.ScheduleBlocked -> PillNotificationHelper.BlockReason.SCHEDULE_BLOCKED
              BlockReason.DateBlocked -> PillNotificationHelper.BlockReason.DATE_BLOCKED
              BlockReason.Combined -> PillNotificationHelper.BlockReason.MANUAL
            }

    pillNotification.notifyAppBlocked(restriction.appName, packageName, notificationReason)
    Log.i(TAG, "$packageName blocked - reason: $reason")
    return true
  }

  suspend fun isBlocked(packageName: String): Boolean {
    val today = dateFormat.format(Date())
    val usage = database.dailyUsageDao().getUsage(packageName, today)
    return usage?.isBlocked ?: false
  }

  suspend fun unblockApp(packageName: String) {
    val today = dateFormat.format(Date())
    val usage = database.dailyUsageDao().getUsage(packageName, today) ?: return
    if (usage.isBlocked) {
      database.dailyUsageDao().update(usage.copy(isBlocked = false))
      Log.i(TAG, "$packageName unblocked")
    }
  }

  suspend fun getBlockedApps(): List<String> {
    val today = dateFormat.format(Date())
    val restrictions = database.appRestrictionDao().getEnabled()
    return restrictions
            .filter { r ->
              val usage = database.dailyUsageDao().getUsage(r.packageName, today)
              usage?.isBlocked == true
            }
            .map { it.packageName }
  }

  fun getAllAppsSync(): List<Pair<String, String>> {
    return try {
      val packages = mutableListOf<Pair<String, String>>()
      val pm = context.packageManager
      val installedApps = pm.getInstalledApplications(PackageManager.GET_META_DATA)

      for (appInfo in installedApps) {
        try {
          val label = pm.getApplicationLabel(appInfo).toString()
          packages.add(appInfo.packageName to label)
        } catch (e: Exception) {
          packages.add(appInfo.packageName to appInfo.packageName)
        }
      }

      packages.sortedBy { it.second }
    } catch (e: Exception) {
      Log.e(TAG, "Error getting apps", e)
      emptyList()
    }
  }

  companion object {
    private const val TAG = "BlockingEngine"
  }
}
