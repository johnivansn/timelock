package io.github.johnivansn.timelock.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.github.johnivansn.timelock.utils.AppUtils
import io.github.johnivansn.timelock.database.AppDatabase
import io.github.johnivansn.timelock.monitoring.ScheduleMonitor
import io.github.johnivansn.timelock.monitoring.UsageStatsMonitor
import java.text.SimpleDateFormat
import java.util.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

class DailyResetReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    Log.i("DailyResetReceiver", "Daily reset triggered at ${Date()}")

    val database = AppDatabase.getDatabase(context)
    val scope = CoroutineScope(Dispatchers.IO + Job())
    val usageStatsMonitor = UsageStatsMonitor(context)
    val scheduleMonitor = ScheduleMonitor(context)
    val dateFormat = AppUtils.newDateFormat()
    val today = dateFormat.format(Date())
    val sevenDaysAgo =
            Calendar.getInstance().apply { add(Calendar.DAY_OF_MONTH, -7) }.let {
              dateFormat.format(it.time)
            }
    val pendingResult = goAsync()

    scope.launch {
      try {
        database.dailyUsageDao().resetUsageForDate(today)
        database.dailyUsageDao().deleteOldUsage(sevenDaysAgo)
        usageStatsMonitor.resetNotificationFlags()
        scheduleMonitor.resetNotificationFlags()
        Log.i("DailyResetReceiver", "Reset completed for $today, purged before $sevenDaysAgo")
      } catch (e: Exception) {
        Log.e("DailyResetReceiver", "Reset failed", e)
      } finally {
        pendingResult.finish()
      }
    }
  }
}

