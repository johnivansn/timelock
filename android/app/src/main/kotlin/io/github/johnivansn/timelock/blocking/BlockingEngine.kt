package io.github.johnivansn.timelock.blocking

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import io.github.johnivansn.timelock.database.AppDatabase
import io.github.johnivansn.timelock.database.getDailyQuotaForDay
import io.github.johnivansn.timelock.monitoring.ScheduleMonitor
import io.github.johnivansn.timelock.notifications.PillNotificationHelper
import io.github.johnivansn.timelock.utils.AppUtils
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
    val restriction = database.appRestrictionDao().getByPackage(packageName)
    val canEvaluateDirect = canEvaluateDirectBlocks(restriction)
    val quotaBlocked = isQuotaBlocked(packageName, restriction)
    val scheduleBlocked = canEvaluateDirect && isScheduleBlocked(packageName)
    val dateBlocked = canEvaluateDirect && isDateBlocked(packageName)
    return quotaBlocked || scheduleBlocked || dateBlocked
  }

  suspend fun shouldBlockSync(packageName: String): BlockReason? {
    val restriction = database.appRestrictionDao().getByPackage(packageName)
    val canEvaluateDirect = canEvaluateDirectBlocks(restriction)
    val quotaBlocked = isQuotaBlocked(packageName, restriction)
    val scheduleBlocked = canEvaluateDirect && isScheduleBlocked(packageName)
    val dateBlocked = canEvaluateDirect && isDateBlocked(packageName)
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
    val restriction = database.appRestrictionDao().getByPackage(packageName)
    return isQuotaBlocked(packageName, restriction)
  }

  private suspend fun isQuotaBlocked(
          packageName: String,
          restriction: io.github.johnivansn.timelock.database.AppRestriction?
  ): Boolean {
    restriction ?: return false
    if (!restriction.isEnabled) return false
    if (isExpired(restriction)) return false
    val today = dateFormat.format(Date())
    val dayOfWeek = Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
    val quotaMinutes =
            if (restriction.limitType == "weekly") {
              restriction.weeklyQuotaMinutes
            } else {
              restriction.getDailyQuotaForDay(dayOfWeek)
            }

    if (quotaMinutes <= 0) return false

    return if (restriction.limitType == "weekly") {
      val weekStart =
              AppUtils.getWeekStartDate(
                      restriction.weeklyResetDay,
                      restriction.weeklyResetHour,
                      restriction.weeklyResetMinute,
                      dateFormat
              )
      val weekUsages = database.dailyUsageDao().getUsageSince(packageName, weekStart)
      val usedMinutes = weekUsages.sumOf { it.usedMinutes }
      usedMinutes >= quotaMinutes
    } else {
      val usage = database.dailyUsageDao().getUsage(packageName, today) ?: return false
      usage.usedMinutes >= quotaMinutes
    }
  }

  suspend fun isScheduleBlocked(packageName: String): Boolean {
    val schedules = database.appScheduleDao().getByPackage(packageName)
    return scheduleMonitor.isCurrentlyBlocked(schedules)
  }

  suspend fun isDateBlocked(packageName: String): Boolean {
    val now = System.currentTimeMillis()
    val blocks = database.dateBlockDao().getEnabledByPackage(packageName)
    return blocks.any { block ->
      val startMillis = toDateTimeMillis(block.startDate, block.startHour, block.startMinute)
      val endMillis = toDateTimeMillis(block.endDate, block.endHour, block.endMinute)
      if (startMillis == null || endMillis == null) return@any false
      now in startMillis..endMillis
    }
  }

  suspend fun getDateBlockRemainingDays(packageName: String): Int? {
    val now = System.currentTimeMillis()
    val active =
            database.dateBlockDao().getEnabledByPackage(packageName).filter { block ->
              val startMillis =
                      toDateTimeMillis(block.startDate, block.startHour, block.startMinute)
              val endMillis = toDateTimeMillis(block.endDate, block.endHour, block.endMinute)
              if (startMillis == null || endMillis == null) return@filter false
              now in startMillis..endMillis
            }
    if (active.isEmpty()) return null

    val minDays =
            active.mapNotNull { block ->
              val endMillis =
                      toDateTimeMillis(block.endDate, block.endHour, block.endMinute)
                              ?: return@mapNotNull null
              val diffMillis = endMillis - now
              (diffMillis / 86400000L).toInt().coerceAtLeast(0)
            }.minOrNull()
    return minDays
  }

  suspend fun getDateBlockRangeSummary(packageName: String): String? {
    val now = System.currentTimeMillis()
    val active =
            database.dateBlockDao().getEnabledByPackage(packageName).filter { block ->
              val startMillis =
                      toDateTimeMillis(block.startDate, block.startHour, block.startMinute)
              val endMillis = toDateTimeMillis(block.endDate, block.endHour, block.endMinute)
              if (startMillis == null || endMillis == null) return@filter false
              now in startMillis..endMillis
            }
    if (active.isEmpty()) return null

    val earliestStartMillis =
            active.mapNotNull {
              toDateTimeMillis(it.startDate, it.startHour, it.startMinute)
            }.minOrNull()
                    ?: return null
    val latestEndMillis =
            active.mapNotNull {
              toDateTimeMillis(it.endDate, it.endHour, it.endMinute)
            }.maxOrNull()
                    ?: return null
    return "Del ${formatDateTime(earliestStartMillis)} al ${formatDateTime(latestEndMillis)}"
  }

  private fun toDateTimeMillis(dateValue: String, hour: Int, minute: Int): Long? {
    val date = dateFormat.parse(dateValue) ?: return null
    val cal = Calendar.getInstance().apply {
      time = date
      set(Calendar.HOUR_OF_DAY, hour)
      set(Calendar.MINUTE, minute)
      set(Calendar.SECOND, 0)
      set(Calendar.MILLISECOND, 0)
    }
    return cal.timeInMillis
  }

  private fun formatDateTime(millis: Long): String {
    val cal = Calendar.getInstance().apply { timeInMillis = millis }
    val date = dateFormat.format(cal.time)
    val hour = cal.get(Calendar.HOUR_OF_DAY)
    val minute = cal.get(Calendar.MINUTE)
    return "$date ${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}"
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
              if (isExpired(r)) return@filter false
              val usage = database.dailyUsageDao().getUsage(r.packageName, today)
              usage?.isBlocked == true
            }
            .map { it.packageName }
  }

  private fun isExpired(restriction: io.github.johnivansn.timelock.database.AppRestriction): Boolean {
    val expiresAt = restriction.expiresAt ?: return false
    if (expiresAt <= 0) return false
    return System.currentTimeMillis() > expiresAt
  }

  private fun canEvaluateDirectBlocks(
          restriction: io.github.johnivansn.timelock.database.AppRestriction?
  ): Boolean {
    if (restriction == null) return true
    if (!restriction.isEnabled) return false
    return !isExpired(restriction)
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

