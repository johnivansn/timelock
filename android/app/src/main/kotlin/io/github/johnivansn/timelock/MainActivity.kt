package io.github.johnivansn.timelock

import android.app.AppOpsManager
import android.app.ActivityManager
import android.app.DownloadManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.os.BatteryManager
import android.content.IntentFilter
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
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.Environment
import android.provider.Settings
import android.util.Log
import android.webkit.URLUtil
import androidx.core.content.FileProvider
import io.github.johnivansn.timelock.admin.AdminManager
import io.github.johnivansn.timelock.database.AppDatabase
import io.github.johnivansn.timelock.database.BlockTemplate
import io.github.johnivansn.timelock.database.AppRestriction
import io.github.johnivansn.timelock.database.AppSchedule
import io.github.johnivansn.timelock.database.DateBlock
import io.github.johnivansn.timelock.optimization.AppCacheManager
import io.github.johnivansn.timelock.optimization.BatteryModeManager
import io.github.johnivansn.timelock.optimization.DataCleanupManager
import io.github.johnivansn.timelock.services.AppBlockAccessibilityService
import io.github.johnivansn.timelock.services.UsageMonitorService
import io.github.johnivansn.timelock.utils.AppUtils
import io.github.johnivansn.timelock.monitoring.UsageStatsMonitor
import io.github.johnivansn.timelock.blocking.BlockingEngine
import io.github.johnivansn.timelock.widget.AppDirectBlockWidget
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.net.ConnectException
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.net.URL
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.*
import javax.net.ssl.SSLException
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
                  "io.github.johnivansn.timelock"
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
        "getAppName" -> {
          val packageName = call.arguments as? String
          if (packageName != null) {
            result.success(getAppName(packageName))
          } else {
            result.error("INVALID_ARGUMENT", "packageName is required", null)
          }
        }
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
        "refreshWidgetsNow" -> {
          refreshWidgetsNow()
          result.success(null)
        }
        "notifyOverlayThemeChanged" -> {
          notifyOverlayThemeChanged()
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
        "updateRestriction" -> {
          val args = call.arguments as Map<*, *>
          scope.launch {
            try {
              updateRestriction(args)
              withContext(Dispatchers.Main) { result.success(null) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error updating restriction", e)
              withContext(Dispatchers.Main) {
                result.error("UPDATE_RESTRICTION_ERROR", e.message, null)
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
        "getDirectBlockPackages" -> {
          scope.launch {
            try {
              val packages = getDirectBlockPackages()
              withContext(Dispatchers.Main) { result.success(packages) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) {
                result.error("DIRECT_BLOCKS_ERROR", e.message, null)
              }
            }
          }
        }
        "deleteDirectBlocks" -> {
          val packageName = call.arguments as String
          scope.launch {
            try {
              deleteDirectBlocks(packageName)
              withContext(Dispatchers.Main) { result.success(null) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) {
                result.error("DELETE_DIRECT_BLOCKS_ERROR", e.message, null)
              }
            }
          }
        }
        "getAppVersion" -> {
          result.success(getAppVersion())
        }
        "getRuntimePackageName" -> {
          result.success(packageName)
        }
        "getSelfAppIcon" -> {
          getSelfAppIcon(result)
        }
        "getReleases" -> {
          scope.launch {
            try {
              val releases = withContext(Dispatchers.IO) { getReleases() }
              withContext(Dispatchers.Main) { result.success(releases) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error getting releases", e)
              withContext(Dispatchers.Main) {
                result.error(
                        "RELEASES_ERROR",
                        mapNetworkErrorMessage(
                                e,
                                "No se pudieron consultar las actualizaciones. Intenta de nuevo."
                        ),
                        null
                )
              }
            }
          }
        }
        "downloadAndInstallApk" -> {
          val args = call.arguments as Map<*, *>
          val url = args["url"] as String
          val shaUrl = args["shaUrl"] as? String
          scope.launch {
            try {
              val ok = downloadAndInstallApk(url, shaUrl)
              withContext(Dispatchers.Main) { result.success(ok) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) {
                result.error(
                        "APK_INSTALL_ERROR",
                        mapNetworkErrorMessage(
                                e,
                                "No se pudo instalar la versión seleccionada."
                        ),
                        null
                )
              }
            }
          }
        }
        "downloadApkOnly" -> {
          val args = call.arguments as Map<*, *>
          val url = args["url"] as String
          val fileName = args["fileName"] as? String
          try {
            val ok = downloadApkOnly(url, fileName)
            result.success(ok)
          } catch (e: Exception) {
            result.error("APK_DOWNLOAD_ERROR", e.message, null)
          }
        }
        "canInstallPackages" -> {
          result.success(canInstallPackages())
        }
        "requestInstallPermission" -> {
          requestInstallPermission()
          result.success(null)
        }
        "getBatteryLevel" -> {
          result.success(getBatteryLevel())
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
        "getMemoryClass" -> {
          val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
          result.success(am.memoryClass)
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
      "getDateBlocks" -> {
        val packageName = call.arguments as String
        scope.launch {
          try {
            val blocks = getDateBlocks(packageName)
            withContext(Dispatchers.Main) { result.success(blocks) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error getting date blocks", e)
            withContext(Dispatchers.Main) {
              result.error("GET_DATE_BLOCKS_ERROR", e.message, null)
            }
          }
        }
      }
      "addDateBlock" -> {
        val args = call.arguments as Map<*, *>
        scope.launch {
          try {
            addDateBlock(args)
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error adding date block", e)
            withContext(Dispatchers.Main) {
              result.error("ADD_DATE_BLOCK_ERROR", e.message, null)
            }
          }
        }
      }
      "updateDateBlock" -> {
        val args = call.arguments as Map<*, *>
        scope.launch {
          try {
            updateDateBlock(args)
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error updating date block", e)
            withContext(Dispatchers.Main) {
              result.error("UPDATE_DATE_BLOCK_ERROR", e.message, null)
            }
          }
        }
      }
      "deleteDateBlock" -> {
        val blockId = call.arguments as String
        scope.launch {
          try {
            deleteDateBlock(blockId)
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error deleting date block", e)
            withContext(Dispatchers.Main) {
              result.error("DELETE_DATE_BLOCK_ERROR", e.message, null)
            }
          }
        }
      }
      "getBlockTemplates" -> {
        scope.launch {
          try {
            val templates = getBlockTemplates()
            withContext(Dispatchers.Main) { result.success(templates) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error getting templates", e)
            withContext(Dispatchers.Main) {
              result.error("GET_BLOCK_TEMPLATES_ERROR", e.message, null)
            }
          }
        }
      }
      "saveBlockTemplate" -> {
        val args = call.arguments as Map<*, *>
        scope.launch {
          try {
            saveBlockTemplate(args)
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error saving template", e)
            withContext(Dispatchers.Main) {
              result.error("SAVE_BLOCK_TEMPLATE_ERROR", e.message, null)
            }
          }
        }
      }
      "deleteBlockTemplate" -> {
        val templateId = call.arguments as String
        scope.launch {
          try {
            deleteBlockTemplate(templateId)
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error deleting template", e)
            withContext(Dispatchers.Main) {
              result.error("DELETE_BLOCK_TEMPLATE_ERROR", e.message, null)
            }
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
            val success =
                    prefs.edit().run {
              when (value) {
                is Boolean -> putBoolean(key, value)
                is String -> putString(key, value)
                is Int -> putInt(key, value)
                is Long -> putLong(key, value)
                is Float -> putFloat(key, value)
                else -> remove(key)
              }
              commit()
            }
            if (!success) {
              throw IllegalStateException("No se pudo guardar $prefsName.$key")
            }

            if (prefsName == "notification_prefs") {
              if (key == "notify_service_status") {
                val enabled = value as? Boolean ?: true
                if (enabled) {
                  startMonitoringService()
                } else {
                  stopMonitoringService()
                }
              } else if (isMonitoringEnabled()) {
                val intent = Intent(this@MainActivity, UsageMonitorService::class.java)
                intent.action = UsageMonitorService.ACTION_UPDATE_NOTIFICATION
                startService(intent)
              }
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
            io.github.johnivansn.timelock.database.AppSchedule(
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
    val existing = database.appScheduleDao().getById(id) ?: return

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
    val schedule = database.appScheduleDao().getById(scheduleId) ?: return
    database.appScheduleDao().delete(schedule)
    Log.i("MainActivity", "Schedule deleted: $scheduleId")
  }

  private suspend fun getDateBlocks(packageName: String): List<Map<String, Any?>> {
    return database.dateBlockDao().getByPackage(packageName).map { block ->
      mapOf(
              "id" to block.id,
              "packageName" to block.packageName,
              "startDate" to block.startDate,
              "endDate" to block.endDate,
              "startHour" to block.startHour,
              "startMinute" to block.startMinute,
              "endHour" to block.endHour,
              "endMinute" to block.endMinute,
              "isEnabled" to block.isEnabled,
              "label" to block.label
      )
    }
  }

  private suspend fun addDateBlock(args: Map<*, *>) {
    val startHour = (args["startHour"] as? Number)?.toInt() ?: 0
    val startMinute = (args["startMinute"] as? Number)?.toInt() ?: 0
    val endHour = (args["endHour"] as? Number)?.toInt() ?: 23
    val endMinute = (args["endMinute"] as? Number)?.toInt() ?: 59
    val block =
            DateBlock(
                    id = UUID.randomUUID().toString(),
                    packageName = args["packageName"] as String,
                    startDate = args["startDate"] as String,
                    endDate = args["endDate"] as String,
                    startHour = startHour,
                    startMinute = startMinute,
                    endHour = endHour,
                    endMinute = endMinute,
                    isEnabled = args["isEnabled"] as? Boolean ?: true,
                    label = args["label"] as? String,
                    createdAt = System.currentTimeMillis()
            )
    database.dateBlockDao().insert(block)
    Log.i("MainActivity", "Date block added for ${block.packageName}")
  }

  private suspend fun updateDateBlock(args: Map<*, *>) {
    val id = args["id"] as String
    val existing = database.dateBlockDao().getById(id) ?: return

    val label =
            if (args.containsKey("label")) {
              args["label"] as? String
            } else {
              existing.label
            }

    val updated =
            existing.copy(
                    startDate = (args["startDate"] as? String) ?: existing.startDate,
                    endDate = (args["endDate"] as? String) ?: existing.endDate,
                    startHour = (args["startHour"] as? Number)?.toInt() ?: existing.startHour,
                    startMinute = (args["startMinute"] as? Number)?.toInt() ?: existing.startMinute,
                    endHour = (args["endHour"] as? Number)?.toInt() ?: existing.endHour,
                    endMinute = (args["endMinute"] as? Number)?.toInt() ?: existing.endMinute,
                    isEnabled = (args["isEnabled"] as? Boolean) ?: existing.isEnabled,
                    label = label
            )
    database.dateBlockDao().update(updated)
    Log.i("MainActivity", "Date block updated: $id")
  }

  private suspend fun deleteDateBlock(blockId: String) {
    val block = database.dateBlockDao().getById(blockId) ?: return
    database.dateBlockDao().delete(block)
    Log.i("MainActivity", "Date block deleted: $blockId")
  }

  private suspend fun getBlockTemplates(): List<Map<String, Any?>> {
    return database.blockTemplateDao().getAll().map { template ->
      mapOf(
              "id" to template.id,
              "name" to template.name,
              "type" to template.type,
              "payloadJson" to template.payloadJson,
              "createdAt" to template.createdAt
      )
    }
  }

  private suspend fun saveBlockTemplate(args: Map<*, *>) {
    val id = args["id"] as? String ?: UUID.randomUUID().toString()
    val existing = database.blockTemplateDao().getById(id)

    val name = (args["name"] as? String) ?: existing?.name ?: ""
    val type = (args["type"] as? String) ?: existing?.type ?: ""
    val payloadJson = (args["payloadJson"] as? String) ?: existing?.payloadJson ?: ""
    if (name.isBlank() || type.isBlank() || payloadJson.isBlank()) {
      throw IllegalArgumentException("name, type y payloadJson son obligatorios")
    }

    val template =
            BlockTemplate(
                    id = id,
                    name = name,
                    type = type,
                    payloadJson = payloadJson,
                    createdAt = existing?.createdAt ?: System.currentTimeMillis()
            )
    database.blockTemplateDao().insert(template)
    Log.i("MainActivity", "Block template saved: $id")
  }

  private suspend fun deleteBlockTemplate(templateId: String) {
    database.blockTemplateDao().deleteById(templateId)
    Log.i("MainActivity", "Block template deleted: $templateId")
  }

  private suspend fun exportConfig(): String {
    val restrictions = database.appRestrictionDao().getAll()
    val adminSettings = database.adminSettingsDao().get()
    val schedules = database.appScheduleDao().getAll()
    val dateBlocks = database.dateBlockDao().getAll()
    val blockTemplates = database.blockTemplateDao().getAll()

    val restrictionsData =
            restrictions.map { r ->
              mapOf(
                      "packageName" to r.packageName,
                      "appName" to r.appName,
                      "dailyQuotaMinutes" to r.dailyQuotaMinutes,
                      "isEnabled" to r.isEnabled,
                      "limitType" to r.limitType,
                      "dailyMode" to r.dailyMode,
                      "dailyQuotas" to r.dailyQuotas,
                      "weeklyQuotaMinutes" to r.weeklyQuotaMinutes,
                      "weeklyResetDay" to r.weeklyResetDay,
                      "weeklyResetHour" to r.weeklyResetHour,
                      "weeklyResetMinute" to r.weeklyResetMinute,
                      "expiresAt" to r.expiresAt
                )
              }

    val dateBlocksData =
            dateBlocks.map { b ->
              mapOf(
                      "id" to b.id,
                      "packageName" to b.packageName,
                      "startDate" to b.startDate,
                      "endDate" to b.endDate,
                      "startHour" to b.startHour,
                      "startMinute" to b.startMinute,
                      "endHour" to b.endHour,
                      "endMinute" to b.endMinute,
                      "isEnabled" to b.isEnabled,
                      "label" to b.label
              )
            }

    val schedulesData =
            schedules.map { s ->
              mapOf(
                      "id" to s.id,
                      "packageName" to s.packageName,
                      "startHour" to s.startHour,
                      "startMinute" to s.startMinute,
                      "endHour" to s.endHour,
                      "endMinute" to s.endMinute,
                      "daysOfWeek" to s.daysOfWeek,
                      "isEnabled" to s.isEnabled,
                      "createdAt" to s.createdAt
              )
            }

    val blockTemplatesData =
            blockTemplates.map { t ->
              mapOf(
                      "id" to t.id,
                      "name" to t.name,
                      "type" to t.type,
                      "payloadJson" to t.payloadJson,
                      "createdAt" to t.createdAt
              )
            }

    val exportMap =
            mutableMapOf<String, Any>(
                    "version" to 4,
                    "exportedAt" to System.currentTimeMillis(),
                    "restrictions" to restrictionsData,
                    "schedules" to schedulesData,
                    "dateBlocks" to dateBlocksData,
                    "blockTemplates" to blockTemplatesData
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
    if (version != 1 && version != 2 && version != 3 && version != 4) {
      return mapOf("success" to false, "error" to "Versión no soportada: $version")
    }

    @Suppress("UNCHECKED_CAST")
    val restrictions =
            data["restrictions"] as? List<Map<String, Any>>
                    ?: return mapOf("success" to false, "error" to "Sin restricciones en archivo")

    var imported = 0
    var skipped = 0
    var schedulesImported = 0
    var schedulesSkipped = 0

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
                        limitType = item["limitType"] as? String ?: "daily",
                        dailyMode = item["dailyMode"] as? String ?: "same",
                        dailyQuotas = item["dailyQuotas"] as? String ?: "",
                        weeklyQuotaMinutes =
                                (item["weeklyQuotaMinutes"] as? Number)?.toInt() ?: 0,
                        weeklyResetDay = (item["weeklyResetDay"] as? Number)?.toInt() ?: 2,
                        weeklyResetHour = (item["weeklyResetHour"] as? Number)?.toInt() ?: 0,
                        weeklyResetMinute = (item["weeklyResetMinute"] as? Number)?.toInt() ?: 0,
                        expiresAt = (item["expiresAt"] as? Number)?.toLong(),
                        createdAt = System.currentTimeMillis()
                )
      database.appRestrictionDao().insert(restriction)
      imported++
    }

    var dateBlocksImported = 0
    var dateBlocksSkipped = 0
    var templatesImported = 0
    var templatesSkipped = 0

    if (version >= 2) {
      @Suppress("UNCHECKED_CAST")
      val schedules =
              data["schedules"] as? List<Map<String, Any>> ?: emptyList()
      for (item in schedules) {
        val id = item["id"] as? String ?: UUID.randomUUID().toString()
        val existing = database.appScheduleDao().getById(id)
        if (existing != null) {
          schedulesSkipped++
          continue
        }

        val pkg = item["packageName"] as? String ?: continue
        val startHour = (item["startHour"] as? Number)?.toInt() ?: continue
        val startMinute = (item["startMinute"] as? Number)?.toInt() ?: 0
        val endHour = (item["endHour"] as? Number)?.toInt() ?: continue
        val endMinute = (item["endMinute"] as? Number)?.toInt() ?: 0
        val daysOfWeek = (item["daysOfWeek"] as? Number)?.toInt() ?: 0
        val isEnabled = item["isEnabled"] as? Boolean ?: true
        val createdAt = (item["createdAt"] as? Number)?.toLong() ?: System.currentTimeMillis()

        val schedule =
                AppSchedule(
                        id = id,
                        packageName = pkg,
                        startHour = startHour,
                        startMinute = startMinute,
                        endHour = endHour,
                        endMinute = endMinute,
                        daysOfWeek = daysOfWeek,
                        isEnabled = isEnabled,
                        createdAt = createdAt
                )
        database.appScheduleDao().insert(schedule)
        schedulesImported++
      }

      @Suppress("UNCHECKED_CAST")
      val dateBlocks =
              data["dateBlocks"] as? List<Map<String, Any>> ?: emptyList()
      for (item in dateBlocks) {
        val id = item["id"] as? String ?: UUID.randomUUID().toString()
        val existing = database.dateBlockDao().getById(id)
        if (existing != null) {
          dateBlocksSkipped++
          continue
        }

        val pkg = item["packageName"] as? String ?: continue
        val startDate = item["startDate"] as? String ?: continue
        val endDate = item["endDate"] as? String ?: continue
        val startHour = (item["startHour"] as? Number)?.toInt() ?: 0
        val startMinute = (item["startMinute"] as? Number)?.toInt() ?: 0
        val endHour = (item["endHour"] as? Number)?.toInt() ?: 23
        val endMinute = (item["endMinute"] as? Number)?.toInt() ?: 59
        val isEnabled = item["isEnabled"] as? Boolean ?: true
        val label = item["label"] as? String

        val block =
                DateBlock(
                        id = id,
                        packageName = pkg,
                        startDate = startDate,
                        endDate = endDate,
                        startHour = startHour,
                        startMinute = startMinute,
                        endHour = endHour,
                        endMinute = endMinute,
                        isEnabled = isEnabled,
                        label = label,
                        createdAt = System.currentTimeMillis()
                )
        database.dateBlockDao().insert(block)
        dateBlocksImported++
      }

      @Suppress("UNCHECKED_CAST")
      val templates =
              data["blockTemplates"] as? List<Map<String, Any>> ?: emptyList()
      for (item in templates) {
        val id = item["id"] as? String ?: UUID.randomUUID().toString()
        val existing = database.blockTemplateDao().getById(id)
        if (existing != null) {
          templatesSkipped++
          continue
        }

        val name = item["name"] as? String ?: continue
        val typeValue = item["type"] as? String ?: continue
        val payloadJson = item["payloadJson"] as? String ?: continue
        val createdAt = (item["createdAt"] as? Number)?.toLong() ?: System.currentTimeMillis()

        val template =
                BlockTemplate(
                        id = id,
                        name = name,
                        type = typeValue,
                        payloadJson = payloadJson,
                        createdAt = createdAt
                )
        database.blockTemplateDao().insert(template)
        templatesImported++
      }
    }

    Log.i(
            "MainActivity",
            "Import: $imported imported, $skipped skipped, " +
                    "schedules $schedulesImported/$schedulesSkipped, " +
                    "dateBlocks $dateBlocksImported/$dateBlocksSkipped, " +
                    "templates $templatesImported/$templatesSkipped"
    )
    return mapOf(
            "success" to true,
            "imported" to imported,
            "skipped" to skipped,
            "schedulesImported" to schedulesImported,
            "schedulesSkipped" to schedulesSkipped,
            "dateBlocksImported" to dateBlocksImported,
            "dateBlocksSkipped" to dateBlocksSkipped,
            "templatesImported" to templatesImported,
            "templatesSkipped" to templatesSkipped
    )
  }

  private fun hasUsageStatsPermission(): Boolean {
    return try {
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
      if (mode == AppOpsManager.MODE_ALLOWED) {
        return true
      }
      if (mode != AppOpsManager.MODE_DEFAULT) {
        return false
      }

      val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
      val end = System.currentTimeMillis()
      val start = end - 60 * 60 * 1000L

      val stats =
              usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)
      if (!stats.isNullOrEmpty()) {
        return true
      }

      val events = usageStatsManager.queryEvents(end - 60 * 1000L, end)
      val event = UsageEvents.Event()
      events != null && events.hasNextEvent().also { if (it) events.getNextEvent(event) }
    } catch (_: Exception) {
      false
    }
  }

  private fun getInstalledAppsQuick(result: MethodChannel.Result) {
    Thread {
              try {
                val pm = packageManager
                val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)

                  val appList =
                          apps.mapNotNull { app ->
                            try {
                              val cachedIcon = appCacheManager.getCachedIconBytes(app.packageName)
                              mapOf(
                                      "appName" to pm.getApplicationLabel(app).toString(),
                                      "packageName" to app.packageName,
                                      "isSystem" to
                                              ((app.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                                      "icon" to cachedIcon
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
                  val cached = appCacheManager.getCachedIconBytes(packageName)
                  if (cached != null && cached.isNotEmpty()) {
                    Handler(Looper.getMainLooper()).post { result.success(cached) }
                    return@Thread
                  }
                  val pm = packageManager
                  val app = pm.getApplicationInfo(packageName, 0)
                  val drawable = pm.getApplicationIcon(app)
  
                    val bitmap = AppUtils.drawableToBitmap(drawable, maxSize = 96)
                  val stream = ByteArrayOutputStream()
                  bitmap.compress(Bitmap.CompressFormat.PNG, 50, stream)
                  val iconBytes = stream.toByteArray()
  
                  appCacheManager.cacheIconBytes(packageName, iconBytes)
                  Handler(Looper.getMainLooper()).post { result.success(iconBytes) }
                } catch (e: Exception) {
                  if (packageName == this.packageName) {
                    getSelfAppIcon(result)
                  } else {
                    Handler(Looper.getMainLooper()).post { result.success(null) }
                  }
                }
              }
              .start()
    }

  private fun getSelfAppIcon(result: MethodChannel.Result) {
    Thread {
      try {
        val drawable = applicationInfo.loadIcon(packageManager)
        val bitmap = AppUtils.drawableToBitmap(drawable, maxSize = 96)
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
        Handler(Looper.getMainLooper()).post { result.success(stream.toByteArray()) }
      } catch (e: Exception) {
        Handler(Looper.getMainLooper()).post { result.success(null) }
      }
    }.start()
  }

  private fun requestUsageStatsPermission() {
    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
  }

  private fun isAccessibilityServiceEnabled(): Boolean {
    val component = ComponentName(this, AppBlockAccessibilityService::class.java)
    val expected = component.flattenToString()
    val expectedShort = component.flattenToShortString()
    val enabledServices =
            Settings.Secure.getString(
                    contentResolver,
                    Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
    return enabledServices
            .split(':')
            .map { it.trim() }
            .any { it.equals(expected, ignoreCase = true) || it.equals(expectedShort, ignoreCase = true) }
  }

  private fun requestAccessibilityPermission() {
    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
  }

  private fun startMonitoringService() {
    if (!isMonitoringEnabled()) {
      stopMonitoringService()
      return
    }
    val intent = Intent(this, UsageMonitorService::class.java)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      startForegroundService(intent)
    } else {
      startService(intent)
    }
  }

  private fun stopMonitoringService() {
    val intent = Intent(this, UsageMonitorService::class.java)
    stopService(intent)
  }

  private fun isMonitoringEnabled(): Boolean {
    val prefs = getSharedPreferences("notification_prefs", Context.MODE_PRIVATE)
    return prefs.getBoolean("notify_service_status", true)
  }

  private fun refreshWidgetsNow() {
    AppDirectBlockWidget.updateWidget(this)
  }

  private fun notifyOverlayThemeChanged() {
    val intent = Intent(AppBlockAccessibilityService.ACTION_OVERLAY_THEME_CHANGED)
    sendBroadcast(intent)
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
                    "io.github.johnivansn.timelock",
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

  private fun getAppVersion(): Map<String, Any?> {
    return try {
      val pm = packageManager
      val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        pm.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
      } else {
        @Suppress("DEPRECATION")
        pm.getPackageInfo(packageName, 0)
      }
      val versionCode =
              if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode
              } else {
                @Suppress("DEPRECATION")
                info.versionCode.toLong()
              }
      mapOf(
              "versionName" to (info.versionName ?: ""),
              "versionCode" to versionCode
      )
    } catch (e: Exception) {
      mapOf("versionName" to "", "versionCode" to 0L)
    }
  }

  private fun getReleases(): List<Map<String, Any?>> {
    val url = URL("https://api.github.com/repos/johnivansn/timelock/releases")
    val conn = url.openConnection() as HttpURLConnection
    conn.requestMethod = "GET"
    conn.setRequestProperty("Accept", "application/vnd.github+json")
    conn.setRequestProperty("User-Agent", "timelock")
    conn.connectTimeout = 8000
    conn.readTimeout = 8000
    conn.connect()
    val code = conn.responseCode
    if (code !in 200..299) {
      throw IllegalStateException("GitHub API error: $code")
    }
    val body = conn.inputStream.bufferedReader().use { it.readText() }
    conn.disconnect()
    val json = org.json.JSONArray(body)
    val releases = mutableListOf<Map<String, Any?>>()
    for (i in 0 until json.length()) {
      val item = json.getJSONObject(i)
      if (item.optBoolean("draft", false)) continue
      val assetsJson = item.optJSONArray("assets") ?: org.json.JSONArray()
      val assets = mutableListOf<Map<String, Any?>>()
      for (j in 0 until assetsJson.length()) {
        val asset = assetsJson.getJSONObject(j)
        assets.add(
                mapOf(
                        "name" to asset.optString("name"),
                        "url" to asset.optString("browser_download_url"),
                        "size" to asset.optLong("size", 0L)
                )
        )
      }
      releases.add(
              mapOf(
                      "tagName" to item.optString("tag_name"),
                      "name" to item.optString("name"),
                      "body" to item.optString("body"),
                      "publishedAt" to item.optString("published_at"),
                      "assets" to assets,
                      "prerelease" to item.optBoolean("prerelease", false)
              )
      )
    }
    return releases
  }

  private fun canInstallPackages(): Boolean {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      packageManager.canRequestPackageInstalls()
    } else {
      true
    }
  }

  private fun requestInstallPermission() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val intent =
              Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                      .setData(Uri.parse("package:$packageName"))
                      .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      startActivity(intent)
    }
  }

  private fun downloadAndInstallApk(url: String, shaUrl: String?): Boolean {
    val cacheDir = File(cacheDir, "apks").apply { mkdirs() }
    val apkFile = File(cacheDir, "update.apk")
    downloadToFile(url, apkFile)

    if (!shaUrl.isNullOrBlank()) {
      val expected = downloadSha256(shaUrl)
      if (expected != null) {
        val actual = sha256(apkFile)
        if (!expected.equals(actual, ignoreCase = true)) {
          apkFile.delete()
          throw IllegalStateException("SHA256 mismatch")
        }
      }
    }

    val uri =
            FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    apkFile
            )
    val intent =
            Intent(Intent.ACTION_VIEW).apply {
              setDataAndType(uri, "application/vnd.android.package-archive")
              addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
              addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
    startActivity(intent)
    return true
  }

  private fun downloadApkOnly(url: String, fileName: String?): Boolean {
    val request =
            DownloadManager.Request(Uri.parse(url)).apply {
              setTitle("TimeLock")
              setDescription("Descargando APK")
              setNotificationVisibility(
                      DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
              )
              setMimeType("application/vnd.android.package-archive")
              setAllowedOverMetered(true)
              setAllowedOverRoaming(true)
              val safeName =
                      if (fileName.isNullOrBlank()) URLUtil.guessFileName(url, null, null)
                      else fileName
              setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, safeName)
            }

    val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    manager.enqueue(request)
    return true
  }

  private fun downloadToFile(url: String, dest: File) {
    val conn = URL(url).openConnection() as HttpURLConnection
    conn.connectTimeout = 10000
    conn.readTimeout = 20000
    conn.connect()
    if (conn.responseCode !in 200..299) {
      throw IllegalStateException("Download error: ${conn.responseCode}")
    }
    BufferedInputStream(conn.inputStream).use { input ->
      FileOutputStream(dest).use { output ->
        val buffer = ByteArray(8 * 1024)
        var read: Int
        while (input.read(buffer).also { read = it } != -1) {
          output.write(buffer, 0, read)
        }
      }
    }
    conn.disconnect()
  }

  private fun downloadSha256(url: String): String? {
    val conn = URL(url).openConnection() as HttpURLConnection
    conn.connectTimeout = 8000
    conn.readTimeout = 8000
    conn.connect()
    if (conn.responseCode !in 200..299) return null
    val text = conn.inputStream.bufferedReader().use { it.readText() }
    conn.disconnect()
    val regex = Regex("([A-Fa-f0-9]{64})")
    val match = regex.find(text) ?: return null
    return match.groupValues[1]
  }

  private fun sha256(file: File): String {
    val digest = MessageDigest.getInstance("SHA-256")
    file.inputStream().use { input ->
      val buffer = ByteArray(8 * 1024)
      var read: Int
      while (input.read(buffer).also { read = it } != -1) {
        digest.update(buffer, 0, read)
      }
    }
    return digest.digest().joinToString("") { "%02x".format(it) }
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
    val limitType = (args["limitType"] as? String) ?: "daily"
    val dailyMode = (args["dailyMode"] as? String) ?: "same"
    val dailyQuotas = parseDailyQuotas(args["dailyQuotas"])
    val weeklyQuotaMinutes = (args["weeklyQuotaMinutes"] as? Number)?.toInt() ?: 0
    val weeklyResetDay = (args["weeklyResetDay"] as? Number)?.toInt() ?: 2
    val weeklyResetHour = (args["weeklyResetHour"] as? Number)?.toInt() ?: 0
    val weeklyResetMinute = (args["weeklyResetMinute"] as? Number)?.toInt() ?: 0
    val expiresAt = (args["expiresAt"] as? Number)?.toLong()
    val restriction =
            AppRestriction(
                    id = UUID.randomUUID().toString(),
                    packageName = args["packageName"] as String,
                    appName = args["appName"] as String,
                    dailyQuotaMinutes = args["dailyQuotaMinutes"] as Int,
                    isEnabled = args["isEnabled"] as Boolean,
                    limitType = limitType,
                    dailyMode = dailyMode,
                    dailyQuotas = dailyQuotas,
            weeklyQuotaMinutes = weeklyQuotaMinutes,
            weeklyResetDay = weeklyResetDay,
            weeklyResetHour = weeklyResetHour,
            weeklyResetMinute = weeklyResetMinute,
            expiresAt = expiresAt,
            createdAt = System.currentTimeMillis()
    )
    database.appRestrictionDao().insert(restriction)
  }

  private fun getBatteryLevel(): Int? {
    val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
    val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
    if (level in 0..100) return level
    val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
    val rawLevel = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
    val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
    if (rawLevel < 0 || scale <= 0) return null
    return ((rawLevel * 100f) / scale).toInt().coerceIn(0, 100)
  }

  private fun getAppName(packageName: String): String? {
    return try {
      val pm = packageManager
      val appInfo = pm.getApplicationInfo(packageName, 0)
      pm.getApplicationLabel(appInfo).toString()
    } catch (_: Exception) {
      null
    }
  }

  private suspend fun updateRestriction(args: Map<*, *>) {
    val packageName = args["packageName"] as String
    val restriction = database.appRestrictionDao().getByPackage(packageName) ?: return
    val expiresAt =
            if (args.containsKey("expiresAt")) {
              (args["expiresAt"] as? Number)?.toLong()
            } else {
              restriction.expiresAt
            }

    val updated =
            restriction.copy(
                    dailyQuotaMinutes =
                            (args["dailyQuotaMinutes"] as? Number)?.toInt()
                                    ?: restriction.dailyQuotaMinutes,
                    isEnabled = (args["isEnabled"] as? Boolean) ?: restriction.isEnabled,
                    limitType = (args["limitType"] as? String) ?: restriction.limitType,
                    dailyMode = (args["dailyMode"] as? String) ?: restriction.dailyMode,
                    dailyQuotas = parseDailyQuotas(args["dailyQuotas"], restriction.dailyQuotas),
                    weeklyQuotaMinutes =
                            (args["weeklyQuotaMinutes"] as? Number)?.toInt()
                                    ?: restriction.weeklyQuotaMinutes,
                    weeklyResetDay =
                            (args["weeklyResetDay"] as? Number)?.toInt()
                                    ?: restriction.weeklyResetDay,
                    weeklyResetHour =
                            (args["weeklyResetHour"] as? Number)?.toInt()
                                    ?: restriction.weeklyResetHour,
                    weeklyResetMinute =
                            (args["weeklyResetMinute"] as? Number)?.toInt()
                                    ?: restriction.weeklyResetMinute,
                    expiresAt = expiresAt
            )
    database.appRestrictionDao().update(updated)
  }

  private suspend fun deleteRestriction(packageName: String) {
    val restriction = database.appRestrictionDao().getByPackage(packageName) ?: return
    database.appRestrictionDao().delete(restriction)
    database.appScheduleDao().deleteByPackage(packageName)
    database.dateBlockDao().deleteByPackage(packageName)
    Log.i("MainActivity", "Deleted restriction for $packageName")
  }

  private suspend fun getDirectBlockPackages(): List<String> {
    val schedules = database.appScheduleDao().getPackages()
    val dates = database.dateBlockDao().getPackages()
    return (schedules + dates).distinct()
  }

  private suspend fun deleteDirectBlocks(packageName: String) {
    database.appScheduleDao().deleteByPackage(packageName)
    database.dateBlockDao().deleteByPackage(packageName)
    Log.i("MainActivity", "Deleted direct blocks for $packageName")
  }

  private suspend fun getRestrictions(): List<Map<String, Any?>> {
    return database.appRestrictionDao().getAll().map { restriction ->
      mapOf(
              "id" to restriction.id,
              "packageName" to restriction.packageName,
              "appName" to restriction.appName,
              "dailyQuotaMinutes" to restriction.dailyQuotaMinutes,
              "isEnabled" to restriction.isEnabled,
              "limitType" to restriction.limitType,
              "dailyMode" to restriction.dailyMode,
              "dailyQuotas" to restriction.dailyQuotas,
              "weeklyQuotaMinutes" to restriction.weeklyQuotaMinutes,
              "weeklyResetDay" to restriction.weeklyResetDay,
              "weeklyResetHour" to restriction.weeklyResetHour,
              "weeklyResetMinute" to restriction.weeklyResetMinute,
              "expiresAt" to restriction.expiresAt
      )
    }
  }

  private suspend fun getUsageToday(packageName: String): Map<String, Any> {
    val dateFormat = AppUtils.newDateFormat()
    val today = dateFormat.format(Date())
    val usage = database.dailyUsageDao().getUsage(packageName, today)
    val liveMillis = UsageStatsMonitor(this).getUsageToday(packageName)
    val restriction = database.appRestrictionDao().getByPackage(packageName)
              val weekStart =
                      if (restriction != null) AppUtils.getWeekStartDate(
                      restriction.weeklyResetDay,
                      restriction.weeklyResetHour,
                      restriction.weeklyResetMinute,
                      dateFormat
              )
              else today
    val weekUsages = database.dailyUsageDao().getUsageSince(packageName, weekStart)
    val weekMinutes = weekUsages.sumOf { it.usedMinutes }
    val blockReason = BlockingEngine(this).shouldBlockSync(packageName)
    return mapOf(
            "usedMinutes" to (usage?.usedMinutes ?: 0),
            "isBlocked" to ((usage?.isBlocked ?: false) || blockReason != null),
            "usedMillis" to liveMillis,
            "usedMinutesWeek" to weekMinutes,
            "weekStart" to weekStart
    )
  }

  private fun parseDailyQuotas(value: Any?, fallback: String = ""): String {
    if (value == null) return fallback
    if (value is String) return value
    if (value is Map<*, *>) {
      return value.entries
              .mapNotNull { (k, v) ->
                val day = k?.toString()?.toIntOrNull() ?: return@mapNotNull null
                val minutes = when (v) {
                  is Number -> v.toInt()
                  else -> v?.toString()?.toIntOrNull()
                } ?: return@mapNotNull null
                "$day:$minutes"
              }
              .joinToString(",")
    }
    return fallback
  }

  private fun enableDeviceAdmin() {
    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    val adminComponent =
            ComponentName(this, io.github.johnivansn.timelock.admin.DeviceAdminManager::class.java)

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
            ComponentName(this, io.github.johnivansn.timelock.admin.DeviceAdminManager::class.java)
    return dpm.isAdminActive(adminComponent)
  }

  companion object {
    private const val REQUEST_ENABLE_ADMIN = 1001
  }

  private fun mapNetworkErrorMessage(error: Throwable, fallback: String): String {
    val root = rootCause(error)
    return when (root) {
      is UnknownHostException, is ConnectException ->
              "Sin conexión a internet. Revisa tu red e intenta de nuevo."
      is SocketTimeoutException ->
              "La conexión tardó demasiado. Verifica tu internet e intenta otra vez."
      is SSLException -> "No se pudo establecer una conexión segura."
      else -> fallback
    }
  }

  private fun rootCause(error: Throwable): Throwable {
    var current = error
    while (current.cause != null && current.cause !== current) {
      current = current.cause!!
    }
    return current
  }
}

