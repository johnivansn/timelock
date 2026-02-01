package com.example.timelock.database

import androidx.room.Entity
import androidx.room.PrimaryKey
import androidx.room.TypeConverters

@Entity(tableName = "app_restrictions")
@TypeConverters(Converters::class)
data class AppRestriction(
    @PrimaryKey val id: String,
    val packageName: String,
    val appName: String,
    val dailyQuotaMinutes: Int,
    val isEnabled: Boolean,
    val blockedWifiSSIDs: List<String>,
    val createdAt: Long
)