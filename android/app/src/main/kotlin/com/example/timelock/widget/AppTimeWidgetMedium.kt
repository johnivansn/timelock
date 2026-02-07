package com.example.timelock.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.example.timelock.R
import com.example.timelock.database.AppDatabase
import com.example.timelock.utils.AppUtils
import java.text.SimpleDateFormat
import java.util.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

class AppTimeWidgetMedium : AppWidgetProvider() {
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
      val restrictions = database.appRestrictionDao().getEnabled().take(3)
      val dateFormat = AppUtils.newDateFormat()
      val today = dateFormat.format(Date())

      val views = RemoteViews(context.packageName, R.layout.widget_medium)

      if (restrictions.isEmpty()) {
        views.setTextViewText(R.id.widget_title, "Sin restricciones activas")
        views.setViewVisibility(R.id.app_list_container, android.view.View.GONE)
      } else {
        views.setTextViewText(R.id.widget_title, "Apps monitoreadas")
        views.setViewVisibility(R.id.app_list_container, android.view.View.VISIBLE)

        for (i in 0 until 3) {
          val appNameId = getAppNameId(i)
          val appTimeId = getAppTimeId(i)
          val appProgressId = getAppProgressId(i)
          val appContainerId = getAppContainerId(i)

          if (i < restrictions.size) {
            val restriction = restrictions[i]
            val usage = database.dailyUsageDao().getUsage(restriction.packageName, today)
            val used = usage?.usedMinutes ?: 0
            val quota = restriction.dailyQuotaMinutes
            val remaining = (quota - used).coerceAtLeast(0)
            val progress = ((used.toFloat() / quota.toFloat()) * 100).toInt().coerceIn(0, 100)

            views.setTextViewText(appNameId, restriction.appName)
            views.setTextViewText(appTimeId, AppUtils.formatRemainingLabel(remaining))
            views.setProgressBar(appProgressId, 100, progress, false)
            views.setViewVisibility(appContainerId, android.view.View.VISIBLE)
          } else {
            views.setViewVisibility(appContainerId, android.view.View.GONE)
          }
        }
      }

      views.setOnClickPendingIntent(
              R.id.widget_container,
              WidgetUtils.buildLaunchPendingIntent(context)
      )

      appWidgetManager.updateAppWidget(appWidgetId, views)
    }
  }

  private fun getAppNameId(index: Int): Int {
    return when (index) {
      0 -> R.id.app1_name
      1 -> R.id.app2_name
      2 -> R.id.app3_name
      else -> R.id.app1_name
    }
  }

  private fun getAppTimeId(index: Int): Int {
    return when (index) {
      0 -> R.id.app1_time
      1 -> R.id.app2_time
      2 -> R.id.app3_time
      else -> R.id.app1_time
    }
  }

  private fun getAppProgressId(index: Int): Int {
    return when (index) {
      0 -> R.id.app1_progress
      1 -> R.id.app2_progress
      2 -> R.id.app3_progress
      else -> R.id.app1_progress
    }
  }

  private fun getAppContainerId(index: Int): Int {
    return when (index) {
      0 -> R.id.app1_container
      1 -> R.id.app2_container
      2 -> R.id.app3_container
      else -> R.id.app1_container
    }
  }

  companion object {
    fun updateWidget(context: Context) {
      WidgetUtils.updateWidget(context, AppTimeWidgetMedium::class.java)
    }
  }
}
