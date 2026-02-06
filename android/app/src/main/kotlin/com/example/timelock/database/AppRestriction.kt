package com.example.timelock.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "app_restrictions")
data class AppRestriction(
        @PrimaryKey val id: String,
        val packageName: String,
        val appName: String,
        val dailyQuotaMinutes: Int,
        val isEnabled: Boolean,
        val createdAt: Long
)
