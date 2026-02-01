package com.example.timelock.preferences

import android.content.Context
import android.content.SharedPreferences

class ProfilePreferences(context: Context) {
  private val prefs: SharedPreferences =
          context.getSharedPreferences("profile_prefs", Context.MODE_PRIVATE)

  companion object {
    private const val KEY_ACTIVE_PROFILE = "active_profile_id"
  }

  var activeProfileId: String
    get() = prefs.getString(KEY_ACTIVE_PROFILE, "default") ?: "default"
    set(value) = prefs.edit().putString(KEY_ACTIVE_PROFILE, value).apply()
}
