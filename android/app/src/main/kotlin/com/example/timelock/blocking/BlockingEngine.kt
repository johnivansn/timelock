package com.example.timelock.blocking

import android.content.Context
import android.net.wifi.WifiManager
import android.util.Log
import com.example.timelock.database.AppDatabase
import java.text.SimpleDateFormat
import java.util.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class BlockingEngine(private val context: Context) {
  private val database = AppDatabase.getDatabase(context)
  private val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
  private val scope = CoroutineScope(Dispatchers.IO)

  suspend fun shouldBlock(packageName: String): Boolean {
    val restriction = database.appRestrictionDao().getByPackage(packageName) ?: return false
    if (!restriction.isEnabled) return false

    if (isQuotaBlocked(packageName)) return true
    if (isWifiBlocked(packageName)) return true

    return false
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

  fun blockApp(packageName: String, callback: (Boolean) -> Unit) {
    scope.launch {
      val today = dateFormat.format(Date())
      var usage = database.dailyUsageDao().getUsage(packageName, today)

      if (usage != null) {
        if (!usage.isBlocked) {
          database.dailyUsageDao().update(usage.copy(isBlocked = true))
          Log.i("BlockingEngine", "$packageName blocked")
        }
        withContext(Dispatchers.Main) { callback(true) }
      } else {
        withContext(Dispatchers.Main) { callback(false) }
      }
    }
  }

  suspend fun isBlocked(packageName: String): Boolean {
    val today = dateFormat.format(Date())
    val usage = database.dailyUsageDao().getUsage(packageName, today)
    return usage?.isBlocked ?: false
  }

  fun unblockApp(packageName: String) {
    scope.launch {
      val today = dateFormat.format(Date())
      val usage = database.dailyUsageDao().getUsage(packageName, today) ?: return@launch
      if (usage.isBlocked) {
        database.dailyUsageDao().update(usage.copy(isBlocked = false))
        Log.i("BlockingEngine", "$packageName unblocked")
      }
    }
  }

  suspend fun getBlockedApps(): List<String> {
    val today = dateFormat.format(Date())
    val restrictions = database.appRestrictionDao().getEnabled()
    val blockedApps = mutableListOf<String>()

    for (restriction in restrictions) {
      val usage = database.dailyUsageDao().getUsage(restriction.packageName, today)
      if (usage?.isBlocked == true) {
        blockedApps.add(restriction.packageName)
      }
    }

    return blockedApps
  }
}
