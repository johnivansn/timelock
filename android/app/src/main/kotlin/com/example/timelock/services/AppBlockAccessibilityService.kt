package com.example.timelock.services

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.graphics.PixelFormat
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
import kotlinx.coroutines.withContext

class AppBlockAccessibilityService : AccessibilityService() {
  private var overlayView: View? = null
  private var windowManager: WindowManager? = null
  private lateinit var blockingEngine: BlockingEngine
  private val scope = CoroutineScope(Dispatchers.IO + Job())
  private val handler = Handler(Looper.getMainLooper())
  private var currentPackage: String? = null

  override fun onServiceConnected() {
    super.onServiceConnected()
    blockingEngine = BlockingEngine(this)
    windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
    Log.d("AccessibilityService", "Service connected")
  }

  override fun onAccessibilityEvent(event: AccessibilityEvent) {
    if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

    val packageName = event.packageName?.toString() ?: return
    if (packageName == "com.example.timelock" || packageName == "com.android.systemui") return
    if (packageName == currentPackage) return

    currentPackage = packageName
    checkAndBlockApp(packageName)
  }

  private fun checkAndBlockApp(packageName: String) {
    scope.launch {
      val shouldBlock = blockingEngine.shouldBlock(packageName)
      withContext(Dispatchers.Main) {
        if (shouldBlock) {
          showBlockOverlay(packageName)
          scope.launch(Dispatchers.IO) {
            blockingEngine.blockApp(
                    packageName,
                    com.example.timelock.notifications.NotificationHelper.BlockReason.QUOTA_EXCEEDED
            )
          }
        } else {
          hideBlockOverlay()
        }
      }
    }
  }

  private fun showBlockOverlay(packageName: String) {
    if (overlayView != null) return

    val inflater = getSystemService(LAYOUT_INFLATER_SERVICE) as LayoutInflater
    overlayView = inflater.inflate(R.layout.block_overlay, null)

    val params =
            WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                    PixelFormat.TRANSLUCENT
            )
    params.gravity = Gravity.CENTER

    windowManager?.addView(overlayView, params)
    Log.d("AccessibilityService", "Overlay shown for $packageName")

    handler.postDelayed({ redirectToHome() }, 3000)
  }

  private fun hideBlockOverlay() {
    overlayView?.let {
      windowManager?.removeView(it)
      overlayView = null
    }
  }

  private fun redirectToHome() {
    val intent = Intent(Intent.ACTION_MAIN)
    intent.addCategory(Intent.CATEGORY_HOME)
    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
    startActivity(intent)
    handler.postDelayed({ hideBlockOverlay() }, 500)
    Log.d("AccessibilityService", "Redirected to home")
  }

  override fun onInterrupt() {
    Log.d("AccessibilityService", "Service interrupted")
  }

  override fun onDestroy() {
    super.onDestroy()
    hideBlockOverlay()
    scope.cancel()
    Log.d("AccessibilityService", "Service destroyed")
  }
}
