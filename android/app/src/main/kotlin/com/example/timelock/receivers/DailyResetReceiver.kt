package com.example.timelock.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.example.timelock.database.AppDatabase
import com.example.timelock.monitoring.UsageStatsMonitor
import java.text.SimpleDateFormat
import java.util.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class DailyResetReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    Log.i("DailyResetReceiver", "Daily reset triggered at ${Date()}")

    val database = AppDatabase.getDatabase(context)
    val usageStatsMonitor = UsageStatsMonitor(context)
    val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
    val pendingResult = goAsync()

    CoroutineScope(Dispatchers.IO).launch {
      try {
        database.dailyUsageDao().resetUsageForDate(today)
        usageStatsMonitor.resetNotificationFlags()
        Log.i("DailyResetReceiver", "Reset completed for $today")
      } catch (e: Exception) {
        Log.e("DailyResetReceiver", "Reset failed", e)
      } finally {
        pendingResult.finish()
      }
    }
  }
}
