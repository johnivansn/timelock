package io.github.johnivansn.timelock.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "app_restrictions")
data class AppRestriction(
        @PrimaryKey val id: String,
        val packageName: String,
        val appName: String,
        val dailyQuotaMinutes: Int,
        val isEnabled: Boolean,
        val limitType: String = "daily",
        val dailyMode: String = "same",
        val dailyQuotas: String = "",
        val weeklyQuotaMinutes: Int = 0,
        val weeklyResetDay: Int = 2,
        val weeklyResetHour: Int = 0,
        val weeklyResetMinute: Int = 0,
        val expiresAt: Long? = null,
        val createdAt: Long
)

fun AppRestriction.getDailyQuotasMap(): Map<Int, Int> {
  if (dailyQuotas.isBlank()) return emptyMap()
  return dailyQuotas.split(",")
          .mapNotNull {
            val parts = it.split(":")
            if (parts.size != 2) return@mapNotNull null
            val day = parts[0].toIntOrNull() ?: return@mapNotNull null
            val minutes = parts[1].toIntOrNull() ?: return@mapNotNull null
            day to minutes
          }
          .toMap()
}

fun AppRestriction.getDailyQuotaForDay(dayOfWeek: Int): Int {
  if (limitType != "daily") return 0
  return if (dailyMode == "per_day") {
    getDailyQuotasMap()[dayOfWeek] ?: 0
  } else {
    dailyQuotaMinutes
  }
}

