package com.example.timelock

import android.app.AppOpsManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Log
import com.example.timelock.admin.AdminManager
import com.example.timelock.backup.AutoBackupWorker
import com.example.timelock.backup.BackupManager
import com.example.timelock.database.AppDatabase
import com.example.timelock.database.AppRestriction
import com.example.timelock.logging.ActivityLogger
import com.example.timelock.logging.LogCleanupWorker
import com.example.timelock.monitoring.NetworkMonitor
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
  private lateinit var backupManager: BackupManager
  private lateinit var activityLogger: ActivityLogger
  private val CHANNEL = "app.restriction/config"
  private lateinit var database: AppDatabase
  private lateinit var adminManager: AdminManager
  private val scope = CoroutineScope(Dispatchers.Main + Job())
  private val systemPackages =
          setOf(
                  "android",
                  "com.android.systemui",
                  "com.android.settings",
                  "com.google.android.gms",
                  "com.google.android.gsf",
                  "com.example.timelock"
          )

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    database = AppDatabase.getDatabase(this)
    adminManager = AdminManager(this)
    backupManager = BackupManager(this)
    activityLogger = ActivityLogger(this)
    LogCleanupWorker.schedule(this)

    AutoBackupWorker.schedule(this)

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
          val nm = NetworkMonitor(this, CoroutineScope(Dispatchers.IO + Job()))
          result.success(nm.getCurrentSSID())
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
        "getNotificationSettings" -> {
          val prefs = com.example.timelock.preferences.NotificationPreferences(this)
          result.success(prefs.getAll())
        }
        "saveNotificationSettings" -> {
          val args = call.arguments as Map<*, *>
          val prefs = com.example.timelock.preferences.NotificationPreferences(this)
          val settings =
                  mapOf(
                          "quota25" to (args["quota25"] as Boolean),
                          "quota10" to (args["quota10"] as Boolean),
                          "blocked" to (args["blocked"] as Boolean)
                  )
          prefs.saveAll(settings)
          result.success(null)
        }
        "exportConfig" -> {
          scope.launch {
            try {
              val config = exportConfig()
              withContext(Dispatchers.Main) { result.success(config) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error exporting config", e)
              withContext(Dispatchers.Main) { result.error("EXPORT_ERROR", e.message, null) }
            }
          }
        }
        "importConfig" -> {
          val json = call.arguments as String
          scope.launch {
            try {
              val importResult = importConfig(json)
              withContext(Dispatchers.Main) { result.success(importResult) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error importing config", e)
              withContext(Dispatchers.Main) { result.error("IMPORT_ERROR", e.message, null) }
            }
          }
        }
        "enableDeviceAdmin" -> {
          enableDeviceAdmin()
          result.success(null)
        }
        "isDeviceAdminEnabled" -> {
          result.success(isDeviceAdminEnabled())
        }
        "createManualBackup" -> {
          scope.launch {
            try {
              val file = backupManager.createBackup()
              withContext(Dispatchers.Main) { result.success(file != null) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("BACKUP_ERROR", e.message, null) }
            }
          }
        }
        "listBackups" -> {
          scope.launch {
            try {
              val backups =
                      backupManager.listBackups().map { backup ->
                        mapOf(
                                "path" to backup.file.absolutePath,
                                "timestamp" to backup.timestamp,
                                "formattedDate" to backup.formatDate(),
                                "size" to backup.size,
                                "formattedSize" to backup.formatSize(),
                                "restrictionCount" to backup.restrictionCount,
                                "hasAdminMode" to backup.hasAdminMode,
                                "isAutomatic" to backup.file.name.startsWith("backup_")
                        )
                      }
              withContext(Dispatchers.Main) { result.success(backups) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("LIST_BACKUPS_ERROR", e.message, null) }
            }
          }
        }
        "restoreBackup" -> {
          val path = call.arguments as String
          scope.launch {
            try {
              val file = java.io.File(path)
              val restoreResult = backupManager.restoreBackup(file)
              val response =
                      when (restoreResult) {
                        is BackupManager.RestoreResult.Success ->
                                mapOf(
                                        "success" to true,
                                        "imported" to restoreResult.imported,
                                        "skipped" to restoreResult.skipped
                                )
                        is BackupManager.RestoreResult.Error ->
                                mapOf("success" to false, "error" to restoreResult.message)
                      }
              withContext(Dispatchers.Main) { result.success(response) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("RESTORE_ERROR", e.message, null) }
            }
          }
        }
        "deleteBackup" -> {
          val path = call.arguments as String
          scope.launch {
            try {
              val file = java.io.File(path)
              val deleted = backupManager.deleteBackup(file)
              withContext(Dispatchers.Main) { result.success(deleted) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("DELETE_BACKUP_ERROR", e.message, null) }
            }
          }
        }
        "checkBackupOnFirstLaunch" -> {
          scope.launch {
            try {
              val prefs = getSharedPreferences("app_prefs", Context.MODE_PRIVATE)
              val isFirstLaunch = prefs.getBoolean("is_first_launch", true)

              if (isFirstLaunch) {
                prefs.edit().putBoolean("is_first_launch", false).apply()
                val latestBackup = backupManager.getLatestBackup()

                if (latestBackup != null) {
                  val backupInfo =
                          mapOf(
                                  "exists" to true,
                                  "path" to latestBackup.file.absolutePath,
                                  "formattedDate" to latestBackup.formatDate(),
                                  "restrictionCount" to latestBackup.restrictionCount
                          )
                  withContext(Dispatchers.Main) { result.success(backupInfo) }
                } else {
                  withContext(Dispatchers.Main) { result.success(mapOf("exists" to false)) }
                }
              } else {
                withContext(Dispatchers.Main) { result.success(mapOf("exists" to false)) }
              }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("CHECK_BACKUP_ERROR", e.message, null) }
            }
          }
        }
        "getActivityLogs" -> {
          scope.launch {
            try {
              val logs = database.activityLogDao().getRecent(200)
              val logsData =
                      logs.map { log ->
                        mapOf(
                                "id" to log.id,
                                "timestamp" to log.timestamp,
                                "eventType" to log.eventType,
                                "packageName" to log.packageName,
                                "appName" to log.appName,
                                "details" to log.details,
                                "metadata" to log.metadata
                        )
                      }
              withContext(Dispatchers.Main) { result.success(logsData) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("GET_LOGS_ERROR", e.message, null) }
            }
          }
        }
        "clearActivityLogs" -> {
          scope.launch {
            try {
              database.activityLogDao().deleteAll()
              withContext(Dispatchers.Main) { result.success(true) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("CLEAR_LOGS_ERROR", e.message, null) }
            }
          }
        }
        "exportActivityLogs" -> {
          scope.launch {
            try {
              val logs = database.activityLogDao().getRecent(1000)
              val csv = buildString {
                appendLine("Timestamp,Date,Event Type,App Name,Package Name,Details")
                logs.forEach { log ->
                  val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                  val date = dateFormat.format(Date(log.timestamp))
                  appendLine(
                          "${log.timestamp},\"$date\",\"${log.eventType}\",\"${log.appName ?: ""}\",\"${log.packageName ?: ""}\",\"${log.details}\""
                  )
                }
              }
              withContext(Dispatchers.Main) { result.success(csv) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("EXPORT_LOGS_ERROR", e.message, null) }
            }
          }
        }
        "getActivityLogs" -> {
          scope.launch {
            try {
              val logs = database.activityLogDao().getRecent(200)
              val logsData =
                      logs.map { log ->
                        mapOf(
                                "id" to log.id,
                                "timestamp" to log.timestamp,
                                "eventType" to log.eventType,
                                "packageName" to log.packageName,
                                "appName" to log.appName,
                                "details" to log.details,
                                "metadata" to log.metadata
                        )
                      }
              withContext(Dispatchers.Main) { result.success(logsData) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("GET_LOGS_ERROR", e.message, null) }
            }
          }
        }
        "clearActivityLogs" -> {
          scope.launch {
            try {
              database.activityLogDao().deleteAll()
              withContext(Dispatchers.Main) { result.success(true) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("CLEAR_LOGS_ERROR", e.message, null) }
            }
          }
        }
        "exportActivityLogs" -> {
          scope.launch {
            try {
              val logs = database.activityLogDao().getRecent(1000)
              val csv = buildString {
                appendLine("Timestamp,Date,Event Type,App Name,Package Name,Details")
                logs.forEach { log ->
                  val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                  val date = dateFormat.format(Date(log.timestamp))
                  appendLine(
                          "${log.timestamp},\"$date\",\"${log.eventType}\",\"${log.appName ?: ""}\",\"${log.packageName ?: ""}\",\"${log.details}\""
                  )
                }
              }
              withContext(Dispatchers.Main) { result.success(csv) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("EXPORT_LOGS_ERROR", e.message, null) }
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

  private suspend fun exportConfig(): String {
    val restrictions = database.appRestrictionDao().getAll()
    val adminSettings = database.adminSettingsDao().get()

    val restrictionsData =
            restrictions.map { r ->
              mapOf(
                      "packageName" to r.packageName,
                      "appName" to r.appName,
                      "dailyQuotaMinutes" to r.dailyQuotaMinutes,
                      "isEnabled" to r.isEnabled,
                      "blockedWifiSSIDs" to r.getBlockedWifiList()
              )
            }

    val exportMap =
            mutableMapOf<String, Any>(
                    "version" to 1,
                    "exportedAt" to System.currentTimeMillis(),
                    "restrictions" to restrictionsData
            )

    if (adminSettings != null && adminSettings.isEnabled) {
      exportMap["adminMode"] = mapOf("enabled" to true)
    }

    return com.google.gson.Gson().toJson(exportMap)
  }

  private suspend fun importConfig(json: String): Map<String, Any> {
    val gson = com.google.gson.Gson()
    val data =
            gson.fromJson(json, Map<String, Any>::class.java)
                    ?: return mapOf("success" to false, "error" to "JSON inválido")

    val version = (data["version"] as? Number)?.toInt() ?: 0
    if (version != 1) {
      return mapOf("success" to false, "error" to "Versión no soportada: $version")
    }

    @Suppress("UNCHECKED_CAST")
    val restrictions =
            data["restrictions"] as? List<Map<String, Any>>
                    ?: return mapOf("success" to false, "error" to "Sin restricciones en archivo")

    var imported = 0
    var skipped = 0

    for (item in restrictions) {
      val pkg = item["packageName"] as? String ?: continue
      val existing = database.appRestrictionDao().getByPackage(pkg)
      if (existing != null) {
        skipped++
        continue
      }

      @Suppress("UNCHECKED_CAST")
      val wifiList = (item["blockedWifiSSIDs"] as? List<String>) ?: emptyList()

      val restriction =
              AppRestriction(
                      id = java.util.UUID.randomUUID().toString(),
                      packageName = pkg,
                      appName = item["appName"] as? String ?: pkg,
                      dailyQuotaMinutes = (item["dailyQuotaMinutes"] as? Number)?.toInt() ?: 60,
                      isEnabled = item["isEnabled"] as? Boolean ?: true,
                      blockedWifiSSIDs = wifiList.joinToString(","),
                      createdAt = System.currentTimeMillis()
              )
      database.appRestrictionDao().insert(restriction)
      imported++
    }

    Log.i("MainActivity", "Import: $imported imported, $skipped skipped")
    return mapOf("success" to true, "imported" to imported, "skipped" to skipped)
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
    val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)

    return packages
            .filter { appInfo ->
              val packageName = appInfo.packageName
              val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
              val isUpdatedSystem = (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0

              !systemPackages.any { packageName.startsWith(it) } && (!isSystem || isUpdatedSystem)
            }
            .map { appInfo ->
              mapOf(
                      "packageName" to appInfo.packageName,
                      "appName" to appInfo.loadLabel(pm).toString()
              )
            }
            .sortedBy { it["appName"]?.lowercase() ?: "" }
  }

  private suspend fun getSavedWifiNetworks(): List<String> {
    val wifiManager =
            applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                    ?: return emptyList()

    val allSSIDs = mutableSetOf<String>()

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      val connectivityManager =
              getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
      val network = connectivityManager.activeNetwork
      val capabilities = connectivityManager.getNetworkCapabilities(network)

      if (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true) {
        val currentSSID = wifiManager.connectionInfo?.ssid?.removeSurrounding("\"")
        if (!currentSSID.isNullOrEmpty() && currentSSID != "<unknown ssid>") {
          allSSIDs.add(currentSSID)
        }
      }
    } else {
      @Suppress("DEPRECATION") val configs = wifiManager.configuredNetworks ?: emptyList()
      configs
              .mapNotNull { it.SSID?.removeSurrounding("\"") }
              .filter { it.isNotEmpty() && it != "<unknown ssid>" }
              .forEach { allSSIDs.add(it) }
    }

    val restricted = database.appRestrictionDao().getAll()
    restricted.flatMap { it.getBlockedWifiList() }.filter { it.isNotEmpty() }.forEach {
      allSSIDs.add(it)
    }

    return allSSIDs.sorted()
  }

  private suspend fun updateRestrictionWifi(args: Map<*, *>) {
    val packageName = args["packageName"] as String
    val ssids = (args["blockedWifiSSIDs"] as? List<*>)?.map { it.toString() } ?: emptyList()
    val restriction = database.appRestrictionDao().getByPackage(packageName) ?: return
    database.appRestrictionDao()
            .update(restriction.copy(blockedWifiSSIDs = ssids.joinToString(",")))
    activityLogger.logWifiUpdated(packageName, restriction.appName, ssids)
    Log.i("MainActivity", "Updated WiFi blocks for $packageName: $ssids")
  }

  private suspend fun addRestriction(args: Map<*, *>) {
    val wifiList = (args["blockedWifiSSIDs"] as? List<*>)?.map { it.toString() } ?: emptyList()
    val packageName = args["packageName"] as String
    val appName = args["appName"] as String
    val quota = args["dailyQuotaMinutes"] as Int

    val restriction =
            AppRestriction(
                    id = java.util.UUID.randomUUID().toString(),
                    packageName = packageName,
                    appName = appName,
                    dailyQuotaMinutes = quota,
                    isEnabled = args["isEnabled"] as Boolean,
                    blockedWifiSSIDs = wifiList.joinToString(","),
                    createdAt = System.currentTimeMillis()
            )
    database.appRestrictionDao().insert(restriction)
    activityLogger.logRestrictionAdded(packageName, appName, quota)
  }

  private suspend fun deleteRestriction(packageName: String) {
    val restriction = database.appRestrictionDao().getByPackage(packageName) ?: return
    database.appRestrictionDao().delete(restriction)
    activityLogger.logRestrictionRemoved(packageName, restriction.appName)
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
  private fun enableDeviceAdmin() {
    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    val adminComponent =
            ComponentName(this, com.example.timelock.admin.DeviceAdminManager::class.java)

    if (!dpm.isAdminActive(adminComponent)) {
      val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
      intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
      intent.putExtra(
              DevicePolicyManager.EXTRA_ADD_EXPLANATION,
              "Protege contra desinstalación accidental de la app"
      )
      startActivityForResult(intent, REQUEST_ENABLE_ADMIN)
    }
  }

  private fun isDeviceAdminEnabled(): Boolean {
    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    val adminComponent =
            ComponentName(this, com.example.timelock.admin.DeviceAdminManager::class.java)
    return dpm.isAdminActive(adminComponent)
  }
}

companion

object {
  private const val REQUEST_ENABLE_ADMIN = 1001
}
