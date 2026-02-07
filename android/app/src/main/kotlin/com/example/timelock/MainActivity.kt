package com.example.timelock

import android.app.AppOpsManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.Settings
import android.util.Log
import com.example.timelock.admin.AdminManager
import com.example.timelock.database.AppDatabase
import com.example.timelock.database.AppRestriction
import com.example.timelock.optimization.AppCacheManager
import com.example.timelock.optimization.BatteryModeManager
import com.example.timelock.optimization.DataCleanupManager
import com.example.timelock.services.AppBlockAccessibilityService
import com.example.timelock.services.UsageMonitorService
import com.example.timelock.utils.AppUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
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
  private lateinit var appCacheManager: AppCacheManager
  private lateinit var batteryModeManager: BatteryModeManager
  private lateinit var dataCleanupManager: DataCleanupManager
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
    appCacheManager = AppCacheManager(this)
    batteryModeManager = BatteryModeManager(this)
    dataCleanupManager = DataCleanupManager(this)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call,
            result ->
      when (call.method) {
        "getInstalledApps" -> getInstalledAppsQuick(result)
        "getAppIcon" -> {
          val packageName = call.arguments as? String
          if (packageName != null) {
            getAppIcon(packageName, result)
          } else {
            result.error("INVALID_ARGUMENT", "packageName is required", null)
          }
        }
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
        else -> {
          handleMethodCallPart2(call, result)
        }
      }
    }
  }

  private fun handleMethodCallPart2(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "getSchedules" -> {
        val packageName = call.arguments as String
        scope.launch {
          try {
            val schedules = getSchedules(packageName)
            withContext(Dispatchers.Main) { result.success(schedules) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error getting schedules", e)
            withContext(Dispatchers.Main) { result.error("GET_SCHEDULES_ERROR", e.message, null) }
          }
        }
      }
      "checkOverlayPermission" -> {
        result.success(android.provider.Settings.canDrawOverlays(this))
      }
      "requestOverlayPermission" -> {
        val intent =
                Intent(
                        android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        android.net.Uri.parse("package:$packageName")
                )
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        result.success(null)
      }
      "addSchedule" -> {
        val args = call.arguments as Map<*, *>
        scope.launch {
          try {
            addSchedule(args)
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error adding schedule", e)
            withContext(Dispatchers.Main) { result.error("ADD_SCHEDULE_ERROR", e.message, null) }
          }
        }
      }
      "updateSchedule" -> {
        val args = call.arguments as Map<*, *>
        scope.launch {
          try {
            updateSchedule(args)
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error updating schedule", e)
            withContext(Dispatchers.Main) { result.error("UPDATE_SCHEDULE_ERROR", e.message, null) }
          }
        }
      }
      "deleteSchedule" -> {
        val scheduleId = call.arguments as String
        scope.launch {
          try {
            deleteSchedule(scheduleId)
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error deleting schedule", e)
            withContext(Dispatchers.Main) { result.error("DELETE_SCHEDULE_ERROR", e.message, null) }
          }
        }
      }
      "setBatterySaverMode" -> {
        val enabled = call.arguments as Boolean
        batteryModeManager.setBatterySaverEnabled(enabled)
        result.success(null)
      }
      "isBatterySaverEnabled" -> {
        result.success(batteryModeManager.isBatterySaverEnabled())
      }
      "getOptimizationStats" -> {
        scope.launch {
          try {
            val stats = getOptimizationStats()
            withContext(Dispatchers.Main) { result.success(stats) }
          } catch (e: Exception) {
            withContext(Dispatchers.Main) { result.error("STATS_ERROR", e.message, null) }
          }
        }
      }
      "invalidateCache" -> {
        scope.launch {
          try {
            appCacheManager.invalidateCache()
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            withContext(Dispatchers.Main) { result.error("CACHE_ERROR", e.message, null) }
          }
        }
      }
      "forceCleanup" -> {
        scope.launch {
          try {
            dataCleanupManager.forceCleanup()
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            withContext(Dispatchers.Main) { result.error("CLEANUP_ERROR", e.message, null) }
          }
        }
      }
      "getSharedPreferences" -> {
        val prefsName = call.arguments as String
        scope.launch {
          try {
            val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            val map = prefs.all.mapValues { (_, v) -> v }
            withContext(Dispatchers.Main) { result.success(map) }
          } catch (e: Exception) {
            withContext(Dispatchers.Main) { result.error("PREFS_ERROR", e.message, null) }
          }
        }
      }
      "saveSharedPreference" -> {
        val args = call.arguments as Map<*, *>
        val prefsName = args["prefsName"] as String
        val key = args["key"] as String
        val value = args["value"]

        scope.launch {
          try {
            val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            prefs.edit().apply {
              when (value) {
                is Boolean -> putBoolean(key, value)
                is String -> putString(key, value)
                is Int -> putInt(key, value)
                is Long -> putLong(key, value)
                is Float -> putFloat(key, value)
                else -> remove(key)
              }
              apply()
            }

            if (prefsName == "notification_prefs") {
              val intent = Intent(this@MainActivity, UsageMonitorService::class.java)
              intent.action = UsageMonitorService.ACTION_UPDATE_NOTIFICATION
              startService(intent)
            }

            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            withContext(Dispatchers.Main) { result.error("PREFS_ERROR", e.message, null) }
          }
        }
      }
      else -> result.notImplemented()
    }
  }

  override fun onDestroy() {
    super.onDestroy()
    scope.cancel()
  }

  private suspend fun getSchedules(packageName: String): List<Map<String, Any>> {
    return database.appScheduleDao().getByPackage(packageName).map { schedule ->
      mapOf(
              "id" to schedule.id,
              "packageName" to schedule.packageName,
              "startHour" to schedule.startHour,
              "startMinute" to schedule.startMinute,
              "endHour" to schedule.endHour,
              "endMinute" to schedule.endMinute,
              "daysOfWeek" to schedule.getDaysOfWeekList().map { it + 1 },
              "isEnabled" to schedule.isEnabled
      )
    }
  }

  private suspend fun addSchedule(args: Map<*, *>) {
    val daysList = (args["daysOfWeek"] as? List<*>)?.map { it.toString().toInt() } ?: emptyList()
    val daysOfWeek = daysList.fold(0) { mask, day -> mask or (1 shl (day - 1)) }
    val schedule =
            com.example.timelock.database.AppSchedule(
                    id = java.util.UUID.randomUUID().toString(),
                    packageName = args["packageName"] as String,
                    startHour = (args["startHour"] as? Number)?.toInt() ?: 0,
                    startMinute = (args["startMinute"] as? Number)?.toInt() ?: 0,
                    endHour = (args["endHour"] as? Number)?.toInt() ?: 0,
                    endMinute = (args["endMinute"] as? Number)?.toInt() ?: 0,
                    daysOfWeek = daysOfWeek,
                    isEnabled = args["isEnabled"] as? Boolean ?: true,
                    createdAt = System.currentTimeMillis()
            )
    database.appScheduleDao().insert(schedule)
    Log.i("MainActivity", "Schedule added for ${schedule.packageName}")
  }

  private suspend fun updateSchedule(args: Map<*, *>) {
    val id = args["id"] as String
    val schedules = database.appScheduleDao().getAllEnabled()
    val existing = schedules.find { it.id == id } ?: return

    val daysList =
            (args["daysOfWeek"] as? List<*>)?.map { it.toString().toInt() }
                    ?: existing.getDaysOfWeekList()
    val daysOfWeek = daysList.fold(0) { mask, day -> mask or (1 shl (day - 1)) }
    val updated =
            existing.copy(
                    startHour = (args["startHour"] as? Number)?.toInt() ?: existing.startHour,
                    startMinute = (args["startMinute"] as? Number)?.toInt() ?: existing.startMinute,
                    endHour = (args["endHour"] as? Number)?.toInt() ?: existing.endHour,
                    endMinute = (args["endMinute"] as? Number)?.toInt() ?: existing.endMinute,
                    daysOfWeek = daysOfWeek,
                    isEnabled = args["isEnabled"] as? Boolean ?: existing.isEnabled
            )
    database.appScheduleDao().update(updated)
    Log.i("MainActivity", "Schedule updated: $id")
  }

  private suspend fun deleteSchedule(scheduleId: String) {
    val schedules = database.appScheduleDao().getAllEnabled()
    val schedule = schedules.find { it.id == scheduleId } ?: return
    database.appScheduleDao().delete(schedule)
    Log.i("MainActivity", "Schedule deleted: $scheduleId")
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
                      "isEnabled" to r.isEnabled
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
    val type = object : com.google.gson.reflect.TypeToken<Map<String, Any>>() {}.type
    val data =
            gson.fromJson<Map<String, Any>>(json, type)
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

      val restriction =
              AppRestriction(
                      id = java.util.UUID.randomUUID().toString(),
                      packageName = pkg,
                      appName = item["appName"] as? String ?: pkg,
                      dailyQuotaMinutes = (item["dailyQuotaMinutes"] as? Number)?.toInt() ?: 60,
                      isEnabled = item["isEnabled"] as? Boolean ?: true,
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

  private fun getInstalledAppsQuick(result: MethodChannel.Result) {
    Thread {
              try {
                val pm = packageManager
                val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)

                val appList =
                        apps.mapNotNull { app ->
                          try {
                            mapOf(
                                    "appName" to pm.getApplicationLabel(app).toString(),
                                    "packageName" to app.packageName,
                                    "isSystem" to
                                            ((app.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                                    "icon" to null // Sin ícono por ahora
                            )
                          } catch (e: Exception) {
                            null
                          }
                        }

                Handler(Looper.getMainLooper()).post { result.success(appList) }
              } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                  result.error("ERROR", "Error getting apps: ${e.message}", null)
                }
              }
            }
            .start()
  }

  private fun getAppIcon(packageName: String, result: MethodChannel.Result) {
    Thread {
              try {
                val pm = packageManager
                val app = pm.getApplicationInfo(packageName, 0)
                val drawable = pm.getApplicationIcon(app)

                val bitmap = drawableToBitmap(drawable)
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 50, stream)
                val iconBytes = stream.toByteArray()

                Handler(Looper.getMainLooper()).post { result.success(iconBytes) }
              } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post { result.success(null) }
              }
            }
            .start()
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

  private fun getInstalledApps(): List<Map<String, Any>> {
    val pm = packageManager

    val packages =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
              pm.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0L))
            } else {
              pm.getInstalledApplications(PackageManager.GET_META_DATA)
            }

    val coreSystemPackages =
            setOf(
                    "com.example.timelock",
                    "com.android.systemui",
                    "android",
                    "com.android.system",
                    "com.android.settings"
            )

    return packages
            .filter { it.packageName !in coreSystemPackages }
            .distinctBy { it.packageName }
            .map { appInfo ->
              val hasSystemFlag = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
              val hasUpdatedFlag = (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
              val sourceDir = appInfo.sourceDir ?: ""

              val isSystem =
                      when {
                        hasUpdatedFlag -> false
                        sourceDir.contains("/data/app/") -> false
                        hasSystemFlag -> true
                        sourceDir.contains("/system/") || sourceDir.contains("/product/") -> true
                        else -> false
                      }

              val appName =
                      try {
                        appInfo.loadLabel(pm).toString()
                      } catch (_: Exception) {
                        appInfo.packageName
                      }

              val iconBytes =
                      try {
                        val drawable = appInfo.loadIcon(pm)
                        val bitmap = AppUtils.drawableToBitmap(drawable)
                        val stream = java.io.ByteArrayOutputStream()
                        bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)
                        stream.toByteArray()
                      } catch (_: Exception) {
                        null
                      }

              mapOf<String, Any>(
                      "packageName" to appInfo.packageName,
                      "appName" to appName,
                      "isSystem" to isSystem,
                      "icon" to (iconBytes ?: byteArrayOf())
              )
            }
            .sortedWith(
                    compareBy(
                            { (it["isSystem"] as? Boolean) ?: false },
                            { it["appName"]?.toString()?.lowercase() ?: "" }
                    )
            )
  }

  private suspend fun getOptimizationStats(): Map<String, Any> {
    val cleanupStats = dataCleanupManager.getCleanupStats()
    val cacheSize = appCacheManager.getCacheSize()

    return mapOf(
            "batterySaverEnabled" to batteryModeManager.isBatterySaverEnabled(),
            "updateIntervalMs" to batteryModeManager.getUpdateInterval(),
            "cacheSizeKB" to (cacheSize / 1024),
            "databaseSizeMB" to cleanupStats["databaseSizeMB"]!!,
            "usageRecordCount" to cleanupStats["usageRecordCount"]!!,
            "lastCleanup" to cleanupStats["lastCleanup"]!!
    )
  }

  private suspend fun addRestriction(args: Map<*, *>) {
    val restriction =
            AppRestriction(
                    id = UUID.randomUUID().toString(),
                    packageName = args["packageName"] as String,
                    appName = args["appName"] as String,
                    dailyQuotaMinutes = args["dailyQuotaMinutes"] as Int,
                    isEnabled = args["isEnabled"] as Boolean,
                    createdAt = System.currentTimeMillis()
            )
    database.appRestrictionDao().insert(restriction)
  }

  private suspend fun deleteRestriction(packageName: String) {
    val restriction = database.appRestrictionDao().getByPackage(packageName) ?: return
    database.appRestrictionDao().delete(restriction)
    database.appScheduleDao().deleteByPackage(packageName)
    Log.i("MainActivity", "Deleted restriction for $packageName")
  }

  private suspend fun getRestrictions(): List<Map<String, Any?>> {
    return database.appRestrictionDao().getAll().map { restriction ->
      mapOf(
              "id" to restriction.id,
              "packageName" to restriction.packageName,
              "appName" to restriction.appName,
              "dailyQuotaMinutes" to restriction.dailyQuotaMinutes,
              "isEnabled" to restriction.isEnabled
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

  private fun drawableToBitmap(drawable: Drawable): Bitmap {
    if (drawable is BitmapDrawable) {
      return drawable.bitmap
    }

    val width = if (drawable.intrinsicWidth > 0) minOf(drawable.intrinsicWidth, 96) else 96
    val height = if (drawable.intrinsicHeight > 0) minOf(drawable.intrinsicHeight, 96) else 96

    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    drawable.setBounds(0, 0, canvas.width, canvas.height)
    drawable.draw(canvas)

    return bitmap
  }

  private fun isDeviceAdminEnabled(): Boolean {
    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    val adminComponent =
            ComponentName(this, com.example.timelock.admin.DeviceAdminManager::class.java)
    return dpm.isAdminActive(adminComponent)
  }

  companion object {
    private const val REQUEST_ENABLE_ADMIN = 1001
  }
}
