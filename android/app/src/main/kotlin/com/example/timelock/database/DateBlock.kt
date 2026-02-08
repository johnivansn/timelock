package com.example.timelock.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "date_blocks")
data class DateBlock(
        @PrimaryKey val id: String,
        val packageName: String,
        val startDate: String,
        val endDate: String,
        val isEnabled: Boolean = true,
        val label: String? = null,
        val createdAt: Long = System.currentTimeMillis()
)
