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
  private var isOverlayAttached = false
  private var blockReceiver: android.content.BroadcastReceiver? = null

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
    setupBlockReceiver()
    Log.d(TAG, "Service connected")
  }

  private fun setupBlockReceiver() {
    blockReceiver =
            object : android.content.BroadcastReceiver() {
              override fun onReceive(
                      context: android.content.Context?,
                      intent: android.content.Intent?
              ) {
                if (intent?.action == "com.example.timelock.BLOCK_APP") {
                  val packageName = intent.getStringExtra("packageName")
                  if (packageName != null) {
                    Log.i(TAG, "Recibida señal de bloqueo para $packageName")
                    handler.post { forceBlockNow(packageName) }
                  }
                }
              }
            }

    val filter = android.content.IntentFilter("com.example.timelock.BLOCK_APP")
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
      registerReceiver(blockReceiver, filter, android.content.Context.RECEIVER_NOT_EXPORTED)
    } else {
      registerReceiver(blockReceiver, filter)
    }
    Log.d(TAG, "Block receiver registrado")
  }

  private fun forceBlockNow(packageName: String) {
    Log.w(TAG, "Forzando bloqueo inmediato de $packageName")
    val currentPackage = rootInActiveWindow?.packageName?.toString()
    if (currentPackage == packageName) {
      Log.i(TAG, "App está activa, bloqueando ahora")
      blockApp(packageName)
    } else {
      Log.d(TAG, "App no está activa actualmente (actual: $currentPackage)")
    }
  }

  override fun onAccessibilityEvent(event: AccessibilityEvent) {
    if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

    val packageName = event.packageName?.toString() ?: return

    if (packageName in IGNORED_PACKAGES) {
      if (currentBlockedPackage != null && !packageName.equals(currentBlockedPackage)) {
        cleanupOverlay()
      }
      return
    }

    if (currentBlockedPackage == packageName && overlayShown) {
      return
    }

    scope.launch {
      val shouldBlock = blockingEngine.shouldBlock(packageName)
      if (shouldBlock) {
        handler.post { blockApp(packageName) }
      } else if (currentBlockedPackage != null && currentBlockedPackage != packageName) {
        handler.post { cleanupOverlay() }
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
      forceHomeScreen()
    } catch (e: Exception) {
      Log.e(TAG, "Error blocking app", e)
      cleanupOverlay()
    }
  }

  private fun showBlockOverlay(packageName: String) {
    if (overlayView != null && isOverlayAttached) return

    try {
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
      isOverlayAttached = true
      Log.i(TAG, "Overlay mostrado para $packageName")
    } catch (e: Exception) {
      Log.e(TAG, "Error showing overlay", e)
      overlayView = null
      isOverlayAttached = false
    }
  }

  private fun hideBlockOverlay() {
    if (overlayView == null || !isOverlayAttached) return

    try {
      windowManager?.removeView(overlayView)
      Log.d(TAG, "Overlay hidden")
    } catch (e: IllegalArgumentException) {
      Log.w(TAG, "View not attached to window manager")
    } catch (e: Exception) {
      Log.w(TAG, "Error hiding overlay", e)
    } finally {
      overlayView = null
      isOverlayAttached = false
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
      val homeIntent =
              Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags =
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_CLEAR_TASK or
                                Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
              }
      startActivity(homeIntent)
      Log.i(TAG, "Intent HOME enviado")

      handler.postDelayed(
              {
                performGlobalAction(GLOBAL_ACTION_HOME)
                Log.i(TAG, "GLOBAL_ACTION_HOME ejecutado como refuerzo")
              },
              100
      )

      handler.postDelayed(
              {
                if (overlayShown) {
                  hideBlockOverlay()
                }
              },
              1000
      )
    } catch (e: Exception) {
      Log.e(TAG, "Error forzando home", e)
      try {
        performGlobalAction(GLOBAL_ACTION_HOME)
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

    try {
      if (blockReceiver != null) {
        unregisterReceiver(blockReceiver)
        Log.d(TAG, "Block receiver desregistrado")
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error desregistrando receiver", e)
    }

    Log.d(TAG, "Service destroyed")
  }
}
