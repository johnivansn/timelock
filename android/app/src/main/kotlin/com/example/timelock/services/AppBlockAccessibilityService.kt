package com.example.timelock.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.FrameLayout
import android.widget.TextView
import com.example.timelock.R
import com.example.timelock.blocking.BlockingEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class AppBlockAccessibilityService : AccessibilityService() {
  private var blockedOverlay: FrameLayout? = null
  private var windowManager: WindowManager? = null
  private lateinit var blockingEngine: BlockingEngine
  private val scope = CoroutineScope(Dispatchers.Main + Job())
  private val handler = Handler(Looper.getMainLooper())

  private var overlayPackage: String? = null
  private var lastCheckTime = 0L
  private val checkInterval = 1000L
  private var redirectScheduled = false

  override fun onServiceConnected() {
    super.onServiceConnected()
    blockingEngine = BlockingEngine(this)
    windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

    val info = AccessibilityServiceInfo()
    info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
    info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
    info.flags = AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
    serviceInfo = info

    Log.i(TAG, "Service connected")
  }

  override fun onAccessibilityEvent(event: AccessibilityEvent) {
    if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

    val pkg = event.packageName?.toString() ?: return

    if (pkg in IGNORED_PACKAGES) {
      if (overlayPackage != null) {
        removeOverlay()
      }
      return
    }

    val now = System.currentTimeMillis()
    if (now - lastCheckTime < checkInterval && overlayPackage == pkg) {
      return
    }
    lastCheckTime = now

    if (overlayPackage == pkg && blockedOverlay != null) {
      return
    }

    if (overlayPackage != null && overlayPackage != pkg) {
      handler.removeCallbacksAndMessages(null)
      removeOverlay()
      redirectScheduled = false
    }

    scope.launch {
      val reason = blockingEngine.shouldBlockSync(pkg)
      if (reason != null) {
        if (overlayPackage != pkg) {
          showOverlay(pkg, reason)
        }
      } else {
        if (overlayPackage == pkg) {
          handler.removeCallbacksAndMessages(null)
          removeOverlay()
          redirectScheduled = false
        }
      }
    }
  }

  override fun onInterrupt() {}

  private fun showOverlay(pkg: String, reason: BlockingEngine.BlockReason) {
    if (blockedOverlay != null && overlayPackage == pkg) {
      return
    }

    try {
      if (blockedOverlay != null) {
        try {
          windowManager?.removeView(blockedOverlay)
        } catch (_: Exception) {}
        blockedOverlay = null
      }

      blockedOverlay =
              FrameLayout(this).apply {
                setBackgroundColor(0xCC000000.toInt())
                isClickable = true
                isFocusable = true
              }

      try {
        val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        val view = inflater.inflate(R.layout.block_overlay, blockedOverlay, false)

        view.findViewById<TextView?>(R.id.block_title)?.text = "🚫 ${appName(pkg)}"

        scope.launch {
          val reasonText =
                  when (reason) {
                    is BlockingEngine.BlockReason.TimeQuota -> "Cuota de tiempo agotada"
                    is BlockingEngine.BlockReason.WifiBlocked -> "Bloqueado en esta red WiFi"
                    is BlockingEngine.BlockReason.ScheduleBlocked -> "Fuera de horario permitido"
                    is BlockingEngine.BlockReason.Combined -> "Cuota agotada + horario"
                  }
          val msgText =
                  when (reason) {
                    is BlockingEngine.BlockReason.TimeQuota -> "Intenta mañana o ajusta tu límite"
                    is BlockingEngine.BlockReason.WifiBlocked ->
                            "Esta app no está permitida en esta red"
                    is BlockingEngine.BlockReason.ScheduleBlocked ->
                            "Solo disponible en horarios permitidos"
                    is BlockingEngine.BlockReason.Combined ->
                            "Revisa tu cuota y horario configurados"
                  }
          view.findViewById<TextView?>(R.id.block_reason)?.text = "Razón: $reasonText"
          view.findViewById<TextView?>(R.id.block_message)?.text = msgText
        }

        blockedOverlay!!.addView(view)
      } catch (e: Exception) {
        Log.w(TAG, "No se pudo inflar layout del overlay", e)
      }

      val params =
              WindowManager.LayoutParams().apply {
                type = WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                format = PixelFormat.TRANSLUCENT
                flags =
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                width = WindowManager.LayoutParams.MATCH_PARENT
                height = WindowManager.LayoutParams.MATCH_PARENT
                gravity = Gravity.CENTER
              }

      windowManager?.addView(blockedOverlay, params)
      overlayPackage = pkg
      Log.i(TAG, "Overlay mostrado para $pkg")

      if (!redirectScheduled) {
        redirectScheduled = true
        handler.postDelayed(
                {
                  if (overlayPackage == pkg) {
                    redirectToHome()
                    removeOverlay()
                    redirectScheduled = false
                    lastCheckTime = System.currentTimeMillis() + 2000L
                  }
                },
                OVERLAY_DURATION_MS
        )
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error mostrando overlay", e)
      blockedOverlay = null
      overlayPackage = null
      redirectScheduled = false
    }
  }

  private fun removeOverlay() {
    try {
      if (blockedOverlay != null && windowManager != null) {
        windowManager!!.removeView(blockedOverlay)
      }
    } catch (e: Exception) {
      Log.w(TAG, "Error removing overlay", e)
    }
    blockedOverlay = null
    overlayPackage = null
  }

  private fun redirectToHome() {
    try {
      startActivity(
              Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
              }
      )
    } catch (e: Exception) {
      Log.e(TAG, "Error al redirigir al home", e)
    }
  }

  private fun appName(pkg: String): String =
          try {
            packageManager
                    .getApplicationLabel(packageManager.getApplicationInfo(pkg, 0))
                    .toString()
                    .take(20)
          } catch (_: Exception) {
            pkg.substringAfterLast(".").take(15)
          }

  override fun onDestroy() {
    super.onDestroy()
    handler.removeCallbacksAndMessages(null)
    removeOverlay()
    scope.cancel()
  }

  companion object {
    private const val TAG = "AppBlockA11yService"
    private const val OVERLAY_DURATION_MS = 3000L

    private val IGNORED_PACKAGES =
            setOf(
                    "com.example.timelock",
                    "com.android.systemui",
                    "android",
                    "com.android.launcher",
                    "com.android.launcher3"
            )
  }
}
