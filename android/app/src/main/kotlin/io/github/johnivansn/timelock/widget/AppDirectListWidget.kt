package io.github.johnivansn.timelock.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import io.github.johnivansn.timelock.R
import io.github.johnivansn.timelock.utils.AppComponentTheme

class AppDirectListWidget : AppWidgetProvider() {
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
    val views = RemoteViews(context.packageName, R.layout.widget_list)
    val palette = AppComponentTheme.widgetPalette(context)
    views.setInt(R.id.widget_container, "setBackgroundResource", palette.backgroundRes)
    views.setTextColor(R.id.widget_title, palette.title)
    views.setTextColor(R.id.widget_empty, palette.tertiary)

    val intent = Intent(context, AppDirectListWidgetService::class.java)
    views.setRemoteAdapter(R.id.widget_list, intent)
    views.setEmptyView(R.id.widget_list, R.id.widget_empty)

    val pendingIntent = WidgetUtils.buildLaunchPendingIntent(context)
    views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
    views.setPendingIntentTemplate(R.id.widget_list, pendingIntent)

    appWidgetManager.updateAppWidget(appWidgetId, views)
    appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list)
  }

  companion object {
    fun updateWidget(context: Context) {
      WidgetUtils.updateWidget(context, AppDirectListWidget::class.java)
    }
  }
}
