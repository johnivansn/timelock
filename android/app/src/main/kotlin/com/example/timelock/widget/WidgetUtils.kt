package com.example.timelock.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import com.example.timelock.MainActivity

object WidgetUtils {
  fun buildLaunchPendingIntent(context: Context): PendingIntent {
    val intent = Intent(context, MainActivity::class.java)
    return PendingIntent.getActivity(
      context,
      0,
      intent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
  }

  fun updateWidget(context: Context, widgetClass: Class<*>) {
    val intent = Intent(context, widgetClass)
    intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
    val ids =
      AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, widgetClass))
    intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
    context.sendBroadcast(intent)
  }
}
