package io.github.johnivansn.timelock.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import io.github.johnivansn.timelock.R

class AppTimeWidgetMedium : AppWidgetProvider() {
  override fun onUpdate(
          context: Context,
          appWidgetManager: AppWidgetManager,
          appWidgetIds: IntArray
  ) {
    for (appWidgetId in appWidgetIds) {
      updateAppWidget(context, appWidgetManager, appWidgetId)
    }
  }

  override fun onAppWidgetOptionsChanged(
          context: Context,
          appWidgetManager: AppWidgetManager,
          appWidgetId: Int,
          newOptions: android.os.Bundle
  ) {
    updateAppWidget(context, appWidgetManager, appWidgetId)
  }

  private fun updateAppWidget(
          context: Context,
          appWidgetManager: AppWidgetManager,
          appWidgetId: Int
  ) {
    val views = RemoteViews(context.packageName, R.layout.widget_medium)
    views.setTextViewText(R.id.widget_title, "Tiempo disponible")
    views.setRemoteAdapter(
            R.id.app_list,
            Intent(context, AppTimeWidgetMediumService::class.java)
    )
    views.setEmptyView(R.id.app_list, R.id.widget_empty)
    views.setOnClickPendingIntent(
            R.id.widget_container,
            WidgetUtils.buildLaunchPendingIntent(context)
    )

    appWidgetManager.updateAppWidget(appWidgetId, views)
    appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.app_list)
  }

  companion object {
    fun updateWidget(context: Context) {
      WidgetUtils.updateWidget(context, AppTimeWidgetMedium::class.java)
      val manager = AppWidgetManager.getInstance(context)
      val ids =
              manager.getAppWidgetIds(
                      android.content.ComponentName(context, AppTimeWidgetMedium::class.java)
              )
      if (ids.isNotEmpty()) {
        manager.notifyAppWidgetViewDataChanged(ids, R.id.app_list)
      }
    }
  }
}

