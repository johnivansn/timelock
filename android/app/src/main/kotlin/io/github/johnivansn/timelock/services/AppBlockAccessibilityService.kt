package io.github.johnivansn.timelock.services

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
import android.widget.ImageView
import android.widget.TextView
import io.github.johnivansn.timelock.utils.AppUtils
import io.github.johnivansn.timelock.utils.AppComponentTheme
import io.github.johnivansn.timelock.R
import io.github.johnivansn.timelock.blocking.BlockingEngine
import io.github.johnivansn.timelock.notifications.PillNotificationHelper
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
  private val pillNotification by lazy { PillNotificationHelper(this) }

  private var currentBlockedPackage: String? = null
  private var lastBlockedPackage: String? = null
  private var lastBlockTime = 0L
  private var lastEventTime = 0L
  private var overlayState = OverlayState.HIDDEN
  private var blockReceiver: android.content.BroadcastReceiver? = null
  private var themeReceiver: android.content.BroadcastReceiver? = null
  private var countdownRunnable: Runnable? = null
  private var countdownSeconds = 5
  private var overlayShownTime = 0L
  private var overlayDismissRunnable: Runnable? = null

  private enum class OverlayState {
    HIDDEN,
    SHOWING,
    VISIBLE,
    HIDING
  }

  private data class BlockDetailInfo(
          val remainingDays: Int?,
          val dateRangeSummary: String?,
          val dateLabelSummary: String?,
          val scheduleRangeSummary: String?,
          val expirySummary: String?,
          val quotaBlocked: Boolean,
          val scheduleBlocked: Boolean,
          val dateBlocked: Boolean
  )

  companion object {
    private const val TAG = "AccessibilityService"
    const val ACTION_OVERLAY_THEME_CHANGED = "io.github.johnivansn.timelock.OVERLAY_THEME_CHANGED"
    private const val BLOCK_COOLDOWN_MS = 2000L
    private const val EVENT_COOLDOWN_MS = 500L
    private val IGNORED_PACKAGES =
            setOf(
                    "io.github.johnivansn.timelock",
                    "com.android.systemui",
                    "android",
                    "com.android.launcher",
                    "com.android.launcher3",
                    "com.transsion.hilauncher"
            )
  }

  override fun onServiceConnected() {
    super.onServiceConnected()
    blockingEngine = BlockingEngine(this)
    windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
    setupBlockReceiver()
    setupThemeReceiver()
    Log.i(TAG, "✅ Service connected")
  }

  private fun setupBlockReceiver() {
    blockReceiver =
            object : android.content.BroadcastReceiver() {
              override fun onReceive(
                      context: android.content.Context?,
                      intent: android.content.Intent?
              ) {
                if (intent?.action == "io.github.johnivansn.timelock.BLOCK_APP") {
                  val packageName = intent.getStringExtra("packageName")
                  if (packageName != null) {
                    Log.w(TAG, "📡 Broadcast recibido: bloquear $packageName")
                    handler.post { forceBlockNow(packageName) }
                  }
                }
              }
            }

    val filter = android.content.IntentFilter("io.github.johnivansn.timelock.BLOCK_APP")
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      registerReceiver(blockReceiver, filter, android.content.Context.RECEIVER_NOT_EXPORTED)
    } else {
      registerReceiver(blockReceiver, filter)
    }
    Log.d(TAG, "📡 Broadcast receiver registrado")
  }

  private fun forceBlockNow(packageName: String) {
    Log.w(TAG, "⚡ FORCE BLOCK: $packageName")
    val currentPackage = rootInActiveWindow?.packageName?.toString()
    Log.d(TAG, "  Current window: $currentPackage")

    if (currentPackage == packageName) {
      Log.e(TAG, "  ✅ App ACTIVA - bloqueando")
      blockApp(packageName, BlockingEngine.BlockReason.TimeQuota)
      return
    }

    if (currentPackage == null || isIgnoredPackage(currentPackage)) {
      Log.w(TAG, "  ⚠️ Ventana actual no confiable/ignorada - forzando bloqueo")
      blockApp(packageName, BlockingEngine.BlockReason.TimeQuota)
      return
    }

    Log.d(TAG, "  ⏭️ App no activa - ignorando")
  }

  override fun onAccessibilityEvent(event: AccessibilityEvent) {
    if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

    val packageName = event.packageName?.toString() ?: return
    val now = System.currentTimeMillis()

    if (now - lastEventTime < EVENT_COOLDOWN_MS && packageName == lastBlockedPackage) {
      Log.v(TAG, "⏱️ Evento ignorado (cooldown): $packageName")
      return
    }
    lastEventTime = now

    Log.d(
            TAG,
            "🔔 Evento: $packageName | Estado overlay: $overlayState | Bloqueado actual: $currentBlockedPackage"
    )

    val isLauncher = isIgnoredPackage(packageName)

    if (isLauncher) {
      Log.d(TAG, "  ⏭️ Paquete ignorado (sistema/launcher)")

      if (currentBlockedPackage != null && overlayState == OverlayState.HIDDEN) {
        Log.i(TAG, "  🧹 Limpiando estado (overlay ya oculto)")
        currentBlockedPackage = null
      } else if (currentBlockedPackage != null && overlayState == OverlayState.VISIBLE) {
        Log.d(TAG, "  ⏳ Overlay visible - dejando que expire naturalmente")
      }
      return
    }

    if (currentBlockedPackage == packageName && overlayState == OverlayState.VISIBLE) {
      Log.d(TAG, "  🔄 Usuario intentando regresar a app bloqueada - forzando HOME de nuevo")
      handler.post { forceHomeScreen() }
      return
    }

    if (currentBlockedPackage == packageName && overlayState != OverlayState.HIDDEN) {
      Log.d(TAG, "  🔄 Mismo paquete bloqueado - manteniendo estado")
      return
    }

    scope.launch {
      val reason = blockingEngine.shouldBlockSync(packageName)
      Log.d(TAG, "  🔍 shouldBlock($packageName) = ${reason != null} ($reason)")

      if (reason != null) {
        val quotaBlocked =
                reason == BlockingEngine.BlockReason.TimeQuota ||
                        (reason == BlockingEngine.BlockReason.Combined &&
                                blockingEngine.isQuotaBlocked(packageName))
        val scheduleBlocked =
                reason == BlockingEngine.BlockReason.ScheduleBlocked ||
                        (reason == BlockingEngine.BlockReason.Combined &&
                                blockingEngine.isScheduleBlocked(packageName))
        val dateBlocked =
                reason == BlockingEngine.BlockReason.DateBlocked ||
                        (reason == BlockingEngine.BlockReason.Combined &&
                                blockingEngine.isDateBlocked(packageName))

        val detailInfo =
                BlockDetailInfo(
                        remainingDays =
                                if (dateBlocked) {
                                  blockingEngine.getDateBlockRemainingDays(packageName)
                                } else {
                                  null
                                },
                        dateRangeSummary =
                                if (dateBlocked) {
                                  blockingEngine.getDateBlockRangeSummary(packageName)
                                } else {
                                  null
                                },
                        dateLabelSummary =
                                if (dateBlocked) {
                                  blockingEngine.getActiveDateBlockLabelSummary(packageName)
                                } else {
                                  null
                                },
                        scheduleRangeSummary =
                                if (scheduleBlocked) {
                                  blockingEngine.getActiveScheduleRangeSummary(packageName)
                                } else {
                                  null
                                },
                        expirySummary = blockingEngine.getRestrictionExpirySummary(packageName),
                        quotaBlocked = quotaBlocked,
                        scheduleBlocked = scheduleBlocked,
                        dateBlocked = dateBlocked
                )

        handler.post {
          Log.w(TAG, "  🚫 Iniciando bloqueo de $packageName")
          blockApp(packageName, reason, detailInfo)
        }
      } else if (currentBlockedPackage != null && currentBlockedPackage != packageName) {
        handler.post {
          Log.i(TAG, "  🧹 Usuario abrió app REAL permitida - limpiando overlay")
          cleanupOverlay()
        }
      }
    }
  }

  private fun isIgnoredPackage(packageName: String): Boolean {
    return packageName in IGNORED_PACKAGES ||
            packageName.contains("launcher", ignoreCase = true) ||
            packageName.contains("home", ignoreCase = true)
  }

  private fun blockApp(
          packageName: String,
          reason: BlockingEngine.BlockReason,
          detailInfo: BlockDetailInfo? = null
  ) {
    if (reason == BlockingEngine.BlockReason.TimeQuota && isImportOverlaySuppressed()) {
      Log.i(TAG, "🔇 Overlay suprimido por importación (cuota): $packageName")
      return
    }
    val now = System.currentTimeMillis()

    val overlayEnabled = isBlockingOverlayEnabled()
    val canDrawOverlay = android.provider.Settings.canDrawOverlays(this)
    val canOverlay = overlayEnabled && canDrawOverlay
    if (!canOverlay) {
      val reasonText =
              when {
                !overlayEnabled -> "overlay desactivado por usuario"
                !canDrawOverlay -> "sin permiso de mostrar sobre otras apps"
                else -> "overlay no disponible"
              }
      Log.w(TAG, "⚠️ Overlay no disponible ($reasonText): usando fallback HOME para $packageName")
      currentBlockedPackage = packageName
      lastBlockedPackage = packageName
      lastBlockTime = now
      forceHomeScreen()
      handler.post { notifyBlockedFallback(packageName, reason) }
      return
    }

    if (overlayState == OverlayState.VISIBLE || overlayState == OverlayState.SHOWING) {
      if (currentBlockedPackage == packageName && now - lastBlockTime < BLOCK_COOLDOWN_MS) {
        Log.v(TAG, "❌ BLOCK IGNORADO (cooldown activo + overlay visible): $packageName")
        return
      }
    }

    Log.e(TAG, "🔒 === BLOQUEANDO: $packageName ===")
    Log.d(TAG, "  Estado previo overlay: $overlayState")
    Log.d(TAG, "  Bloqueado previo: $currentBlockedPackage")
    Log.d(TAG, "  Tiempo desde último bloqueo: ${now - lastBlockTime}ms")

    currentBlockedPackage = packageName
    lastBlockedPackage = packageName
    lastBlockTime = now

    showOverlay(packageName, reason, detailInfo)
    forceHomeScreen()
  }

  private fun setupThemeReceiver() {
    themeReceiver =
            object : android.content.BroadcastReceiver() {
              override fun onReceive(context: android.content.Context?, intent: android.content.Intent?) {
                if (intent?.action == ACTION_OVERLAY_THEME_CHANGED ||
                                intent?.action == Intent.ACTION_CONFIGURATION_CHANGED) {
                  handler.post {
                    applyOverlayTheme()
                  }
                }
              }
            }
    val filter = android.content.IntentFilter(ACTION_OVERLAY_THEME_CHANGED)
    filter.addAction(Intent.ACTION_CONFIGURATION_CHANGED)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      registerReceiver(themeReceiver, filter, android.content.Context.RECEIVER_NOT_EXPORTED)
    } else {
      registerReceiver(themeReceiver, filter)
    }
  }

  private fun notifyBlockedFallback(packageName: String, reason: BlockingEngine.BlockReason) {
    try {
      val pm = packageManager
      val appInfo = pm.getApplicationInfo(packageName, 0)
      val appName = pm.getApplicationLabel(appInfo).toString()
      val notificationReason =
              when (reason) {
                BlockingEngine.BlockReason.TimeQuota ->
                        PillNotificationHelper.BlockReason.QUOTA_EXCEEDED
                BlockingEngine.BlockReason.ScheduleBlocked ->
                        PillNotificationHelper.BlockReason.SCHEDULE_BLOCKED
                BlockingEngine.BlockReason.DateBlocked ->
                        PillNotificationHelper.BlockReason.DATE_BLOCKED
                BlockingEngine.BlockReason.Combined ->
                        PillNotificationHelper.BlockReason.MANUAL
              }
      pillNotification.notifyAppBlocked(appName, packageName, notificationReason)
    } catch (e: Exception) {
      Log.e(TAG, "Error notificando bloqueo fallback", e)
    }
  }

  private fun showOverlay(
          packageName: String,
          reason: BlockingEngine.BlockReason,
          detailInfo: BlockDetailInfo? = null
  ) {
    if (overlayState == OverlayState.VISIBLE || overlayState == OverlayState.SHOWING) {
      Log.w(TAG, "⚠️ Overlay ya visible/mostrándose - SALTANDO")
      return
    }

    overlayState = OverlayState.SHOWING
    Log.i(TAG, "👁️ MOSTRANDO OVERLAY para $packageName")

    try {
      if (overlayView != null) {
        Log.w(TAG, "  ⚠️ overlayView ya existe - removiendo primero")
        hideOverlay()
      }

      val inflater = getSystemService(LAYOUT_INFLATER_SERVICE) as LayoutInflater
      overlayView = inflater.inflate(R.layout.block_overlay, null)

      val appIcon = overlayView?.findViewById<ImageView>(R.id.block_app_icon)
      val appNameText = overlayView?.findViewById<TextView>(R.id.block_app_name)
      val titleText = overlayView?.findViewById<TextView>(R.id.block_title)
      val reasonText = overlayView?.findViewById<TextView>(R.id.block_reason)
      val messageText = overlayView?.findViewById<TextView>(R.id.block_message)
      val footerText = overlayView?.findViewById<TextView>(R.id.block_footer_text)
      val dateRangeText = overlayView?.findViewById<TextView>(R.id.block_date_range)

      try {
        val pm = packageManager
        val appInfo = pm.getApplicationInfo(packageName, 0)
        val appName = pm.getApplicationLabel(appInfo).toString()
        val drawable = pm.getApplicationIcon(packageName)

        appIcon?.setImageDrawable(drawable)
        appNameText?.text = appName
      } catch (e: Exception) {
        Log.e(TAG, "Error cargando info de app: $packageName", e)
        appIcon?.setImageResource(android.R.drawable.ic_menu_info_details)
        appNameText?.text = "Aplicación"
      }

      when (reason) {
        BlockingEngine.BlockReason.TimeQuota -> {
          titleText?.text = "Bloqueada"
          reasonText?.text = "Límite de tiempo alcanzado"
          messageText?.text = "La aplicación se cerrará automáticamente"
          footerText?.text = detailInfo?.expirySummary ?: "Intenta de nuevo mañana o ajusta tu límite de tiempo"
        }
        BlockingEngine.BlockReason.ScheduleBlocked -> {
          titleText?.text = "Fuera de horario"
          reasonText?.text = detailInfo?.scheduleRangeSummary ?: "Bloqueo por horario activo"
          messageText?.text = "Esta app no está permitida en este horario"
          footerText?.text = "Intenta de nuevo dentro de tu horario permitido"
        }
        BlockingEngine.BlockReason.DateBlocked -> {
          titleText?.text = "Bloqueada por fecha"
          reasonText?.text = detailInfo?.dateLabelSummary ?: "Bloqueo por fechas activo"
          messageText?.text = "Esta app no está permitida durante este período"
          footerText?.text =
                  when (detailInfo?.remainingDays) {
                    null -> "Intenta de nuevo cuando termine el bloqueo"
                    0 -> "Termina hoy"
                    1 -> "Termina en 1 día"
                    else -> "Termina en ${detailInfo.remainingDays} días"
                  }
        }
        BlockingEngine.BlockReason.Combined -> {
          titleText?.text = "Bloqueada"
          val activeReasons = mutableListOf<String>()
          if (detailInfo?.quotaBlocked == true) activeReasons.add("límite")
          if (detailInfo?.scheduleBlocked == true) activeReasons.add("horario")
          if (detailInfo?.dateBlocked == true) activeReasons.add("fecha")
          reasonText?.text =
                  if (activeReasons.isEmpty()) {
                    "Restricciones múltiples activas"
                  } else {
                    "Motivos: ${activeReasons.joinToString(", ")}"
                  }
          messageText?.text = "Hay más de una restricción activa para esta app"
          footerText?.text = detailInfo?.expirySummary ?: "Intenta más tarde o ajusta tus restricciones"
        }
      }

      val extraLines =
              listOfNotNull(
                      detailInfo?.scheduleRangeSummary,
                      detailInfo?.dateLabelSummary,
                      detailInfo?.dateRangeSummary,
                      detailInfo?.expirySummary
              )
                      .distinct()
      if (extraLines.isNotEmpty()) {
        dateRangeText?.text = extraLines.joinToString("\n")
        dateRangeText?.visibility = View.VISIBLE
      } else {
        dateRangeText?.visibility = View.GONE
      }

      applyOverlayTheme()

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
      overlayState = OverlayState.VISIBLE
      overlayShownTime = System.currentTimeMillis()
      Log.i(TAG, "  ✅ Overlay VISIBLE (timestamp: $overlayShownTime)")

      startCountdown()

      overlayDismissRunnable = Runnable {
        Log.d(TAG, "⏰ Timer overlay (5s) - auto-ocultando")
        hideOverlay()
      }
      handler.postDelayed(overlayDismissRunnable!!, 5000)
    } catch (e: Exception) {
      Log.e(TAG, "❌ ERROR mostrando overlay", e)
      overlayView = null
      overlayState = OverlayState.HIDDEN
    }
  }

  private fun hideOverlay() {
    if (overlayState == OverlayState.HIDDEN || overlayState == OverlayState.HIDING) {
      Log.v(TAG, "👁️ Overlay ya oculto/ocultándose")
      return
    }

    overlayState = OverlayState.HIDING

    val visibleDuration =
            if (overlayShownTime > 0) {
              System.currentTimeMillis() - overlayShownTime
            } else 0

    Log.i(
            TAG,
            "👁️ OCULTANDO OVERLAY (duración visible: ${visibleDuration}ms = ${visibleDuration/1000.0}s)"
    )

    stopCountdown()

    try {
      if (overlayView != null) {
        windowManager?.removeView(overlayView)
        overlayView = null
        Log.i(TAG, "  ✅ Overlay removido")
      }
    } catch (e: IllegalArgumentException) {
      Log.w(TAG, "  ⚠️ View no estaba adjunta", e)
    } catch (e: Exception) {
      Log.e(TAG, "  ❌ Error removiendo overlay", e)
    } finally {
      overlayView = null
      overlayState = OverlayState.HIDDEN
      overlayShownTime = 0
      currentBlockedPackage = null
      Log.d(TAG, "  🧹 Estado limpiado después de ocultar")
    }
  }

  private fun startCountdown() {
    countdownSeconds = 5
    updateCountdownText()

    countdownRunnable =
            object : Runnable {
              override fun run() {
                countdownSeconds--
                if (countdownSeconds >= 0) {
                  updateCountdownText()
                  handler.postDelayed(this, 1000)
                }
              }
            }
    handler.postDelayed(countdownRunnable!!, 1000)
  }

  private fun stopCountdown() {
    countdownRunnable?.let {
      handler.removeCallbacks(it)
      countdownRunnable = null
    }
  }

  private fun updateCountdownText() {
    overlayView?.findViewById<TextView>(R.id.countdown_text)?.text =
      AppUtils.formatDurationMillis(countdownSeconds * 1000L)
  }

  private fun applyOverlayTheme() {
    val view = overlayView ?: return
    val palette = AppComponentTheme.overlayPalette(this)
    view.findViewById<View>(R.id.block_overlay_root)?.setBackgroundColor(palette.rootBackground)
    view.findViewById<View>(R.id.block_overlay_scrim)?.setBackgroundColor(palette.scrim)
    view.findViewById<TextView>(R.id.block_app_name)?.setTextColor(palette.appName)
    view.findViewById<TextView>(R.id.block_title)?.setTextColor(palette.title)
    view.findViewById<TextView>(R.id.block_reason)?.setTextColor(palette.reason)
    view.findViewById<TextView>(R.id.block_message)?.setTextColor(palette.message)
    view.findViewById<TextView>(R.id.block_footer_text)?.setTextColor(palette.footer)
    view.findViewById<TextView>(R.id.block_date_range)?.setTextColor(palette.extra)
    view.findViewById<View>(R.id.block_content_card)?.setBackgroundColor(palette.contentCard)
    view.findViewById<View>(R.id.block_reason_chip)?.setBackgroundColor(palette.reasonChip)
    view.findViewById<View>(R.id.block_countdown_box)?.setBackgroundColor(palette.countdownBox)
    view.findViewById<TextView>(R.id.block_countdown_label)?.setTextColor(palette.countdownTitle)
    view.findViewById<TextView>(R.id.block_countdown_unit)?.setTextColor(palette.countdownTitle)
    view.findViewById<TextView>(R.id.countdown_text)?.setTextColor(palette.countdownValue)
    view.findViewById<View>(R.id.block_separator)?.setBackgroundColor(palette.separator)
    view.findViewById<ImageView>(R.id.block_lock_badge)?.setColorFilter(palette.badgeTint)
  }

  private fun cleanupOverlay() {
    Log.i(TAG, "🧹 === CLEANUP COMPLETO ===")

    overlayDismissRunnable?.let {
      handler.removeCallbacks(it)
      overlayDismissRunnable = null
    }

    stopCountdown()
    hideOverlay()
    currentBlockedPackage = null
    Log.i(TAG, "  ✅ Cleanup completado")
  }

  private fun forceHomeScreen() {
    Log.w(TAG, "🏠 Forzando HOME")

    try {
      try {
        performGlobalAction(GLOBAL_ACTION_HOME)
        Log.i(TAG, "  ✅ GLOBAL_ACTION_HOME ejecutado (inmediato)")
      } catch (e: Exception) {
        Log.w(TAG, "  ⚠️ GLOBAL_ACTION_HOME inmediato falló", e)
      }

      val homeIntent =
              Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags =
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_CLEAR_TASK or
                                Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
              }
      startActivity(homeIntent)
      Log.i(TAG, "  ✅ Intent HOME enviado")

      handler.postDelayed(
              {
                try {
                  performGlobalAction(GLOBAL_ACTION_HOME)
                  Log.i(TAG, "  ✅ GLOBAL_ACTION_HOME ejecutado (refuerzo)")
                } catch (e: Exception) {
                  Log.e(TAG, "  ❌ Error en GLOBAL_ACTION", e)
                }
              },
              80
      )
    } catch (e: Exception) {
      Log.e(TAG, "❌ Error forzando home", e)
      try {
        performGlobalAction(GLOBAL_ACTION_HOME)
      } catch (e2: Exception) {
        Log.e(TAG, "❌ Error crítico", e2)
      }
    }
  }

  private fun isBlockingOverlayEnabled(): Boolean {
    val prefs = getSharedPreferences("notification_prefs", MODE_PRIVATE)
    return prefs.getBoolean("notify_overlay_enabled", true)
  }

  private fun isImportOverlaySuppressed(): Boolean {
    val prefs = getSharedPreferences("import_prefs", MODE_PRIVATE)
    val until = prefs.getLong("suppress_overlay_until", 0L)
    return System.currentTimeMillis() < until
  }

  override fun onInterrupt() {
    Log.w(TAG, "⚠️ Service interrupted")
  }

  override fun onDestroy() {
    super.onDestroy()
    Log.w(TAG, "💀 Service destroying")

    cleanupOverlay()
    scope.cancel()

    try {
      if (blockReceiver != null) {
        unregisterReceiver(blockReceiver)
        Log.d(TAG, "📡 Receiver desregistrado")
      }
      if (themeReceiver != null) {
        unregisterReceiver(themeReceiver)
      }
    } catch (e: Exception) {
      Log.e(TAG, "❌ Error desregistrando receiver", e)
    }

    Log.i(TAG, "💀 Service destroyed")
  }
}

