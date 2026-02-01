package com.example.timelock.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
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
  private var lastBlockedPackage: String? = null

  override fun onServiceConnected() {
    super.onServiceConnected()
    blockingEngine = BlockingEngine(this)
    windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

    val info = AccessibilityServiceInfo()
    info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
    info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
    serviceInfo = info

    Log.i(TAG, "AppBlockAccessibilityService connected")
  }

  override fun onAccessibilityEvent(event: AccessibilityEvent) {
    if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

    val packageName = event.packageName?.toString() ?: return

    if (shouldIgnorePackage(packageName)) {
      removeBlockOverlay()
      lastBlockedPackage = null
      return
    }

    Log.d(TAG, "Foreground app: $packageName")

    scope.launch {
      val blockReason = blockingEngine.shouldBlockSync(packageName)
      if (blockReason != null) {
        Log.w(TAG, "App blocked: $packageName - reason=$blockReason")
        showBlockOverlay(packageName)
        lastBlockedPackage = packageName
      } else {
        if (lastBlockedPackage != packageName && blockedOverlay != null) {
          removeBlockOverlay()
          lastBlockedPackage = null
        }
      }
    }
  }

  override fun onInterrupt() {
    Log.d(TAG, "Accessibility service interrupted")
  }

  private fun shouldIgnorePackage(packageName: String): Boolean {
    return packageName in setOf("com.example.timelock", "com.android.systemui", "android")
  }

  private fun getBlockReason(packageName: String): String {
    return "Aplicación bloqueada"
  }

  private fun getBlockMessage(packageName: String): String {
    return "Has alcanzado el límite establecido"
  }

  private suspend fun getBlockReasonSuspend(packageName: String): String {
    val engine = BlockingEngine(this)
    return when {
      engine.isQuotaBlocked(packageName) -> "Cuota de tiempo agotada"
      engine.isWifiBlocked(packageName) -> "Bloqueado en esta red WiFi"
      engine.isScheduleBlocked(packageName) -> "Fuera de horario permitido"
      else -> "Aplicación bloqueada"
    }
  }

  private suspend fun getBlockMessageSuspend(packageName: String): String {
    val engine = BlockingEngine(this)
    return when {
      engine.isQuotaBlocked(packageName) -> "Intenta mañana o ajusta tu límite de tiempo"
      engine.isWifiBlocked(packageName) -> "Esta app no está permitida en esta red"
      engine.isScheduleBlocked(packageName) -> "Solo disponible en horarios permitidos"
      else -> "Has alcanzado el límite establecido"
    }
  }

  private fun getAppName(packageName: String): String {
    return try {
      val info = packageManager.getApplicationInfo(packageName, 0)
      packageManager.getApplicationLabel(info).toString().take(20)
    } catch (e: Exception) {
      packageName.substringAfterLast(".").take(15)
    }
  }

  private fun showBlockOverlay(packageName: String) {
    if (blockedOverlay != null) {
      return
    }

    try {
      blockedOverlay =
              FrameLayout(this).apply {
                setBackgroundColor(0xCC000000.toInt())
                isClickable = true
                isFocusable = true
              }

      try {
        val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        val customView = inflater.inflate(R.layout.block_overlay, blockedOverlay, false)

        customView.findViewById<TextView?>(R.id.block_title)?.apply {
          text = "🚫 ${getAppName(packageName)}"
        }

        scope.launch {
          val reason = getBlockReasonSuspend(packageName)
          val message = getBlockMessageSuspend(packageName)

          customView.findViewById<TextView?>(R.id.block_reason)?.apply { text = "Razón: $reason" }

          customView.findViewById<TextView?>(R.id.block_message)?.apply { text = message }
        }

        blockedOverlay!!.addView(customView)
      } catch (e: Exception) {
        Log.w(TAG, "Could not inflate custom overlay layout", e)
      }

      val params =
              WindowManager.LayoutParams().apply {
                type =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                          WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                        } else {
                          @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_SYSTEM_OVERLAY
                        }
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
      Log.i(TAG, "Block overlay shown for $packageName")

      handler.postDelayed(
              {
                redirectToHome()
                removeBlockOverlay()
              },
              OVERLAY_DURATION_MS
      )
    } catch (e: Exception) {
      Log.e(TAG, "Error showing block overlay", e)
      blockedOverlay = null
    }
  }

  private fun removeBlockOverlay() {
    try {
      if (blockedOverlay != null && windowManager != null) {
        windowManager!!.removeView(blockedOverlay)
        blockedOverlay = null
        Log.i(TAG, "Block overlay removed")
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error removing block overlay", e)
      blockedOverlay = null
    }
  }

  private fun redirectToHome() {
    try {
      val intent =
              Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
              }
      startActivity(intent)
      Log.i(TAG, "Redirected to home")
    } catch (e: Exception) {
      Log.e(TAG, "Error redirecting to home", e)
    }
  }

  override fun onDestroy() {
    super.onDestroy()
    removeBlockOverlay()
    scope.cancel()
    Log.i(TAG, "AppBlockAccessibilityService destroyed")
  }

  companion object {
    private const val TAG = "AppBlockA11yService"
    private const val OVERLAY_DURATION_MS = 3000L
  }
}
