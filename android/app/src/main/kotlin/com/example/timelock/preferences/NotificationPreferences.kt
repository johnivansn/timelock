package com.example.timelock.preferences

import android.content.Context
import android.content.SharedPreferences

class NotificationPreferences(context: Context) {
  private val prefs: SharedPreferences =
          context.getSharedPreferences("notification_prefs", Context.MODE_PRIVATE)

  companion object {
    private const val KEY_QUOTA_50 = "notify_quota_50"
    private const val KEY_QUOTA_75 = "notify_quota_75"
    private const val KEY_LAST_MINUTE = "notify_last_minute"
    private const val KEY_BLOCKED = "notify_blocked"
    private const val KEY_SCHEDULE = "notify_schedule"
    private const val KEY_SERVICE_NOTIFICATION = "notify_service_status"
  }

  var quota50Enabled: Boolean
    get() = prefs.getBoolean(KEY_QUOTA_50, true)
    set(value) = prefs.edit().putBoolean(KEY_QUOTA_50, value).apply()

  var quota75Enabled: Boolean
    get() = prefs.getBoolean(KEY_QUOTA_75, true)
    set(value) = prefs.edit().putBoolean(KEY_QUOTA_75, value).apply()

  var lastMinuteEnabled: Boolean
    get() = prefs.getBoolean(KEY_LAST_MINUTE, true)
    set(value) = prefs.edit().putBoolean(KEY_LAST_MINUTE, value).apply()

  var blockedEnabled: Boolean
    get() = prefs.getBoolean(KEY_BLOCKED, true)
    set(value) = prefs.edit().putBoolean(KEY_BLOCKED, value).apply()

  var scheduleEnabled: Boolean
    get() = prefs.getBoolean(KEY_SCHEDULE, true)
    set(value) = prefs.edit().putBoolean(KEY_SCHEDULE, value).apply()

  var serviceNotificationEnabled: Boolean
    get() = prefs.getBoolean(KEY_SERVICE_NOTIFICATION, true)
    set(value) = prefs.edit().putBoolean(KEY_SERVICE_NOTIFICATION, value).apply()

  fun getAll(): Map<String, Boolean> {
    return mapOf(
            "quota50" to quota50Enabled,
            "quota75" to quota75Enabled,
            "lastMinute" to lastMinuteEnabled,
            "blocked" to blockedEnabled,
            "schedule" to scheduleEnabled,
            "serviceNotification" to serviceNotificationEnabled
    )
  }

  fun saveAll(settings: Map<String, Boolean>) {
    prefs.edit().apply {
      settings["quota50"]?.let { putBoolean(KEY_QUOTA_50, it) }
      settings["quota75"]?.let { putBoolean(KEY_QUOTA_75, it) }
      settings["lastMinute"]?.let { putBoolean(KEY_LAST_MINUTE, it) }
      settings["blocked"]?.let { putBoolean(KEY_BLOCKED, it) }
      settings["schedule"]?.let { putBoolean(KEY_SCHEDULE, it) }
      settings["serviceNotification"]?.let { putBoolean(KEY_SERVICE_NOTIFICATION, it) }
      apply()
    }
  }
}
