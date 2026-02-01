package com.example.timelock.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.timelock.database.AppDatabase
import com.example.timelock.monitoring.UsageStatsMonitor
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class UsageMonitorService : Service() {
  private lateinit var usageStatsMonitor: UsageStatsMonitor
  private lateinit var database: AppDatabase
  private val handler = Handler(Looper.getMainLooper())
  private val updateInterval = 30000L
  private var monitoredAppsCount = 0

  private val updateRunnable =
          object : Runnable {
            override fun run() {
              usageStatsMonitor.updateAllUsage()
              updateNotification()
              handler.postDelayed(this, updateInterval)
            }
          }

  override fun onCreate() {
    super.onCreate()
    usageStatsMonitor = UsageStatsMonitor(this)
    database = AppDatabase.getDatabase(this)
    createNotificationChannel()
    startForeground(NOTIFICATION_ID, createNotification())
    Log.d("UsageMonitorService", "Service created")
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    handler.post(updateRunnable)
    Log.d("UsageMonitorService", "Service started")
    return START_STICKY
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onDestroy() {
    super.onDestroy()
    handler.removeCallbacks(updateRunnable)
    Log.d("UsageMonitorService", "Service destroyed")
  }

  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel =
              NotificationChannel(
                              CHANNEL_ID,
                              "Monitoreo de Uso",
                              NotificationManager.IMPORTANCE_LOW
                      )
                      .apply { description = "Monitoreo continuo de uso de aplicaciones" }
      val notificationManager = getSystemService(NotificationManager::class.java)
      notificationManager.createNotificationChannel(channel)
    }
  }

  private fun createNotification(): Notification {
    return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AppTimeControl activo")
            .setContentText("Iniciando monitoreo...")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
  }

  private fun updateNotification() {
    CoroutineScope(Dispatchers.IO).launch {
      monitoredAppsCount = database.appRestrictionDao().getEnabled().size

      val notification =
              NotificationCompat.Builder(this@UsageMonitorService, CHANNEL_ID)
                      .setContentTitle("AppTimeControl activo")
                      .setContentText(
                              "Monitoreando $monitoredAppsCount ${if (monitoredAppsCount == 1) "aplicación" else "aplicaciones"}"
                      )
                      .setSmallIcon(android.R.drawable.ic_menu_info_details)
                      .setPriority(NotificationCompat.PRIORITY_LOW)
                      .build()

      val notificationManager = getSystemService(NotificationManager::class.java)
      notificationManager.notify(NOTIFICATION_ID, notification)
    }
  }

  companion object {
    private const val CHANNEL_ID = "usage_monitor_channel"
    private const val NOTIFICATION_ID = 1
  }
}
