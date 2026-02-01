package com.example.timelock.backup

import android.content.Context
import androidx.work.*
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class AutoBackupWorker(context: Context, params: WorkerParameters) :
        CoroutineWorker(context, params) {

  override suspend fun doWork(): Result =
          withContext(Dispatchers.IO) {
            return@withContext try {
              val backupManager = BackupManager(applicationContext)
              val file = backupManager.createBackup()

              if (file != null) {
                Result.success()
              } else {
                Result.retry()
              }
            } catch (e: Exception) {
              Result.failure()
            }
          }

  companion object {
    private const val WORK_NAME = "auto_backup_work"

    fun schedule(context: Context) {
      val constraints = Constraints.Builder().setRequiresBatteryNotLow(true).build()

      val dailyWorkRequest =
              PeriodicWorkRequestBuilder<AutoBackupWorker>(1, TimeUnit.DAYS)
                      .setConstraints(constraints)
                      .setInitialDelay(calculateInitialDelay(), TimeUnit.MILLISECONDS)
                      .build()

      WorkManager.getInstance(context)
              .enqueueUniquePeriodicWork(
                      WORK_NAME,
                      ExistingPeriodicWorkPolicy.KEEP,
                      dailyWorkRequest
              )
    }

    private fun calculateInitialDelay(): Long {
      val currentTime = System.currentTimeMillis()
      val calendar =
              java.util.Calendar.getInstance().apply {
                timeInMillis = currentTime
                set(java.util.Calendar.HOUR_OF_DAY, 3)
                set(java.util.Calendar.MINUTE, 0)
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)

                if (timeInMillis <= currentTime) {
                  add(java.util.Calendar.DAY_OF_MONTH, 1)
                }
              }

      return calendar.timeInMillis - currentTime
    }

    fun cancel(context: Context) {
      WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
    }
  }
}
