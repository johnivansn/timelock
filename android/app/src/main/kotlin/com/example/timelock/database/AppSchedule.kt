package com.example.timelock.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "app_schedules")
data class AppSchedule(
        @PrimaryKey val id: String,
        val packageName: String,
        val startHour: Int,
        val startMinute: Int,
        val endHour: Int,
        val endMinute: Int,
        val daysOfWeek: String,
        val isEnabled: Boolean,
        val createdAt: Long
) {
  fun getDaysOfWeekList(): List<Int> {
    return if (daysOfWeek.isEmpty()) emptyList() else daysOfWeek.split(",").map { it.toInt() }
  }

  fun isActiveOnDay(dayOfWeek: Int): Boolean {
    return dayOfWeek in getDaysOfWeekList()
  }

  fun isActiveNow(): Boolean {
    val calendar = java.util.Calendar.getInstance()
    val currentDay = calendar.get(java.util.Calendar.DAY_OF_WEEK)
    if (!isActiveOnDay(currentDay)) return false

    val currentHour = calendar.get(java.util.Calendar.HOUR_OF_DAY)
    val currentMinute = calendar.get(java.util.Calendar.MINUTE)
    val currentTimeMinutes = currentHour * 60 + currentMinute
    val startTimeMinutes = startHour * 60 + startMinute
    val endTimeMinutes = endHour * 60 + endMinute

    return if (endTimeMinutes > startTimeMinutes) {
      currentTimeMinutes in startTimeMinutes until endTimeMinutes
    } else {
      currentTimeMinutes >= startTimeMinutes || currentTimeMinutes < endTimeMinutes
    }
  }

  fun getMinutesUntilStart(): Int? {
    val calendar = java.util.Calendar.getInstance()
    val currentDay = calendar.get(java.util.Calendar.DAY_OF_WEEK)
    if (!isActiveOnDay(currentDay)) return null

    val currentHour = calendar.get(java.util.Calendar.HOUR_OF_DAY)
    val currentMinute = calendar.get(java.util.Calendar.MINUTE)
    val currentTimeMinutes = currentHour * 60 + currentMinute
    val startTimeMinutes = startHour * 60 + startMinute

    val diff = startTimeMinutes - currentTimeMinutes
    return if (diff > 0 && diff <= 5) diff else null
  }
}
