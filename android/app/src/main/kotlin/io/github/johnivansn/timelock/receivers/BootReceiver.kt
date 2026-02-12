package io.github.johnivansn.timelock.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.github.johnivansn.timelock.services.UsageMonitorService

class BootReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

    val prefs = context.getSharedPreferences("notification_prefs", Context.MODE_PRIVATE)
    val monitoringEnabled = prefs.getBoolean("notify_service_status", true)
    if (!monitoringEnabled) {
      Log.i("BootReceiver", "Boot completed, monitoring disabled by user")
      return
    }

    Log.i("BootReceiver", "Boot completed, starting UsageMonitorService")

    val serviceIntent = Intent(context, UsageMonitorService::class.java)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      context.startForegroundService(serviceIntent)
    } else {
      context.startService(serviceIntent)
    }
  }
}

