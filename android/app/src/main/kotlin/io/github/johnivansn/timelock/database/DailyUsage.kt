package io.github.johnivansn.timelock.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "daily_usage")
data class DailyUsage(
    @PrimaryKey val id: String,
    val packageName: String,
    val date: String,
    val usedMinutes: Int,
    val isBlocked: Boolean,
    val lastUpdated: Long
)
