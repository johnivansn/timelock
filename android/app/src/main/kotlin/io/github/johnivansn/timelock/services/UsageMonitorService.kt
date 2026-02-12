package io.github.johnivansn.timelock.services

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import io.github.johnivansn.timelock.database.AppDatabase
import io.github.johnivansn.timelock.monitoring.ScheduleMonitor
import io.github.johnivansn.timelock.monitoring.UsageStatsMonitor
import io.github.johnivansn.timelock.optimization.BatteryModeManager
import io.github.johnivansn.timelock.optimization.DataCleanupManager
import io.github.johnivansn.timelock.receivers.DailyResetReceiver
import io.github.johnivansn.timelock.widget.AppTimeWidget
import io.github.johnivansn.timelock.widget.AppTimeWidgetMedium
import io.github.johnivansn.timelock.widget.AppDirectBlockWidget
import java.util.Calendar
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class UsageMonitorService : Service() {
  private lateinit var usageStatsMonitor: UsageStatsMonitor
  private lateinit var scheduleMonitor: ScheduleMonitor
  private lateinit var database: AppDatabase
  private lateinit var batteryModeManager: BatteryModeManager
  private lateinit var dataCleanupManager: DataCleanupManager
  private val handler = Handler(Looper.getMainLooper())
  private val scope = CoroutineScope(Dispatchers.IO + Job())
  private var monitoredAppsCount = 0

  private val updateRunnable =
          object : Runnable {
            override fun run() {
              usageStatsMonitor.updateAllUsage()
              updateServiceNotification()
              updateWidgets()

              scope.launch { dataCleanupManager.performCleanupIfNeeded() }

              val interval = batteryModeManager.getUpdateInterval()
              handler.postDelayed(this, interval)
            }
          }

  override fun onCreate() {
    super.onCreate()
    database = AppDatabase.getDatabase(this)
    usageStatsMonitor = UsageStatsMonitor(this)
    scheduleMonitor = ScheduleMonitor(this)
    batteryModeManager = BatteryModeManager(this)
    dataCleanupManager = DataCleanupManager(this)

    createNotificationChannels()

    scope.launch {
      monitoredAppsCount = database.appRestrictionDao().getEnabled().size
      withContext(Dispatchers.Main) {
        if (isServiceNotificationEnabled()) {
          startForeground(NOTIFICATION_ID, createVisibleNotification(monitoredAppsCount))
        } else {
          getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
          } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
          }
        }
      }
    }

    scheduleDailyReset()

    scope.launch { dataCleanupManager.performCleanupIfNeeded() }
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
      ACTION_UPDATE_NOTIFICATION -> updateServiceNotification()
      else -> handler.post(updateRunnable)
    }
    return START_STICKY
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onDestroy() {
    super.onDestroy()
    handler.removeCallbacks(updateRunnable)
    scope.cancel()
  }

  private fun createNotificationChannels() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val visibleChannel =
              NotificationChannel(
                              CHANNEL_ID_VISIBLE,
                              "Monitoreo Activo",
                              NotificationManager.IMPORTANCE_LOW
                      )
                      .apply {
                        description = "Estado del monitoreo"
                        setShowBadge(false)
                        enableVibration(false)
                        setSound(null, null)
                      }

      val silentChannel =
              NotificationChannel(CHANNEL_ID_SILENT, "Servicio", NotificationManager.IMPORTANCE_MIN)
                      .apply {
                        description = "Servicio de fondo"
                        setShowBadge(false)
                        enableVibration(false)
                        setSound(null, null)
                      }

      getSystemService(NotificationManager::class.java).apply {
        createNotificationChannel(visibleChannel)
        createNotificationChannel(silentChannel)
      }
    }
  }

  private fun isServiceNotificationEnabled(): Boolean {
    val prefs = getSharedPreferences("notification_prefs", Context.MODE_PRIVATE)
    return prefs.getBoolean("notify_service_status", true)
  }

  private fun buildServiceNotification(): Notification {
    return if (isServiceNotificationEnabled()) {
      createVisibleNotification(monitoredAppsCount)
    } else {
      createSilentNotification()
    }
  }

  private fun createVisibleNotification(count: Int): Notification {
    val text = "Monitoreando $count ${if (count == 1) "app" else "apps"}"

    return NotificationCompat.Builder(this, CHANNEL_ID_VISIBLE)
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setShowWhen(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
  }

  private fun createSilentNotification(): Notification {
    return NotificationCompat.Builder(this, CHANNEL_ID_SILENT)
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
  }

  private fun updateServiceNotification() {
    scope.launch {
      monitoredAppsCount = database.appRestrictionDao().getEnabled().size
      withContext(Dispatchers.Main) {
        val notificationManager = getSystemService(NotificationManager::class.java)
        if (isServiceNotificationEnabled()) {
          val notification = createVisibleNotification(monitoredAppsCount)
          startForeground(NOTIFICATION_ID, notification)
          notificationManager.notify(NOTIFICATION_ID, notification)
        } else {
          notificationManager.cancel(NOTIFICATION_ID)
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
          } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
          }
        }
      }
    }
  }

  private fun scheduleDailyReset() {
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

  private fun updateWidgets() {
    AppTimeWidget.updateWidget(this)
    AppTimeWidgetMedium.updateWidget(this)
    AppDirectBlockWidget.updateWidget(this)
  }

  companion object {
    private const val CHANNEL_ID_VISIBLE = "service_status_visible"
    private const val CHANNEL_ID_SILENT = "service_status_silent"
    private const val NOTIFICATION_ID = 1
    const val ACTION_UPDATE_NOTIFICATION = "io.github.johnivansn.timelock.UPDATE_SERVICE_NOTIFICATION"
  }
}

