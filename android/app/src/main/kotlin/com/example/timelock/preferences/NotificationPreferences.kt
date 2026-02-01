package com.example.timelock.preferences

import android.content.Context
import android.content.SharedPreferences

class NotificationPreferences(context: Context) {
  private val prefs: SharedPreferences =
          context.getSharedPreferences("notification_prefs", Context.MODE_PRIVATE)

  companion object {
    private const val KEY_QUOTA_25 = "notify_quota_25"
    private const val KEY_QUOTA_10 = "notify_quota_10"
    private const val KEY_BLOCKED = "notify_blocked"
  }

  var quota25Enabled: Boolean
    get() = prefs.getBoolean(KEY_QUOTA_25, true)
    set(value) = prefs.edit().putBoolean(KEY_QUOTA_25, value).apply()

  var quota10Enabled: Boolean
    get() = prefs.getBoolean(KEY_QUOTA_10, true)
    set(value) = prefs.edit().putBoolean(KEY_QUOTA_10, value).apply()

  var blockedEnabled: Boolean
    get() = prefs.getBoolean(KEY_BLOCKED, true)
    set(value) = prefs.edit().putBoolean(KEY_BLOCKED, value).apply()

  fun getAll(): Map<String, Boolean> {
    return mapOf(
            "quota25" to quota25Enabled,
            "quota10" to quota10Enabled,
            "blocked" to blockedEnabled
    )
  }

  fun saveAll(settings: Map<String, Boolean>) {
    prefs.edit().apply {
      settings["quota25"]?.let { putBoolean(KEY_QUOTA_25, it) }
      settings["quota10"]?.let { putBoolean(KEY_QUOTA_10, it) }
      settings["blocked"]?.let { putBoolean(KEY_BLOCKED, it) }
      apply()
    }
  }
}
