package io.github.johnivansn.timelock.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import io.github.johnivansn.timelock.R
import io.github.johnivansn.timelock.utils.AppComponentTheme

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
    val palette = AppComponentTheme.widgetPalette(context)
    views.setInt(R.id.widget_container, "setBackgroundResource", palette.backgroundRes)
    views.setTextViewText(R.id.widget_title, "Tiempo disponible")
    views.setTextViewText(R.id.widget_subtitle, "Monitoreo activo")
    views.setTextColor(R.id.widget_title, palette.title)
    views.setTextColor(R.id.widget_subtitle, palette.tertiary)
    views.setTextColor(R.id.widget_empty, palette.tertiary)
    views.setInt(R.id.widget_header_icon, "setColorFilter", palette.accent)
    val svcIntent = Intent(context, AppTimeWidgetMediumService::class.java).apply {
      putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
      data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
    }
    views.setRemoteAdapter(R.id.app_list, svcIntent)
    views.setEmptyView(R.id.app_list, R.id.widget_empty)
    views.setOnClickPendingIntent(
            R.id.widget_container,
            WidgetUtils.buildLaunchPendingIntent(context)
    )

    appWidgetManager.updateAppWidget(appWidgetId, views)
  }

  companion object {
    fun updateWidget(context: Context) {
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

