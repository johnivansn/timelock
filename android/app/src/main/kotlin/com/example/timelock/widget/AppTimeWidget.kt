package com.example.timelock.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.example.timelock.MainActivity
import com.example.timelock.R
import com.example.timelock.database.AppDatabase
import com.example.timelock.utils.AppUtils
import java.text.SimpleDateFormat
import java.util.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

class AppTimeWidget : AppWidgetProvider() {
  private val scope = CoroutineScope(Dispatchers.IO + Job())

  override fun onUpdate(
          context: Context,
          appWidgetManager: AppWidgetManager,
          appWidgetIds: IntArray
  ) {
    for (appWidgetId in appWidgetIds) {
      updateAppWidget(context, appWidgetManager, appWidgetId)
    }
  }

  private fun updateAppWidget(
          context: Context,
          appWidgetManager: AppWidgetManager,
          appWidgetId: Int
  ) {
    scope.launch {
      val database = AppDatabase.getDatabase(context)
      val restrictions = database.appRestrictionDao().getEnabled()
      val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
      val today = dateFormat.format(Date())

      val views = RemoteViews(context.packageName, R.layout.widget_small)

      if (restrictions.isEmpty()) {
        views.setTextViewText(R.id.widget_title, "Sin restricciones")
        views.setTextViewText(R.id.widget_content, "Toca para configurar")
      } else {
        var totalUsed = 0
        var totalQuota = 0
        var blockedCount = 0

        for (restriction in restrictions) {
          val usage = database.dailyUsageDao().getUsage(restriction.packageName, today)
          totalUsed += usage?.usedMinutes ?: 0
          totalQuota += restriction.dailyQuotaMinutes
          if (usage?.isBlocked == true) blockedCount++
        }

        val remainingMinutes = (totalQuota - totalUsed).coerceAtLeast(0)
        views.setTextViewText(R.id.widget_title, "${restrictions.size} apps monitoreadas")
        views.setTextViewText(
                R.id.widget_content,
                "${AppUtils.formatTime(remainingMinutes)} restantes" +
                        if (blockedCount > 0)
                                " • $blockedCount bloqueada${if (blockedCount > 1) "s" else ""}"
                        else ""
        )
      }

      val intent = Intent(context, MainActivity::class.java)
      val pendingIntent =
              PendingIntent.getActivity(
                      context,
                      0,
                      intent,
                      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
              )
      views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

      appWidgetManager.updateAppWidget(appWidgetId, views)
    }
  }

  companion object {
    fun updateWidget(context: Context) {
      val intent = Intent(context, AppTimeWidget::class.java)
      intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
      val ids =
              AppWidgetManager.getInstance(context)
                      .getAppWidgetIds(ComponentName(context, AppTimeWidget::class.java))
      intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
      context.sendBroadcast(intent)
    }
  }
}
