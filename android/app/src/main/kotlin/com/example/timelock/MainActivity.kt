package com.example.timelock

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Log
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
  private val scope = CoroutineScope(Dispatchers.Main + Job())

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    database = AppDatabase.getDatabase(this)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call,
            result ->
      when (call.method) {
        "checkUsagePermission" -> {
          result.success(hasUsageStatsPermission())
        }
        "requestUsagePermission" -> {
          requestUsageStatsPermission()
          result.success(null)
        }
        "checkAccessibilityPermission" -> {
          result.success(isAccessibilityServiceEnabled())
        }
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
        else -> result.notImplemented()
      }
    }
  }

  override fun onDestroy() {
    super.onDestroy()
    scope.cancel()
    Log.d("MainActivity", "Coroutine scope cancelled")
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
    Log.d("MainActivity", "Monitoring service started")
  }

  private suspend fun addRestriction(args: Map<*, *>) {
    val restriction =
            AppRestriction(
                    id = UUID.randomUUID().toString(),
                    packageName = args["packageName"] as String,
                    appName = args["appName"] as String,
                    dailyQuotaMinutes = args["dailyQuotaMinutes"] as Int,
                    isEnabled = args["isEnabled"] as Boolean,
                    blockedWifiSSIDs = (args["blockedWifiSSIDs"] as? List<*>)?.map { it.toString() }
                                    ?: emptyList(),
                    createdAt = System.currentTimeMillis()
            )
    database.appRestrictionDao().insert(restriction)
    Log.d(
            "MainActivity",
            "Restriction added: ${restriction.appName} (${restriction.dailyQuotaMinutes} min)"
    )
  }

  private suspend fun getRestrictions(): List<Map<String, Any?>> {
    return database.appRestrictionDao().getAll().map { restriction ->
      mapOf(
              "id" to restriction.id,
              "packageName" to restriction.packageName,
              "appName" to restriction.appName,
              "dailyQuotaMinutes" to restriction.dailyQuotaMinutes,
              "isEnabled" to restriction.isEnabled,
              "blockedWifiSSIDs" to restriction.blockedWifiSSIDs
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
