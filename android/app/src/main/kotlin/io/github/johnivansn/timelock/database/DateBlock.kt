package io.github.johnivansn.timelock.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "date_blocks")
data class DateBlock(
        @PrimaryKey val id: String,
        val packageName: String,
        val startDate: String,
        val endDate: String,
        val startHour: Int = 0,
        val startMinute: Int = 0,
        val endHour: Int = 23,
        val endMinute: Int = 59,
        val isEnabled: Boolean = true,
        val label: String? = null,
        val createdAt: Long = System.currentTimeMillis()
)

