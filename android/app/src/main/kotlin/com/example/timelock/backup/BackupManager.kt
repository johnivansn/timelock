package com.example.timelock.backup

import android.content.Context
import android.util.Log
import com.example.timelock.database.AppDatabase
import com.google.gson.Gson
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

class BackupManager(private val context: Context) {
  private val database = AppDatabase.getDatabase(context)
  private val gson = Gson()
  private val dateFormat = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault())

  companion object {
    private const val BACKUP_DIR = "backups"
    private const val MAX_BACKUPS = 7
    private const val BACKUP_VERSION = 2
  }

  private fun getBackupDir(): File {
    val dir = File(context.filesDir, BACKUP_DIR)
    if (!dir.exists()) dir.mkdirs()
    return dir
  }

  suspend fun createBackup(): File? {
    return try {
      val restrictions = database.appRestrictionDao().getAll()
      val adminSettings = database.adminSettingsDao().get()

      val restrictionsData =
              restrictions.map { r ->
                mapOf(
                        "packageName" to r.packageName,
                        "appName" to r.appName,
                        "dailyQuotaMinutes" to r.dailyQuotaMinutes,
                        "isEnabled" to r.isEnabled,
                        "blockedWifiSSIDs" to r.getBlockedWifiList(),
                        "createdAt" to r.createdAt
                )
              }

      val backupData =
              mutableMapOf<String, Any>(
                      "version" to BACKUP_VERSION,
                      "timestamp" to System.currentTimeMillis(),
                      "appVersion" to "1.0.0",
                      "restrictions" to restrictionsData
              )

      if (adminSettings != null && adminSettings.isEnabled) {
        backupData["adminMode"] = mapOf("enabled" to true)
      }

      val json = gson.toJson(backupData)
      val timestamp = dateFormat.format(Date())
      val file = File(getBackupDir(), "backup_$timestamp.json")
      file.writeText(json)

      rotateBackups()
      Log.i("BackupManager", "Backup created: ${file.name}")
      file
    } catch (e: Exception) {
      Log.e("BackupManager", "Failed to create backup", e)
      null
    }
  }

  private fun rotateBackups() {
    val backups =
            getBackupDir()
                    .listFiles()
                    ?.filter { it.name.startsWith("backup_") }
                    ?.sortedByDescending { it.lastModified() }
                    ?: return
    if (backups.size > MAX_BACKUPS) {
      backups.drop(MAX_BACKUPS).forEach { file ->
        file.delete()
        Log.i("BackupManager", "Deleted old backup: ${file.name}")
      }
    }
  }

  suspend fun restoreBackup(file: File): RestoreResult {
    return try {
      val json = file.readText()
      val data =
              gson.fromJson(json, Map::class.java) as? Map<String, Any>
                      ?: return RestoreResult.Error("Invalid backup format")

      val version = (data["version"] as? Number)?.toInt() ?: 1
      if (version > BACKUP_VERSION) {
        return RestoreResult.Error("Backup version $version not supported")
      }

      @Suppress("UNCHECKED_CAST")
      val restrictions =
              data["restrictions"] as? List<Map<String, Any>>
                      ?: return RestoreResult.Error("No restrictions in backup")

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
                com.example.timelock.database.AppRestriction(
                        id = UUID.randomUUID().toString(),
                        packageName = pkg,
                        appName = item["appName"] as? String ?: pkg,
                        dailyQuotaMinutes = (item["dailyQuotaMinutes"] as? Number)?.toInt() ?: 60,
                        isEnabled = item["isEnabled"] as? Boolean ?: true,
                        blockedWifiSSIDs = wifiList.joinToString(","),
                        createdAt = (item["createdAt"] as? Number)?.toLong()
                                        ?: System.currentTimeMillis()
                )
        database.appRestrictionDao().insert(restriction)
        imported++
      }

      Log.i("BackupManager", "Restore complete: $imported imported, $skipped skipped")
      RestoreResult.Success(imported, skipped)
    } catch (e: Exception) {
      Log.e("BackupManager", "Failed to restore backup", e)
      RestoreResult.Error(e.message ?: "Unknown error")
    }
  }

  fun listBackups(): List<BackupInfo> {
    val backups =
            getBackupDir()
                    .listFiles()
                    ?.filter { it.name.startsWith("backup_") }
                    ?.sortedByDescending { it.lastModified() }
                    ?: emptyList()
    return backups.map { file ->
      try {
        val json = file.readText()
        val data = gson.fromJson(json, Map::class.java) as? Map<String, Any>
        val timestamp = (data?.get("timestamp") as? Number)?.toLong() ?: file.lastModified()
        @Suppress("UNCHECKED_CAST")
        val restrictions = (data?.get("restrictions") as? List<Map<String, Any>>)?.size ?: 0

        BackupInfo(
                file = file,
                timestamp = timestamp,
                size = file.length(),
                restrictionCount = restrictions,
                hasAdminMode = data?.containsKey("adminMode") == true
        )
      } catch (e: Exception) {
        BackupInfo(
                file = file,
                timestamp = file.lastModified(),
                size = file.length(),
                restrictionCount = 0,
                hasAdminMode = false
        )
      }
    }
  }

  fun getLatestBackup(): BackupInfo? {
    return listBackups().maxByOrNull { it.timestamp }
  }

  fun deleteBackup(file: File): Boolean {
    return try {
      file.delete()
      Log.i("BackupManager", "Deleted backup: ${file.name}")
      true
    } catch (e: Exception) {
      Log.e("BackupManager", "Failed to delete backup", e)
      false
    }
  }

  sealed class RestoreResult {
    data class Success(val imported: Int, val skipped: Int) : RestoreResult()
    data class Error(val message: String) : RestoreResult()
  }

  data class BackupInfo(
          val file: File,
          val timestamp: Long,
          val size: Long,
          val restrictionCount: Int,
          val hasAdminMode: Boolean
  ) {
    fun formatDate(): String {
      val dateFormat = SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.getDefault())
      return dateFormat.format(Date(timestamp))
    }

    fun formatSize(): String {
      return when {
        size < 1024 -> "$size B"
        size < 1024 * 1024 -> "${size / 1024} KB"
        else -> "${size / (1024 * 1024)} MB"
      }
    }
  }
}
