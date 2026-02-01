package com.example.timelock.blocking

import android.content.Context
import android.net.wifi.WifiManager
import android.util.Log
import com.example.timelock.database.AppDatabase
import com.example.timelock.logging.ActivityLogger
import com.example.timelock.notifications.NotificationHelper
import com.example.timelock.preferences.ProfilePreferences
import java.text.SimpleDateFormat
import java.util.*

class BlockingEngine(private val context: Context) {
  private val activityLogger = ActivityLogger(context)
  private val database = AppDatabase.getDatabase(context)
  private val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
  private val notificationHelper = NotificationHelper(context)
  private val profilePrefs = ProfilePreferences(context)

  suspend fun shouldBlock(packageName: String): Boolean {
    val profileId = profilePrefs.activeProfileId
    val restriction =
            database.appRestrictionDao().getByPackageAndProfile(packageName, profileId)
                    ?: return false
    if (!restriction.isEnabled) return false
    return isQuotaBlocked(packageName) || isWifiBlocked(packageName)
  }

  suspend fun isQuotaBlocked(packageName: String): Boolean {
    val profileId = profilePrefs.activeProfileId
    val restriction =
            database.appRestrictionDao().getByPackageAndProfile(packageName, profileId)
                    ?: return false
    val today = dateFormat.format(Date())
    val usage = database.dailyUsageDao().getUsage(packageName, today) ?: return false
    return usage.usedMinutes >= restriction.dailyQuotaMinutes
  }

  suspend fun isWifiBlocked(packageName: String): Boolean {
    val profileId = profilePrefs.activeProfileId
    val restriction =
            database.appRestrictionDao().getByPackageAndProfile(packageName, profileId)
                    ?: return false
    val blockedSSIDs = restriction.getBlockedWifiList()
    if (blockedSSIDs.isEmpty()) return false
    val currentSSID = getCurrentSSID() ?: return false
    return currentSSID in blockedSSIDs
  }

  private fun getCurrentSSID(): String? {
    val wifiManager =
            context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                    ?: return null
    val info = wifiManager.connectionInfo ?: return null
    if (info.networkId == -1) return null
    return info.ssid?.removeSurrounding("\"")
  }

  suspend fun blockApp(packageName: String, reason: NotificationHelper.BlockReason): Boolean {
    val today = dateFormat.format(Date())
    val usage = database.dailyUsageDao().getUsage(packageName, today) ?: return false
    val profileId = profilePrefs.activeProfileId
    val restriction =
            database.appRestrictionDao().getByPackageAndProfile(packageName, profileId)
                    ?: return false

    if (usage.isBlocked) return true

    database.dailyUsageDao().update(usage.copy(isBlocked = true))
    notificationHelper.notifyAppBlocked(restriction.appName, reason)

    val reasonText =
            when (reason) {
              NotificationHelper.BlockReason.QUOTA_EXCEEDED -> "cuota diaria alcanzada"
              NotificationHelper.BlockReason.WIFI_BLOCKED -> "bloqueada en esta WiFi"
              NotificationHelper.BlockReason.MANUAL -> "bloqueo manual"
            }
    activityLogger.logAppBlocked(packageName, restriction.appName, reasonText)

    Log.i("BlockingEngine", "$packageName blocked - reason: $reason")
    return true
  }

  suspend fun isBlocked(packageName: String): Boolean {
    val today = dateFormat.format(Date())
    val usage = database.dailyUsageDao().getUsage(packageName, today)
    return usage?.isBlocked ?: false
  }

  suspend fun unblockApp(packageName: String) {
    val today = dateFormat.format(Date())
    val usage = database.dailyUsageDao().getUsage(packageName, today) ?: return
    if (usage.isBlocked) {
      val profileId = profilePrefs.activeProfileId
      val restriction = database.appRestrictionDao().getByPackageAndProfile(packageName, profileId)
      database.dailyUsageDao().update(usage.copy(isBlocked = false))
      if (restriction != null) {
        activityLogger.logAppUnblocked(
                packageName,
                restriction.appName,
                "reset diario o WiFi desconectado"
        )
      }
      Log.i("BlockingEngine", "$packageName unblocked")
    }
  }

  suspend fun getBlockedApps(): List<String> {
    val today = dateFormat.format(Date())
    val profileId = profilePrefs.activeProfileId
    val restrictions = database.appRestrictionDao().getEnabledForProfile(profileId)
    return restrictions
            .filter { r ->
              val usage = database.dailyUsageDao().getUsage(r.packageName, today)
              usage?.isBlocked == true
            }
            .map { it.packageName }
  }
}
