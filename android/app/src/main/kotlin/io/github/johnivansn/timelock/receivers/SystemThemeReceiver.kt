package io.github.johnivansn.timelock.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.github.johnivansn.timelock.services.AppBlockAccessibilityService
import io.github.johnivansn.timelock.widget.AppDirectListWidget

class SystemThemeReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent?) {
    if (intent?.action != Intent.ACTION_CONFIGURATION_CHANGED) return
    AppDirectListWidget.updateWidget(context)
    context.sendBroadcast(Intent(AppBlockAccessibilityService.ACTION_OVERLAY_THEME_CHANGED))
  }
}
