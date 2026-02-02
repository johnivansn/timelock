package com.example.timelock.services

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import com.example.timelock.R
import com.example.timelock.blocking.BlockingEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class AppBlockAccessibilityService : AccessibilityService() {
  private var overlayView: View? = null
  private var windowManager: WindowManager? = null
  private lateinit var blockingEngine: BlockingEngine
  private val scope = CoroutineScope(Dispatchers.IO + Job())
  private val handler = Handler(Looper.getMainLooper())
  private var currentBlockedPackage: String? = null
  private var overlayShown = false
  private var blockStartTime = 0L

  companion object {
    private const val TAG = "AccessibilityService"
    private val IGNORED_PACKAGES =
            setOf(
                    "com.example.timelock",
                    "com.android.systemui",
                    "android",
                    "com.android.launcher",
                    "com.android.launcher3"
            )
  }

  override fun onServiceConnected() {
    super.onServiceConnected()
    blockingEngine = BlockingEngine(this)
    windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
    Log.d(TAG, "Service connected")
  }

  override fun onAccessibilityEvent(event: AccessibilityEvent) {
    if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

    val packageName = event.packageName?.toString() ?: return

    if (packageName in IGNORED_PACKAGES) {
      if (currentBlockedPackage != null) {
        cleanupOverlay()
      }
      return
    }

    val now = System.currentTimeMillis()

    if (currentBlockedPackage == packageName) {
      if (now - blockStartTime > 5000) {
        Log.w(
                TAG,
                "Usuario persistente intentando acceder a $packageName, forzando home nuevamente"
        )
        forceHomeScreen()
      }
      return
    }

    scope.launch {
      val shouldBlock = blockingEngine.shouldBlock(packageName)
      if (shouldBlock) {
        blockApp(packageName)
      } else {
        if (currentBlockedPackage == packageName) {
          cleanupOverlay()
        }
      }
    }
  }

  private fun blockApp(packageName: String) {
    if (overlayShown && currentBlockedPackage == packageName) return

    try {
      currentBlockedPackage = packageName
      blockStartTime = System.currentTimeMillis()
      overlayShown = true

      Log.i(TAG, "Bloqueando app: $packageName")

      showBlockOverlay(packageName)

      handler.postDelayed({ forceHomeScreen() }, 1500)

      handler.postDelayed({ cleanupOverlay() }, 2500)
    } catch (e: Exception) {
      Log.e(TAG, "Error blocking app", e)
      cleanupOverlay()
    }
  }

  private fun showBlockOverlay(packageName: String) {
    if (overlayView != null) return

    val inflater = getSystemService(LAYOUT_INFLATER_SERVICE) as LayoutInflater
    overlayView = inflater.inflate(R.layout.block_overlay, null)

    val params =
            WindowManager.LayoutParams().apply {
              type =
                      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                      } else {
                        @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
                      }
              format = PixelFormat.TRANSLUCENT
              flags =
                      WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                              WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                              WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                              WindowManager.LayoutParams.FLAG_FULLSCREEN or
                              WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
              width = WindowManager.LayoutParams.MATCH_PARENT
              height = WindowManager.LayoutParams.MATCH_PARENT
              gravity = Gravity.CENTER
            }

    windowManager?.addView(overlayView, params)
    Log.i(TAG, "Overlay mostrado para $packageName")
  }

  private fun hideBlockOverlay() {
    overlayView?.let {
      try {
        windowManager?.removeView(it)
        overlayView = null
        Log.d(TAG, "Overlay hidden")
      } catch (e: Exception) {
        Log.w(TAG, "Error hiding overlay", e)
      }
    }
  }

  private fun cleanupOverlay() {
    handler.removeCallbacksAndMessages(null)
    hideBlockOverlay()
    currentBlockedPackage = null
    overlayShown = false
    blockStartTime = 0L
  }

  private fun forceHomeScreen() {
    try {
      performGlobalAction(GLOBAL_ACTION_HOME)
      Log.i(TAG, "Ejecutado GLOBAL_ACTION_HOME")

      handler.postDelayed(
              {
                try {
                  val homeIntent =
                          Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_HOME)
                            flags =
                                    Intent.FLAG_ACTIVITY_NEW_TASK or
                                            Intent.FLAG_ACTIVITY_CLEAR_TASK or
                                            Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
                          }
                  startActivity(homeIntent)
                  Log.i(TAG, "Lanzado Intent HOME como backup")
                } catch (e: Exception) {
                  Log.e(TAG, "Error lanzando Intent HOME", e)
                }
              },
              100
      )
    } catch (e: Exception) {
      Log.e(TAG, "Error ejecutando GLOBAL_ACTION_HOME", e)

      try {
        val homeIntent =
                Intent(Intent.ACTION_MAIN).apply {
                  addCategory(Intent.CATEGORY_HOME)
                  flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                }
        startActivity(homeIntent)
      } catch (e2: Exception) {
        Log.e(TAG, "Error crítico al forzar home", e2)
      }
    }
  }

  override fun onInterrupt() {
    Log.d(TAG, "Service interrupted")
  }

  override fun onDestroy() {
    super.onDestroy()
    cleanupOverlay()
    scope.cancel()
    Log.d(TAG, "Service destroyed")
  }
}
