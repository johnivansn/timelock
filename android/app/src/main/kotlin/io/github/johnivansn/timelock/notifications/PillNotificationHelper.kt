package io.github.johnivansn.timelock.notifications

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.ImageView
import android.widget.TextView
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import android.app.NotificationChannel
import android.app.NotificationManager
import android.provider.Settings
import io.github.johnivansn.timelock.R
import io.github.johnivansn.timelock.utils.AppUtils

class PillNotificationHelper(private val context: Context) {
  private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
  private val handler = Handler(Looper.getMainLooper())
  private val prefs = io.github.johnivansn.timelock.preferences.NotificationPreferences(context)
  private var currentView: View? = null
  private val dismissRunnable = Runnable { dismiss() }

  companion object {
    private const val TAG = "PillNotification"
    private const val DISPLAY_DURATION_MS = 4000L
    private const val ANIMATION_DURATION_MS = 300L
    private const val CHANNEL_ID = "timelock_alerts"
    private const val ALERT_NOTIFICATION_ID = 9001
    private const val ALERT_GROUP_KEY = "timelock_alerts_group"
  }

  enum class BlockReason {
    QUOTA_EXCEEDED,
    SCHEDULE_BLOCKED,
    DATE_BLOCKED,
    MANUAL
  }

  fun notifyQuota50(appName: String, packageName: String, remainingMinutes: Int) {
    if (!prefs.quota50Enabled) return
    show(appName, packageName, AppUtils.formatRemainingLabel(remainingMinutes))
  }

  fun notifyQuota75(appName: String, packageName: String, remainingMinutes: Int) {
    if (!prefs.quota75Enabled) return
    show(appName, packageName, AppUtils.formatRemainingLabel(remainingMinutes))
  }

  fun notifyLastMinute(appName: String, packageName: String) {
    if (!prefs.lastMinuteEnabled) return
    show(appName, packageName, "Último minuto")
  }

  fun notifyAppBlocked(appName: String, packageName: String, reason: BlockReason) {
    if (!prefs.blockedEnabled) return

    val text =
            when (reason) {
              BlockReason.QUOTA_EXCEEDED -> "Límite alcanzado"
              BlockReason.SCHEDULE_BLOCKED -> "Fuera de horario"
              BlockReason.DATE_BLOCKED -> "Bloqueo por fechas"
              BlockReason.MANUAL -> "Bloqueada"
            }

    show(appName, packageName, text)
  }

  fun notifyScheduleUpcoming(
          appName: String,
          packageName: String,
          minutes: Int,
          startLabel: String,
          endLabel: String
  ) {
    if (!prefs.scheduleEnabled) return
    val timeText = AppUtils.formatTime(minutes)
    show(appName, packageName, "En $timeText se activa restricción ($startLabel a $endLabel)")
  }

  fun notifyDateBlockRemaining(appName: String, packageName: String, daysRemaining: Int) {
    if (!prefs.dateBlockEnabled) return
    val text =
            when (daysRemaining) {
              0 -> "Bloqueo termina hoy"
              1 -> "Bloqueo termina en 1 día"
              else -> "Bloqueo termina en $daysRemaining días"
            }
    show(appName, packageName, text)
  }

  fun notifyDateBlockUpcoming(appName: String, packageName: String, message: String) {
    if (!prefs.dateBlockEnabled) return
    show(appName, packageName, message)
  }

  fun notifyDateBlockUpcomingGrouped(label: String, message: String, appNames: List<String>) {
    if (!prefs.dateBlockEnabled) return
    showGroupedSystemNotification(
            title = "Etiqueta: $label",
            message = message,
            appNames = appNames,
            notificationId = ("date_upcoming_group|$label|$message").hashCode()
    )
  }

  private fun show(appName: String, packageName: String, message: String) {
    val style = prefs.notificationStyle.trim().lowercase()
    val canOverlay = canShowOverlay()
    val reduceAnimations = isReduceAnimationsEnabled()
    if (style != "pill" || !prefs.overlayEnabled || !canOverlay) {
      if (style == "pill" && !canOverlay) {
        prefs.notificationStyle = "normal"
        prefs.overlayEnabled = false
      }
      showSystemNotification(appName, message, packageName.hashCode())
      return
    }
    handler.post {
      try {
        dismiss()

        val inflater = context.getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        val view = inflater.inflate(R.layout.pill_notification, null)

        val appIcon = view.findViewById<ImageView>(R.id.pill_app_icon)
        val messageText = view.findViewById<TextView>(R.id.pill_message)

        try {
          val pm = context.packageManager
          val drawable = pm.getApplicationIcon(packageName)
          appIcon.setImageDrawable(drawable)
        } catch (e: Exception) {
          Log.e(TAG, "Error loading icon for $packageName", e)
          appIcon.setImageResource(android.R.drawable.ic_lock_idle_lock)
        }

        messageText.text = message

        val params =
                WindowManager.LayoutParams().apply {
                  width = WindowManager.LayoutParams.WRAP_CONTENT
                  height = WindowManager.LayoutParams.WRAP_CONTENT
                  type =
                          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                          } else {
                            @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
                          }
                  flags =
                          WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                                  WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                                  WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                  format = PixelFormat.TRANSLUCENT
                  gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                  y = dpToPx(20)
                }

        windowManager.addView(view, params)
        currentView = view

        if (reduceAnimations) {
          view.alpha = 1f
          view.translationY = 0f
        } else {
          view.alpha = 0f
          view.translationY = -dpToPx(50).toFloat()
          view.animate()
                  .alpha(1f)
                  .translationY(0f)
                  .setDuration(ANIMATION_DURATION_MS)
                  .setInterpolator(AccelerateDecelerateInterpolator())
                  .start()
        }

        handler.postDelayed(dismissRunnable, DISPLAY_DURATION_MS)

        Log.d(TAG, "Pill notification shown: $appName - $message")
      } catch (e: Exception) {
        Log.e(TAG, "Error showing pill notification", e)
      }
    }
  }

  private fun canShowOverlay(): Boolean {
    val prefs = context.getSharedPreferences("permission_prefs", Context.MODE_PRIVATE)
    val overlayBlocked = prefs.getBoolean("overlay_blocked", false)
    val canDraw = Settings.canDrawOverlays(context)
    if (canDraw && overlayBlocked) {
      prefs.edit().putBoolean("overlay_blocked", false).apply()
      return true
    }
    return !overlayBlocked && canDraw
  }

  private fun showSystemNotification(appName: String, message: String, notificationId: Int) {
    try {
      ensureChannel()
      val notification =
              NotificationCompat.Builder(context, CHANNEL_ID)
                      .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
                      .setContentTitle(appName)
                      .setContentText(message)
                      .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                      .setPriority(NotificationCompat.PRIORITY_HIGH)
                      .setGroup(ALERT_GROUP_KEY)
                      .setOnlyAlertOnce(true)
                      .setAutoCancel(true)
                      .build()
      // Reemplaza alertas previas para evitar acumulación en bandeja.
      NotificationManagerCompat.from(context).notify(ALERT_NOTIFICATION_ID, notification)
    } catch (e: Exception) {
      Log.e(TAG, "Error mostrando notificación estándar", e)
    }
  }

  private fun showGroupedSystemNotification(
          title: String,
          message: String,
          appNames: List<String>,
          notificationId: Int
  ) {
    try {
      ensureChannel()
      val inboxStyle =
              NotificationCompat.InboxStyle()
                      .setBigContentTitle(message)
                      .setSummaryText("${appNames.size} apps")
      appNames.distinct().sorted().take(7).forEach { inboxStyle.addLine("- $it") }

      val notification =
              NotificationCompat.Builder(context, CHANNEL_ID)
                      .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
                      .setContentTitle(title)
                      .setContentText(message)
                      .setStyle(inboxStyle)
                      .setPriority(NotificationCompat.PRIORITY_HIGH)
                      .setGroup(ALERT_GROUP_KEY)
                      .setOnlyAlertOnce(true)
                      .setAutoCancel(true)
                      .build()
      NotificationManagerCompat.from(context).notify(ALERT_NOTIFICATION_ID, notification)
    } catch (e: Exception) {
      Log.e(TAG, "Error mostrando notificación agrupada", e)
    }
  }

  private fun ensureChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (manager.getNotificationChannel(CHANNEL_ID) != null) return
    val channel =
            NotificationChannel(
                    CHANNEL_ID,
                    "Alertas TimeLock",
                    NotificationManager.IMPORTANCE_HIGH
            )
    channel.description = "Notificaciones de alertas y bloqueos"
    manager.createNotificationChannel(channel)
  }

  private fun dismiss() {
    currentView?.let { view ->
      handler.removeCallbacks(dismissRunnable)
      if (isReduceAnimationsEnabled()) {
        try {
          windowManager.removeView(view)
        } catch (e: Exception) {
          Log.e(TAG, "Error removing view", e)
        }
        currentView = null
        return
      }

      view.animate()
              .alpha(0f)
              .translationY(-dpToPx(50).toFloat())
              .setDuration(ANIMATION_DURATION_MS)
              .setInterpolator(AccelerateDecelerateInterpolator())
              .withEndAction {
                try {
                  windowManager.removeView(view)
                } catch (e: Exception) {
                  Log.e(TAG, "Error removing view", e)
                }
                currentView = null
              }
              .start()
    }
  }

  private fun isReduceAnimationsEnabled(): Boolean {
    val uiPrefs = context.getSharedPreferences("ui_prefs", Context.MODE_PRIVATE)
    return uiPrefs.getBoolean("reduce_animations", false)
  }

  private fun dpToPx(dp: Int): Int {
    return (dp * context.resources.displayMetrics.density).toInt()
  }

  fun cancelAll() {
    handler.post { dismiss() }
  }
}

