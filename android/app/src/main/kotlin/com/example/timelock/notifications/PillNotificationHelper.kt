package com.example.timelock.notifications

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
import com.example.timelock.R
import com.example.timelock.utils.AppUtils

class PillNotificationHelper(private val context: Context) {
  private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
  private val handler = Handler(Looper.getMainLooper())
  private val prefs = com.example.timelock.preferences.NotificationPreferences(context)
  private var currentView: View? = null
  private val dismissRunnable = Runnable { dismiss() }

  companion object {
    private const val TAG = "PillNotification"
    private const val DISPLAY_DURATION_MS = 4000L
    private const val ANIMATION_DURATION_MS = 300L
  }

  enum class BlockReason {
    QUOTA_EXCEEDED,
    WIFI_BLOCKED,
    SCHEDULE_BLOCKED,
    MANUAL
  }

  fun notifyQuota50(appName: String, packageName: String, remainingMinutes: Int) {
    if (!prefs.quota50Enabled) return
    val timeText = AppUtils.formatTime(remainingMinutes)
    show(appName, packageName, "$timeText restantes")
  }

  fun notifyQuota75(appName: String, packageName: String, remainingMinutes: Int) {
    if (!prefs.quota75Enabled) return
    val timeText = AppUtils.formatTime(remainingMinutes)
    show(appName, packageName, "$timeText restantes")
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
              BlockReason.WIFI_BLOCKED -> "Bloqueada en WiFi"
              BlockReason.SCHEDULE_BLOCKED -> "Fuera de horario"
              BlockReason.MANUAL -> "Bloqueada"
            }

    show(appName, packageName, text)
  }

  fun notifyScheduleUpcoming(appName: String, packageName: String, minutes: Int) {
    if (!prefs.scheduleEnabled) return
    val timeText = if (minutes == 1) "1 min" else "$minutes min"
    show(appName, packageName, "Se pausará en $timeText")
  }

  private fun show(appName: String, packageName: String, message: String) {
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

        view.alpha = 0f
        view.translationY = -dpToPx(50).toFloat()
        view.animate()
                .alpha(1f)
                .translationY(0f)
                .setDuration(ANIMATION_DURATION_MS)
                .setInterpolator(AccelerateDecelerateInterpolator())
                .start()

        handler.postDelayed(dismissRunnable, DISPLAY_DURATION_MS)

        Log.d(TAG, "Pill notification shown: $appName - $message")
      } catch (e: Exception) {
        Log.e(TAG, "Error showing pill notification", e)
      }
    }
  }

  private fun dismiss() {
    currentView?.let { view ->
      handler.removeCallbacks(dismissRunnable)

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

  private fun dpToPx(dp: Int): Int {
    return (dp * context.resources.displayMetrics.density).toInt()
  }

  fun cancelAll() {
    handler.post { dismiss() }
  }
}
