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
        val blockedWifiSSIDs: String = "",
        val createdAt: Long,
        val profileId: String = "default"
) {
  fun getBlockedWifiList(): List<String> {
    return if (blockedWifiSSIDs.isEmpty()) emptyList() else blockedWifiSSIDs.split(",")
  }
}
