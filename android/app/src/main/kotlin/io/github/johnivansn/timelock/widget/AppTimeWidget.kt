package io.github.johnivansn.timelock.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import io.github.johnivansn.timelock.R
import io.github.johnivansn.timelock.database.AppDatabase
import io.github.johnivansn.timelock.utils.AppUtils
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
      val dateFormat = AppUtils.newDateFormat()
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
                AppUtils.formatRemainingLabel(remainingMinutes) +
                        if (blockedCount > 0)
                                " • $blockedCount bloqueada${if (blockedCount > 1) "s" else ""}"
                        else ""
        )
      }

      views.setOnClickPendingIntent(
              R.id.widget_container,
              WidgetUtils.buildLaunchPendingIntent(context)
      )

      appWidgetManager.updateAppWidget(appWidgetId, views)
    }
  }

  companion object {
    fun updateWidget(context: Context) {
      WidgetUtils.updateWidget(context, AppTimeWidget::class.java)
    }
  }

}

