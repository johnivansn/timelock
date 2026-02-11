package io.github.johnivansn.timelock.monitoring

import android.content.Context
import android.util.Log
import io.github.johnivansn.timelock.database.AppDatabase
import io.github.johnivansn.timelock.database.AppSchedule
import java.util.*

class ScheduleMonitor(private val context: Context? = null) {
  private var database: AppDatabase? = null

  init {
    if (context != null) {
      database = AppDatabase.getDatabase(context)
    }
  }

  fun isCurrentlyBlocked(schedules: List<AppSchedule>): Boolean {
    if (schedules.isEmpty()) return false
    val now = Calendar.getInstance()
    val currentHour = now.get(Calendar.HOUR_OF_DAY)
    val currentMinute = now.get(Calendar.MINUTE)
    val currentDayOfWeek = now.get(Calendar.DAY_OF_WEEK)
    val currentTimeMinutes = currentHour * 60 + currentMinute

    for (schedule in schedules) {
      if (!schedule.isEnabled) continue

      val dayBit = 1 shl (currentDayOfWeek - 1)
      val daysValue: Int = schedule.daysOfWeek
      if ((daysValue and dayBit) == 0) continue

      val startTimeMinutes = (schedule.startHour * 60) + schedule.startMinute
      val endTimeMinutes = (schedule.endHour * 60) + schedule.endMinute

      val isActive =
              if (startTimeMinutes <= endTimeMinutes) {
                currentTimeMinutes >= startTimeMinutes && currentTimeMinutes < endTimeMinutes
              } else {
                currentTimeMinutes >= startTimeMinutes || currentTimeMinutes < endTimeMinutes
              }

      if (isActive) return true
    }

    return false
  }

  fun resetNotificationFlags() {
    Log.i("ScheduleMonitor", "Schedule notification flags reset")
  }
}

