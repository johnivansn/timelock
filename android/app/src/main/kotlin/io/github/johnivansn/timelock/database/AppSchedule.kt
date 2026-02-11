package io.github.johnivansn.timelock.database

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
        val daysOfWeek: Int = 0,
        val isEnabled: Boolean = true,
        val createdAt: Long = System.currentTimeMillis()
) {
  fun getDaysOfWeekList(): List<Int> {
    val mask = daysOfWeek and 0xFF
    return (0..6).filter { (mask and (1 shl it)) != 0 }
  }

  fun isActiveOnDay(dayOfWeek: Int): Boolean {
    val dayBit = 1 shl (dayOfWeek - 1)
    return (daysOfWeek and dayBit) != 0
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

