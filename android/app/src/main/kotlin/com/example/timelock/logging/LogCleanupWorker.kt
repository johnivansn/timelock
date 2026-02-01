package com.example.timelock.logging

import android.content.Context
import androidx.work.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

class LogCleanupWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

  override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
    return@withContext try {
      val activityLogger = ActivityLogger(applicationContext)
      activityLogger.purgeOldLogs(30)
      Result.success()
    } catch (e: Exception) {
      Result.retry()
    }
  }

  companion object {
    private const val WORK_NAME = "log_cleanup_work"

    fun schedule(context: Context) {
      val constraints = Constraints.Builder()
        .setRequiresBatteryNotLow(true)
        .build()

      val weeklyWorkRequest = PeriodicWorkRequestBuilder<LogCleanupWorker>(7, TimeUnit.DAYS)
        .setConstraints(constraints)
        .setInitialDelay(1, TimeUnit.DAYS)
        .build()

      WorkManager.getInstance(context).enqueueUniquePeriodicWork(
        WORK_NAME,
        ExistingPeriodicWorkPolicy.KEEP,
        weeklyWorkRequest
      )
    }

    fun cancel(context: Context) {
      WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
    }
  }
}