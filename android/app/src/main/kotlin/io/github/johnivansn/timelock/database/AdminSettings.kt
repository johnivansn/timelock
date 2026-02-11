package io.github.johnivansn.timelock.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "admin_settings")
data class AdminSettings(
        @PrimaryKey val id: Int = 1,
        val isEnabled: Boolean = false,
        val pinHash: String = "",
        val failedAttempts: Int = 0,
        val lockedUntil: Long = 0L
)

