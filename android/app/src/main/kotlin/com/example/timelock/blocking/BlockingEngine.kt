package com.example.timelock.blocking

import android.content.Context
import android.net.wifi.WifiManager
import android.util.Log
import com.example.timelock.database.AppDatabase
import com.example.timelock.notifications.NotificationHelper
import java.text.SimpleDateFormat
import java.util.*

class BlockingEngine(private val context: Context) {
  private val database = AppDatabase.getDatabase(context)
  private val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
  private val notificationHelper = NotificationHelper(context)

  suspend fun shouldBlock(packageName: String): Boolean {
    val restriction = database.appRestrictionDao().getByPackage(packageName) ?: return false
    if (!restriction.isEnabled) return false
    return isQuotaBlocked(packageName) || isWifiBlocked(packageName)
  }

  suspend fun isQuotaBlocked(packageName: String): Boolean {
    val restriction = database.appRestrictionDao().getByPackage(packageName) ?: return false
    val today = dateFormat.format(Date())
    val usage = database.dailyUsageDao().getUsage(packageName, today) ?: return false
    return usage.usedMinutes >= restriction.dailyQuotaMinutes
  }

  suspend fun isWifiBlocked(packageName: String): Boolean {
    val restriction = database.appRestrictionDao().getByPackage(packageName) ?: return false
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
    val restriction = database.appRestrictionDao().getByPackage(packageName) ?: return false

    if (usage.isBlocked) return true

    database.dailyUsageDao().update(usage.copy(isBlocked = true))
    notificationHelper.notifyAppBlocked(restriction.appName, reason)
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
      database.dailyUsageDao().update(usage.copy(isBlocked = false))
      Log.i("BlockingEngine", "$packageName unblocked")
    }
  }

  suspend fun getBlockedApps(): List<String> {
    val today = dateFormat.format(Date())
    val restrictions = database.appRestrictionDao().getEnabled()
    return restrictions
            .filter { r ->
              val usage = database.dailyUsageDao().getUsage(r.packageName, today)
              usage?.isBlocked == true
            }
            .map { it.packageName }
  }
}
