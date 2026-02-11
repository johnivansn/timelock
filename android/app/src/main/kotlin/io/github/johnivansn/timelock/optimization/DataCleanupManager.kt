package io.github.johnivansn.timelock.optimization

import android.content.Context
import android.util.Log
import io.github.johnivansn.timelock.utils.AppUtils
import io.github.johnivansn.timelock.database.AppDatabase
import java.text.SimpleDateFormat
import java.util.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class DataCleanupManager(private val context: Context) {
  private val database = AppDatabase.getDatabase(context)
  private val dateFormat = AppUtils.newDateFormat()
  private val prefs = context.getSharedPreferences("cleanup_prefs", Context.MODE_PRIVATE)

  companion object {
    private const val KEY_LAST_CLEANUP = "last_cleanup"
    private const val CLEANUP_INTERVAL_MS = 24 * 60 * 60 * 1000L
    private const val USAGE_DATA_RETENTION_DAYS = 30L
    private const val MAX_DB_SIZE_MB = 10L
  }

  suspend fun performCleanupIfNeeded() =
          withContext(Dispatchers.IO) {
            try {
              val lastCleanup = prefs.getLong(KEY_LAST_CLEANUP, 0L)
              val now = System.currentTimeMillis()

              if (now - lastCleanup < CLEANUP_INTERVAL_MS) {
                Log.d("DataCleanupManager", "Cleanup not needed yet")
                return@withContext
              }

              val sizeBefore = getDatabaseSize()
              Log.d("DataCleanupManager", "Starting cleanup. DB size: ${sizeBefore / 1024}KB")

              cleanupOldUsageData()
              cleanupOrphanedData()

              val sizeAfter = getDatabaseSize()
              val savedBytes = sizeBefore - sizeAfter
              Log.i(
                      "DataCleanupManager",
                      "Cleanup complete. Saved ${savedBytes / 1024}KB. DB size: ${sizeAfter / 1024}KB"
              )

              prefs.edit().putLong(KEY_LAST_CLEANUP, now).apply()
            } catch (e: Exception) {
              Log.e("DataCleanupManager", "Error during cleanup", e)
            }
          }

  private suspend fun cleanupOldUsageData() {
    try {
      val cutoffDate =
              Calendar.getInstance()
                      .apply { add(Calendar.DAY_OF_MONTH, -USAGE_DATA_RETENTION_DAYS.toInt()) }
                      .let { dateFormat.format(it.time) }

      database.dailyUsageDao().deleteOldUsage(cutoffDate)
      Log.d("DataCleanupManager", "Deleted usage data before $cutoffDate")
    } catch (e: Exception) {
      Log.e("DataCleanupManager", "Error cleaning usage data", e)
    }
  }

  private suspend fun cleanupOrphanedData() {
    try {
      val activePackages = database.appRestrictionDao().getAll().map { it.packageName }.toSet()

      val allUsage = database.dailyUsageDao().getAllUsage()
      var orphanedCount = 0

      for (usage in allUsage) {
        if (usage.packageName !in activePackages) {
          database.dailyUsageDao().delete(usage)
          orphanedCount++
        }
      }

      if (orphanedCount > 0) {
        Log.d("DataCleanupManager", "Deleted $orphanedCount orphaned usage records")
      }
    } catch (e: Exception) {
      Log.e("DataCleanupManager", "Error cleaning orphaned data", e)
    }
  }

  suspend fun getDatabaseSize(): Long =
          withContext(Dispatchers.IO) {
            try {
              val dbFile = context.getDatabasePath("app_time_control_db")
              dbFile?.length() ?: 0L
            } catch (e: Exception) {
              0L
            }
          }

  suspend fun getDatabaseSizeMB(): Double {
    return getDatabaseSize() / (1024.0 * 1024.0)
  }

  suspend fun isCleanupNeeded(): Boolean {
    return getDatabaseSizeMB() > MAX_DB_SIZE_MB
  }

  suspend fun getCleanupStats(): Map<String, Any> {
    return mapOf(
            "databaseSizeMB" to String.format("%.2f", getDatabaseSizeMB()),
            "lastCleanup" to prefs.getLong(KEY_LAST_CLEANUP, 0L),
            "usageRecordCount" to database.dailyUsageDao().getAllUsage().size,
            "restrictionCount" to database.appRestrictionDao().getAll().size
    )
  }

  suspend fun forceCleanup() =
          withContext(Dispatchers.IO) {
            prefs.edit().putLong(KEY_LAST_CLEANUP, 0L).apply()
            performCleanupIfNeeded()
          }
}

