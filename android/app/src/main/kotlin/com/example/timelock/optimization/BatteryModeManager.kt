package com.example.timelock.optimization

import android.content.Context
import android.os.PowerManager
import android.util.Log

class BatteryModeManager(private val context: Context) {
  private val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
  private val prefs = context.getSharedPreferences("battery_prefs", Context.MODE_PRIVATE)

  companion object {
    private const val KEY_BATTERY_SAVER_ENABLED = "battery_saver_enabled"
    const val NORMAL_UPDATE_INTERVAL_MS = 30000L
    const val BATTERY_SAVER_UPDATE_INTERVAL_MS = 120000L
  }

  fun isBatterySaverEnabled(): Boolean {
    return prefs.getBoolean(KEY_BATTERY_SAVER_ENABLED, false)
  }

  fun setBatterySaverEnabled(enabled: Boolean) {
    prefs.edit().putBoolean(KEY_BATTERY_SAVER_ENABLED, enabled).apply()
    Log.i("BatteryModeManager", "Battery saver mode: $enabled")
  }

  fun isDeviceInPowerSaveMode(): Boolean {
    return powerManager.isPowerSaveMode
  }

  fun getUpdateInterval(): Long {
    return if (isBatterySaverEnabled() || isDeviceInPowerSaveMode()) {
      BATTERY_SAVER_UPDATE_INTERVAL_MS
    } else {
      NORMAL_UPDATE_INTERVAL_MS
    }
  }

  fun shouldReduceTracking(): Boolean {
    return isBatterySaverEnabled() || isDeviceInPowerSaveMode()
  }
}
