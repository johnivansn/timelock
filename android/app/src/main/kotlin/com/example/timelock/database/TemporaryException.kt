package com.example.timelock.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "temporary_exceptions")
data class TemporaryException(
        @PrimaryKey val id: String,
        val packageName: String,
        val appName: String,
        val startTime: Long,
        val durationMinutes: Int,
        val createdAt: Long
) {
  fun isActive(): Boolean {
    val now = System.currentTimeMillis()
    val endTime = startTime + (durationMinutes * 60 * 1000)
    return now in startTime..endTime
  }
  fun getRemainingMinutes(): Int {
    if (!isActive()) return 0
    val now = System.currentTimeMillis()
    val endTime = startTime + (durationMinutes * 60 * 1000)
    val remainingMs = endTime - now
    return ((remainingMs + 59999) / 60000).toInt()
  }
  fun getEndTime(): Long {
    return startTime + (durationMinutes * 60 * 1000)
  }
}
