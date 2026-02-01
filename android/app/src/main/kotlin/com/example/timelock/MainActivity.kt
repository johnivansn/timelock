package com.example.timelock

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Log
import android.wifi.WifiManager
import com.example.timelock.admin.AdminManager
import com.example.timelock.database.AppDatabase
import com.example.timelock.database.AppRestriction
import com.example.timelock.services.AppBlockAccessibilityService
import com.example.timelock.services.UsageMonitorService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {
  private val CHANNEL = "app.restriction/config"
  private lateinit var database: AppDatabase
  private lateinit var adminManager: AdminManager
  private val scope = CoroutineScope(Dispatchers.Main + Job())

  private val systemPackages =
          setOf(
                  "com.android.systemui",
                  "com.android.settings",
                  "com.android.launcher3",
                  "com.google.android.apps.launcher3",
                  "com.android.providers.contacts",
                  "com.android.providers.calendar",
                  "com.android.providers.telephony",
                  "com.android.providers.media",
                  "com.android.app.mediarouter",
                  "com.android.bluetooth",
                  "com.android.bluetooth.a2dp.Vol",
                  "com.android.server.bluetooth",
                  "com.android.captiveportallogin",
                  "com.android.coreui",
                  "com.android.res",
                  "com.example.timelock"
          )

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    database = AppDatabase.getDatabase(this)
    adminManager = AdminManager(this)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call,
            result ->
      when (call.method) {
        "checkUsagePermission" -> result.success(hasUsageStatsPermission())
        "requestUsagePermission" -> {
          requestUsageStatsPermission()
          result.success(null)
        }
        "checkAccessibilityPermission" -> result.success(isAccessibilityServiceEnabled())
        "requestAccessibilityPermission" -> {
          requestAccessibilityPermission()
          result.success(null)
        }
        "startMonitoring" -> {
          startMonitoringService()
          result.success(null)
        }
        "getInstalledApps" -> {
          scope.launch {
            try {
              val apps = getInstalledApps()
              withContext(Dispatchers.Main) { result.success(apps) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error getting installed apps", e)
              withContext(Dispatchers.Main) { result.error("GET_APPS_ERROR", e.message, null) }
            }
          }
        }
        "addRestriction" -> {
          val args = call.arguments as Map<*, *>
          scope.launch {
            try {
              addRestriction(args)
              withContext(Dispatchers.Main) { result.success(null) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error adding restriction", e)
              withContext(Dispatchers.Main) {
                result.error("ADD_RESTRICTION_ERROR", e.message, null)
              }
            }
          }
        }
        "deleteRestriction" -> {
          val packageName = call.arguments as String
          scope.launch {
            try {
              deleteRestriction(packageName)
              withContext(Dispatchers.Main) { result.success(null) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error deleting restriction", e)
              withContext(Dispatchers.Main) {
                result.error("DELETE_RESTRICTION_ERROR", e.message, null)
              }
            }
          }
        }
        "getRestrictions" -> {
          scope.launch {
            try {
              val restrictions = getRestrictions()
              withContext(Dispatchers.Main) { result.success(restrictions) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error getting restrictions", e)
              withContext(Dispatchers.Main) {
                result.error("GET_RESTRICTIONS_ERROR", e.message, null)
              }
            }
          }
        }
        "getUsageToday" -> {
          val packageName = call.arguments as String
          scope.launch {
            try {
              val usage = getUsageToday(packageName)
              withContext(Dispatchers.Main) { result.success(usage) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error getting usage", e)
              withContext(Dispatchers.Main) { result.error("GET_USAGE_ERROR", e.message, null) }
            }
          }
        }
        "getCurrentWifi" -> {
          result.success(getCurrentWifiSSID())
        }
        "getSavedWifiNetworks" -> {
          scope.launch {
            try {
              val networks = getSavedWifiNetworks()
              withContext(Dispatchers.Main) { result.success(networks) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error getting saved wifi", e)
              withContext(Dispatchers.Main) { result.error("GET_WIFI_ERROR", e.message, null) }
            }
          }
        }
        "updateRestrictionWifi" -> {
          val args = call.arguments as Map<*, *>
          scope.launch {
            try {
              updateRestrictionWifi(args)
              withContext(Dispatchers.Main) { result.success(null) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error updating wifi", e)
              withContext(Dispatchers.Main) { result.error("UPDATE_WIFI_ERROR", e.message, null) }
            }
          }
        }
        "isAdminEnabled" -> {
          scope.launch {
            try {
              val enabled = adminManager.isAdminEnabled()
              withContext(Dispatchers.Main) { result.success(enabled) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("ADMIN_ERROR", e.message, null) }
            }
          }
        }
        "setupAdminPin" -> {
          val pin = call.arguments as String
          scope.launch {
            try {
              val success = adminManager.setupPin(pin)
              withContext(Dispatchers.Main) { result.success(success) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("ADMIN_ERROR", e.message, null) }
            }
          }
        }
        "verifyAdminPin" -> {
          val pin = call.arguments as String
          scope.launch {
            try {
              val verifyResult = adminManager.verifyPin(pin)
              val response =
                      when (verifyResult) {
                        is AdminManager.VerifyResult.SUCCESS -> mapOf("status" to "success")
                        is AdminManager.VerifyResult.NOT_ENABLED -> mapOf("status" to "not_enabled")
                        is AdminManager.VerifyResult.WrongPin ->
                                mapOf(
                                        "status" to "wrong_pin",
                                        "attemptsRemaining" to verifyResult.attemptsRemaining
                                )
                        is AdminManager.VerifyResult.Locked ->
                                mapOf(
                                        "status" to "locked",
                                        "remainingSeconds" to verifyResult.remainingSeconds
                                )
                      }
              withContext(Dispatchers.Main) { result.success(response) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("ADMIN_ERROR", e.message, null) }
            }
          }
        }
        "disableAdmin" -> {
          scope.launch {
            try {
              val success = adminManager.disableAdmin()
              withContext(Dispatchers.Main) { result.success(success) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("ADMIN_ERROR", e.message, null) }
            }
          }
        }
        else -> result.notImplemented()
      }
    }
  }

  override fun onDestroy() {
    super.onDestroy()
    scope.cancel()
  }

  private fun hasUsageStatsPermission(): Boolean {
    val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
    val mode =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
              appOps.unsafeCheckOpNoThrow(
                      AppOpsManager.OPSTR_GET_USAGE_STATS,
                      Process.myUid(),
                      packageName
              )
            } else {
              appOps.checkOpNoThrow(
                      AppOpsManager.OPSTR_GET_USAGE_STATS,
                      Process.myUid(),
                      packageName
              )
            }
    return mode == AppOpsManager.MODE_ALLOWED
  }

  private fun requestUsageStatsPermission() {
    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
  }

  private fun isAccessibilityServiceEnabled(): Boolean {
    val service = "${packageName}/${AppBlockAccessibilityService::class.java.canonicalName}"
    val enabledServices =
            Settings.Secure.getString(
                    contentResolver,
                    Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
    return enabledServices?.contains(service) == true
  }

  private fun requestAccessibilityPermission() {
    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
  }

  private fun startMonitoringService() {
    val intent = Intent(this, UsageMonitorService::class.java)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      startForegroundService(intent)
    } else {
      startService(intent)
    }
  }

  private fun getInstalledApps(): List<Map<String, String>> {
    val pm = packageManager
    val packages = pm.getInstalledPackages(PackageManager.GET_META_DATA)
    return packages
            .filter { pkg ->
              val hasLauncher = pm.getLaunchIntentForPackage(pkg.packageName) != null
              hasLauncher && pkg.packageName !in systemPackages
            }
            .map { pkg ->
              mapOf(
                      "packageName" to pkg.packageName,
                      "appName" to pkg.applicationInfo.loadLabel(pm).toString()
              )
            }
            .sortedBy { it["appName"]?.lowercase() ?: "" }
  }

  private fun getCurrentWifiSSID(): String? {
    val wifiManager = getSystemService(WifiManager::class.java) ?: return null
    val info = wifiManager.connectionInfo ?: return null
    if (info.networkId == -1) return null
    return info.ssid?.removeSurrounding("\"")
  }

  private suspend fun getSavedWifiNetworks(): List<String> {
    val wifiManager = getSystemService(WifiManager::class.java) ?: return emptyList()
    val configs = wifiManager.configuredNetworks ?: return emptyList()
    val ssids =
            configs
                    .mapNotNull { it.SSID?.removeSurrounding("\"") }
                    .filter { it.isNotEmpty() }
                    .distinct()
                    .sorted()
    val restricted = database.appRestrictionDao().getAll()
    val allBlockedSSIDs = restricted.flatMap { it.getBlockedWifiList() }.toSet()
    return (ssids + allBlockedSSIDs).distinct().sorted()
  }

  private suspend fun updateRestrictionWifi(args: Map<*, *>) {
    val packageName = args["packageName"] as String
    val ssids = (args["blockedWifiSSIDs"] as? List<*>)?.map { it.toString() } ?: emptyList()
    val restriction = database.appRestrictionDao().getByPackage(packageName) ?: return
    database.appRestrictionDao()
            .update(restriction.copy(blockedWifiSSIDs = ssids.joinToString(",")))
    Log.i("MainActivity", "Updated WiFi blocks for $packageName: $ssids")
  }

  private suspend fun addRestriction(args: Map<*, *>) {
    val wifiList = (args["blockedWifiSSIDs"] as? List<*>)?.map { it.toString() } ?: emptyList()
    val restriction =
            AppRestriction(
                    id = UUID.randomUUID().toString(),
                    packageName = args["packageName"] as String,
                    appName = args["appName"] as String,
                    dailyQuotaMinutes = args["dailyQuotaMinutes"] as Int,
                    isEnabled = args["isEnabled"] as Boolean,
                    blockedWifiSSIDs = wifiList.joinToString(","),
                    createdAt = System.currentTimeMillis()
            )
    database.appRestrictionDao().insert(restriction)
  }

  private suspend fun deleteRestriction(packageName: String) {
    val restriction = database.appRestrictionDao().getByPackage(packageName) ?: return
    database.appRestrictionDao().delete(restriction)
    Log.i("MainActivity", "Deleted restriction for $packageName")
  }

  private suspend fun getRestrictions(): List<Map<String, Any?>> {
    return database.appRestrictionDao().getAll().map { restriction ->
      mapOf(
              "id" to restriction.id,
              "packageName" to restriction.packageName,
              "appName" to restriction.appName,
              "dailyQuotaMinutes" to restriction.dailyQuotaMinutes,
              "isEnabled" to restriction.isEnabled,
              "blockedWifiSSIDs" to restriction.getBlockedWifiList()
      )
    }
  }

  private suspend fun getUsageToday(packageName: String): Map<String, Any> {
    val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
    val today = dateFormat.format(Date())
    val usage = database.dailyUsageDao().getUsage(packageName, today)
    return mapOf(
            "usedMinutes" to (usage?.usedMinutes ?: 0),
            "isBlocked" to (usage?.isBlocked ?: false)
    )
  }
}
