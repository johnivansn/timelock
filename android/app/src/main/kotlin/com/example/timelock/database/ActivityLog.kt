package com.example.timelock.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "activity_logs")
data class ActivityLog(
        @PrimaryKey val id: String,
        val timestamp: Long,
        val eventType: String,
        val packageName: String?,
        val appName: String?,
        val details: String,
        val metadata: String?
) {
  companion object {
    const val EVENT_APP_BLOCKED = "app_blocked"
    const val EVENT_APP_UNBLOCKED = "app_unblocked"
    const val EVENT_QUOTA_CHANGED = "quota_changed"
    const val EVENT_RESTRICTION_ADDED = "restriction_added"
    const val EVENT_RESTRICTION_REMOVED = "restriction_removed"
    const val EVENT_WIFI_UPDATED = "wifi_updated"
    const val EVENT_PIN_CHANGED = "pin_changed"
    const val EVENT_ADMIN_ENABLED = "admin_enabled"
    const val EVENT_ADMIN_DISABLED = "admin_disabled"
    const val EVENT_BACKUP_CREATED = "backup_created"
    const val EVENT_BACKUP_RESTORED = "backup_restored"
    const val EVENT_EXCEPTION_GRANTED = "exception_granted"
    const val EVENT_EXCEPTION_EXPIRED = "exception_expired"
  }
}
