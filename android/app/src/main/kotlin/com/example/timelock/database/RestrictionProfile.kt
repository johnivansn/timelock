package com.example.timelock.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "restriction_profiles")
data class RestrictionProfile(
        @PrimaryKey val id: String,
        val name: String,
        val isDefault: Boolean = false,
        val createdAt: Long = System.currentTimeMillis()
)
