package io.github.johnivansn.timelock.optimization

import android.content.Context
import android.os.BatteryManager
import android.os.PowerManager
import android.content.Intent
import android.content.IntentFilter
import android.util.Log

class BatteryModeManager(private val context: Context) {
  private val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
  private val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
  private val prefs = context.getSharedPreferences("battery_prefs", Context.MODE_PRIVATE)

  companion object {
    private const val KEY_BATTERY_SAVER_ENABLED = "battery_saver_enabled"
    private const val KEY_AUTO_ENABLED = "battery_auto_enabled"
    private const val KEY_AUTO_THRESHOLD = "battery_auto_threshold"
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

  fun isAutoEnabled(): Boolean {
    return prefs.getBoolean(KEY_AUTO_ENABLED, false)
  }

  fun getAutoThreshold(): Int {
    return prefs.getInt(KEY_AUTO_THRESHOLD, 25).coerceIn(5, 80)
  }

  fun isDeviceInPowerSaveMode(): Boolean {
    return powerManager.isPowerSaveMode
  }

  private fun getBatteryLevelPercent(): Int {
    val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
    if (level in 0..100) return level
    val intent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
    val rawLevel = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
    val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
    if (rawLevel < 0 || scale <= 0) return -1
    return ((rawLevel * 100f) / scale).toInt().coerceIn(0, 100)
  }

  fun isAutoBatterySaverActive(): Boolean {
    if (!isAutoEnabled()) return false
    val level = getBatteryLevelPercent()
    if (level < 0) return false
    return level <= getAutoThreshold()
  }

  fun getUpdateInterval(): Long {
    return if (isBatterySaverEnabled() || isAutoBatterySaverActive() || isDeviceInPowerSaveMode()) {
      BATTERY_SAVER_UPDATE_INTERVAL_MS
    } else {
      NORMAL_UPDATE_INTERVAL_MS
    }
  }

  fun shouldReduceTracking(): Boolean {
    return isBatterySaverEnabled() || isAutoBatterySaverActive() || isDeviceInPowerSaveMode()
  }
}

