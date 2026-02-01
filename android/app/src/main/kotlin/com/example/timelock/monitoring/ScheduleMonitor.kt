package com.example.timelock.monitoring

import android.content.Context
import android.util.Log
import com.example.timelock.blocking.BlockingEngine
import com.example.timelock.database.AppDatabase
import com.example.timelock.notifications.NotificationHelper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class ScheduleMonitor(private val context: Context, private val scope: CoroutineScope) {
  private val database = AppDatabase.getDatabase(context)
  private val blockingEngine = BlockingEngine(context)
  private val notificationHelper = NotificationHelper(context)
  private val notified5MinBefore = mutableSetOf<String>()

  fun checkSchedules() {
    scope.launch(Dispatchers.IO) {
      try {
        val schedules = database.appScheduleDao().getAllEnabled()
        val scheduledPackages = schedules.map { it.packageName }.toSet()

        for (schedule in schedules) {
          if (!schedule.isEnabled) continue

          if (schedule.isActiveNow()) {
            handleScheduleActive(schedule)
          } else {
            handleScheduleInactive(schedule)
          }

          val minutesUntil = schedule.getMinutesUntilStart()
          if (minutesUntil != null && minutesUntil <= 5) {
            notifyUpcoming(schedule, minutesUntil)
          }
        }

        unblockScheduledApps(scheduledPackages)
      } catch (e: Exception) {
        Log.e("ScheduleMonitor", "Error checking schedules", e)
      }
    }
  }

  private suspend fun handleScheduleActive(schedule: com.example.timelock.database.AppSchedule) {
    val restriction = database.appRestrictionDao().getByPackage(schedule.packageName)
    if (restriction == null || !restriction.isEnabled) return

    val alreadyBlocked = blockingEngine.isBlocked(schedule.packageName)
    val quotaBlocked = blockingEngine.isQuotaBlocked(schedule.packageName)
    val wifiBlocked = blockingEngine.isWifiBlocked(schedule.packageName)

    if (!alreadyBlocked && !quotaBlocked && !wifiBlocked) {
      blockingEngine.blockApp(schedule.packageName, NotificationHelper.BlockReason.SCHEDULE_BLOCKED)
      Log.i("ScheduleMonitor", "${schedule.packageName} blocked by schedule")
    }
  }

  private suspend fun handleScheduleInactive(schedule: com.example.timelock.database.AppSchedule) {
    val restriction = database.appRestrictionDao().getByPackage(schedule.packageName)
    if (restriction == null || !restriction.isEnabled) return

    val quotaBlocked = blockingEngine.isQuotaBlocked(schedule.packageName)
    val wifiBlocked = blockingEngine.isWifiBlocked(schedule.packageName)

    if (!quotaBlocked && !wifiBlocked) {
      blockingEngine.unblockApp(schedule.packageName)
      Log.i("ScheduleMonitor", "${schedule.packageName} unblocked - schedule ended")
    }
  }

  private suspend fun unblockScheduledApps(scheduledPackages: Set<String>) {
    val restrictions = database.appRestrictionDao().getEnabled()
    for (restriction in restrictions) {
      if (restriction.packageName !in scheduledPackages) continue

      val hasActiveSchedule =
              database.appScheduleDao().getByPackage(restriction.packageName).any {
                it.isActiveNow()
              }

      if (!hasActiveSchedule) {
        val quotaBlocked = blockingEngine.isQuotaBlocked(restriction.packageName)
        val wifiBlocked = blockingEngine.isWifiBlocked(restriction.packageName)

        if (!quotaBlocked && !wifiBlocked) {
          blockingEngine.unblockApp(restriction.packageName)
        }
      }
    }
  }

  private suspend fun notifyUpcoming(
          schedule: com.example.timelock.database.AppSchedule,
          minutes: Int
  ) {
    val key = "${schedule.packageName}_${schedule.id}"
    if (notified5MinBefore.contains(key)) return

    val restriction = database.appRestrictionDao().getByPackage(schedule.packageName) ?: return
    notificationHelper.notifyScheduleUpcoming(restriction.appName, minutes)
    notified5MinBefore.add(key)
    Log.i("ScheduleMonitor", "Notified upcoming schedule for ${schedule.packageName}")
  }

  fun resetNotificationFlags() {
    notified5MinBefore.clear()
    Log.i("ScheduleMonitor", "Schedule notification flags reset")
  }
}
