package com.example.timelock.logging

import android.content.Context
import com.example.timelock.database.ActivityLog
import com.example.timelock.database.AppDatabase
import com.google.gson.Gson
import java.util.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class ActivityLogger(context: Context) {
  private val database = AppDatabase.getDatabase(context)
  private val scope = CoroutineScope(Dispatchers.IO)
  private val gson = Gson()

  fun logAppBlocked(packageName: String, appName: String, reason: String) {
    scope.launch {
      val log =
              ActivityLog(
                      id = UUID.randomUUID().toString(),
                      timestamp = System.currentTimeMillis(),
                      eventType = ActivityLog.EVENT_APP_BLOCKED,
                      packageName = packageName,
                      appName = appName,
                      details = reason,
                      metadata = null
              )
      database.activityLogDao().insert(log)
    }
  }

  fun logAppUnblocked(packageName: String, appName: String, reason: String) {
    scope.launch {
      val log =
              ActivityLog(
                      id = UUID.randomUUID().toString(),
                      timestamp = System.currentTimeMillis(),
                      eventType = ActivityLog.EVENT_APP_UNBLOCKED,
                      packageName = packageName,
                      appName = appName,
                      details = reason,
                      metadata = null
              )
      database.activityLogDao().insert(log)
    }
  }

  fun logQuotaChanged(packageName: String, appName: String, oldQuota: Int, newQuota: Int) {
    scope.launch {
      val metadata = mapOf("oldQuota" to oldQuota, "newQuota" to newQuota)
      val log =
              ActivityLog(
                      id = UUID.randomUUID().toString(),
                      timestamp = System.currentTimeMillis(),
                      eventType = ActivityLog.EVENT_QUOTA_CHANGED,
                      packageName = packageName,
                      appName = appName,
                      details = "Cuota cambiada: ${oldQuota}m → ${newQuota}m",
                      metadata = gson.toJson(metadata)
              )
      database.activityLogDao().insert(log)
    }
  }

  fun logRestrictionAdded(packageName: String, appName: String, quota: Int) {
    scope.launch {
      val log =
              ActivityLog(
                      id = UUID.randomUUID().toString(),
                      timestamp = System.currentTimeMillis(),
                      eventType = ActivityLog.EVENT_RESTRICTION_ADDED,
                      packageName = packageName,
                      appName = appName,
                      details = "Restricción agregada: ${quota}m diarios",
                      metadata = gson.toJson(mapOf("quota" to quota))
              )
      database.activityLogDao().insert(log)
    }
  }

  fun logRestrictionRemoved(packageName: String, appName: String) {
    scope.launch {
      val log =
              ActivityLog(
                      id = UUID.randomUUID().toString(),
                      timestamp = System.currentTimeMillis(),
                      eventType = ActivityLog.EVENT_RESTRICTION_REMOVED,
                      packageName = packageName,
                      appName = appName,
                      details = "Restricción eliminada",
                      metadata = null
              )
      database.activityLogDao().insert(log)
    }
  }

  fun logWifiUpdated(packageName: String, appName: String, ssids: List<String>) {
    scope.launch {
      val details =
              if (ssids.isEmpty()) {
                "Redes WiFi eliminadas"
              } else {
                "Redes WiFi actualizadas: ${ssids.joinToString(", ")}"
              }
      val log =
              ActivityLog(
                      id = UUID.randomUUID().toString(),
                      timestamp = System.currentTimeMillis(),
                      eventType = ActivityLog.EVENT_WIFI_UPDATED,
                      packageName = packageName,
                      appName = appName,
                      details = details,
                      metadata = gson.toJson(mapOf("ssids" to ssids))
              )
      database.activityLogDao().insert(log)
    }
  }

  fun logPinChanged() {
    scope.launch {
      val log =
              ActivityLog(
                      id = UUID.randomUUID().toString(),
                      timestamp = System.currentTimeMillis(),
                      eventType = ActivityLog.EVENT_PIN_CHANGED,
                      packageName = null,
                      appName = null,
                      details = "PIN de administrador cambiado",
                      metadata = null
              )
      database.activityLogDao().insert(log)
    }
  }

  fun logAdminEnabled() {
    scope.launch {
      val log =
              ActivityLog(
                      id = UUID.randomUUID().toString(),
                      timestamp = System.currentTimeMillis(),
                      eventType = ActivityLog.EVENT_ADMIN_ENABLED,
                      packageName = null,
                      appName = null,
                      details = "Modo administrador activado",
                      metadata = null
              )
      database.activityLogDao().insert(log)
    }
  }

  fun logAdminDisabled() {
    scope.launch {
      val log =
              ActivityLog(
                      id = UUID.randomUUID().toString(),
                      timestamp = System.currentTimeMillis(),
                      eventType = ActivityLog.EVENT_ADMIN_DISABLED,
                      packageName = null,
                      appName = null,
                      details = "Modo administrador desactivado",
                      metadata = null
              )
      database.activityLogDao().insert(log)
    }
  }

  fun logBackupCreated(restrictionCount: Int) {
    scope.launch {
      val log =
              ActivityLog(
                      id = UUID.randomUUID().toString(),
                      timestamp = System.currentTimeMillis(),
                      eventType = ActivityLog.EVENT_BACKUP_CREATED,
                      packageName = null,
                      appName = null,
                      details = "Backup creado: $restrictionCount restricciones",
                      metadata = gson.toJson(mapOf("count" to restrictionCount))
              )
      database.activityLogDao().insert(log)
    }
  }

  fun logBackupRestored(imported: Int, skipped: Int) {
    scope.launch {
      val log =
              ActivityLog(
                      id = UUID.randomUUID().toString(),
                      timestamp = System.currentTimeMillis(),
                      eventType = ActivityLog.EVENT_BACKUP_RESTORED,
                      packageName = null,
                      appName = null,
                      details = "Backup restaurado: $imported importadas, $skipped omitidas",
                      metadata = gson.toJson(mapOf("imported" to imported, "skipped" to skipped))
              )
      database.activityLogDao().insert(log)
    }
  }

  suspend fun purgeOldLogs(daysToKeep: Int = 30) {
    val cutoffTime = System.currentTimeMillis() - (daysToKeep * 24 * 60 * 60 * 1000L)
    database.activityLogDao().deleteOldLogs(cutoffTime)
  }
}

