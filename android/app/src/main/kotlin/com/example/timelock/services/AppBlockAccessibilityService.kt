package com.example.timelock.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
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

  private var currentBlockedPackage: String? = null
  private var overlayShown = false
  private var blockStartTime = 0L

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
      if (currentBlockedPackage != null) {
        cleanupOverlay()
      }
      return
    }

    val now = System.currentTimeMillis()

    if (currentBlockedPackage == pkg) {
      if (now - blockStartTime > 5000) {
        Log.w(TAG, "Usuario persistente intentando acceder a $pkg, forzando home nuevamente")
        forceHomeScreen()
      }
      return
    }

    scope.launch {
      val reason = blockingEngine.shouldBlockSync(pkg)
      if (reason != null) {
        blockApp(pkg, reason)
      } else {
        if (currentBlockedPackage == pkg) {
          cleanupOverlay()
        }
      }
    }
  }

  override fun onInterrupt() {}

  private fun blockApp(pkg: String, reason: BlockingEngine.BlockReason) {
    if (overlayShown && currentBlockedPackage == pkg) return

    try {
      currentBlockedPackage = pkg
      blockStartTime = System.currentTimeMillis()
      overlayShown = true

      Log.i(TAG, "Bloqueando app: $pkg")

      showOverlay(pkg, reason)

      handler.postDelayed({
        forceHomeScreen()
      }, 1500)

      handler.postDelayed({
        cleanupOverlay()
      }, 2500)

    } catch (e: Exception) {
      Log.e(TAG, "Error blocking app", e)
      cleanupOverlay()
    }
  }

  private fun showOverlay(pkg: String, reason: BlockingEngine.BlockReason) {
    try {
      if (blockedOverlay != null) {
        return
      }

      blockedOverlay = FrameLayout(this).apply {
        setBackgroundColor(0xDD000000.toInt())
        isClickable = true
        isFocusable = true
      }

      try {
        val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        val view = inflater.inflate(R.layout.block_overlay, blockedOverlay, false)

        view.findViewById<TextView?>(R.id.block_title)?.text = "🚫 ${appName(pkg)}"

        val reasonText = when (reason) {
          is BlockingEngine.BlockReason.TimeQuota -> "Cuota de tiempo agotada"
          is BlockingEngine.BlockReason.WifiBlocked -> "Bloqueado en esta red WiFi"
          is BlockingEngine.BlockReason.ScheduleBlocked -> "Fuera de horario permitido"
          is BlockingEngine.BlockReason.Combined -> "Cuota agotada + horario"
        }

        val msgText = when (reason) {
          is BlockingEngine.BlockReason.TimeQuota -> "Intenta mañana o ajusta tu límite"
          is BlockingEngine.BlockReason.WifiBlocked -> "Esta app no está permitida en esta red"
          is BlockingEngine.BlockReason.ScheduleBlocked -> "Solo disponible en horarios permitidos"
          is BlockingEngine.BlockReason.Combined -> "Revisa tu cuota y horario configurados"
        }

        view.findViewById<TextView?>(R.id.block_reason)?.text = "Razón: $reasonText"
        view.findViewById<TextView?>(R.id.block_message)?.text = msgText

        blockedOverlay!!.addView(view)
      } catch (e: Exception) {
        Log.w(TAG, "No se pudo inflar layout del overlay", e)
      }

      val params = WindowManager.LayoutParams().apply {
        type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
          WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
          @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
        }
        format = PixelFormat.TRANSLUCENT
        flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_FULLSCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        width = WindowManager.LayoutParams.MATCH_PARENT
        height = WindowManager.LayoutParams.MATCH_PARENT
        gravity = Gravity.CENTER
      }

      windowManager?.addView(blockedOverlay, params)
      Log.i(TAG, "Overlay mostrado para $pkg")

    } catch (e: Exception) {
      Log.e(TAG, "Error mostrando overlay", e)
      cleanupOverlay()
    }
  }

  private fun forceHomeScreen() {
    try {
      performGlobalAction(GLOBAL_ACTION_HOME)
      Log.i(TAG, "Ejecutado GLOBAL_ACTION_HOME")

      handler.postDelayed({
        try {
          val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TASK or
                    Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
          }
          startActivity(homeIntent)
          Log.i(TAG, "Lanzado Intent HOME como backup")
        } catch (e: Exception) {
          Log.e(TAG, "Error lanzando Intent HOME", e)
        }
      }, 100)

    } catch (e: Exception) {
      Log.e(TAG, "Error ejecutando GLOBAL_ACTION_HOME", e)

      try {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
          addCategory(Intent.CATEGORY_HOME)
          flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                  Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        startActivity(homeIntent)
      } catch (e2: Exception) {
        Log.e(TAG, "Error crítico al forzar home", e2)
      }
    }
  }

  private fun cleanupOverlay() {
    handler.removeCallbacksAndMessages(null)

    try {
      if (blockedOverlay != null && windowManager != null) {
        windowManager!!.removeView(blockedOverlay)
        Log.d(TAG, "Overlay removido")
      }
    } catch (e: Exception) {
      Log.w(TAG, "Error removing overlay", e)
    }

    blockedOverlay = null
    currentBlockedPackage = null
    overlayShown = false
    blockStartTime = 0L
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
    cleanupOverlay()
    scope.cancel()
  }

  companion object {
    private const val TAG = "AppBlockA11yService"

    private val IGNORED_PACKAGES = setOf(
      "com.example.timelock",
      "com.android.systemui",
      "android",
      "com.android.launcher",
      "com.android.launcher3",
      "com.google.android.apps.nexuslauncher",
      "com.sec.android.app.launcher",
      "com.android.settings"
    )
  }
}