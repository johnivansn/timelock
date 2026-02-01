package com.example.timelock.services

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.timelock.database.AppDatabase
import com.example.timelock.monitoring.NetworkMonitor
import com.example.timelock.monitoring.ScheduleMonitor
import com.example.timelock.monitoring.UsageStatsMonitor
import com.example.timelock.notifications.PersistentNotification
import com.example.timelock.receivers.DailyResetReceiver
import com.example.timelock.widget.AppTimeWidget
import com.example.timelock.widget.AppTimeWidgetMedium
import java.util.Calendar
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class UsageMonitorService : Service() {
  private lateinit var usageStatsMonitor: UsageStatsMonitor
  private lateinit var networkMonitor: NetworkMonitor
  private lateinit var scheduleMonitor: ScheduleMonitor
  private lateinit var persistentNotification: PersistentNotification
  private lateinit var database: AppDatabase
  private val handler = Handler(Looper.getMainLooper())
  private val scope = CoroutineScope(Dispatchers.IO + Job())
  private val updateInterval = 30000L
  private var monitoredAppsCount = 0

  private val updateRunnable =
          object : Runnable {
            override fun run() {
              usageStatsMonitor.updateAllUsage()
              scheduleMonitor.checkSchedules()
              updateNotification()
              updateWidgets()
              updatePersistentNotification()
              handler.postDelayed(this, updateInterval)
            }
          }

  override fun onCreate() {
    super.onCreate()
    database = AppDatabase.getDatabase(this)
    usageStatsMonitor = UsageStatsMonitor(this)
    networkMonitor = NetworkMonitor(this, scope)
    scheduleMonitor = ScheduleMonitor(this, scope)
    persistentNotification = PersistentNotification(this)
    createNotificationChannel()
    startForeground(NOTIFICATION_ID, createNotification())
    scheduleDailyReset()
    networkMonitor.start()
    persistentNotification.show()
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    handler.post(updateRunnable)
    return START_STICKY
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onDestroy() {
    super.onDestroy()
    handler.removeCallbacks(updateRunnable)
    networkMonitor.stop()
    persistentNotification.hide()
    scope.cancel()
  }

  fun scheduleDailyReset() {
    val alarmManager = getSystemService(AlarmManager::class.java)
    val intent = Intent(this, DailyResetReceiver::class.java)
    val pendingIntent =
            PendingIntent.getBroadcast(
                    this,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

    val midnight =
            Calendar.getInstance().apply {
              set(Calendar.HOUR_OF_DAY, 0)
              set(Calendar.MINUTE, 0)
              set(Calendar.SECOND, 0)
              set(Calendar.MILLISECOND, 0)
              if (timeInMillis <= System.currentTimeMillis()) {
                add(Calendar.DAY_OF_MONTH, 1)
              }
            }

    alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            midnight.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pendingIntent
    )

    Log.i("UsageMonitorService", "Daily reset scheduled for ${midnight.time}")
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
      getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
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
    scope.launch {
      monitoredAppsCount = database.appRestrictionDao().getEnabled().size
      val notification =
              NotificationCompat.Builder(this@UsageMonitorService, CHANNEL_ID)
                      .setContentTitle("AppTimeControl activo")
                      .setContentText(
                              "Monitoreando $monitoredAppsCount ${
                        if (monitoredAppsCount == 1) "aplicación" else "aplicaciones"
                    }"
                      )
                      .setSmallIcon(android.R.drawable.ic_menu_info_details)
                      .setPriority(NotificationCompat.PRIORITY_LOW)
                      .build()
      withContext(Dispatchers.Main) {
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification)
      }
    }
  }

  private fun updateWidgets() {
    AppTimeWidget.updateWidget(this)
    AppTimeWidgetMedium.updateWidget(this)
  }

  private fun updatePersistentNotification() {
    persistentNotification.show()
  }

  companion object {
    private const val CHANNEL_ID = "usage_monitor_channel"
    private const val NOTIFICATION_ID = 1
  }
}
