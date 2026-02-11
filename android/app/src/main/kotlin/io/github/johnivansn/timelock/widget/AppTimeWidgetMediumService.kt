package io.github.johnivansn.timelock.widget

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import io.github.johnivansn.timelock.R
import io.github.johnivansn.timelock.database.AppDatabase
import io.github.johnivansn.timelock.database.getDailyQuotaForDay
import io.github.johnivansn.timelock.utils.AppUtils
import java.util.Calendar
import java.util.Date
import kotlinx.coroutines.runBlocking

class AppTimeWidgetMediumService : RemoteViewsService() {
  override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
    return AppTimeWidgetMediumFactory(applicationContext)
  }
}

private class AppTimeWidgetMediumFactory(
        private val context: Context
) : RemoteViewsService.RemoteViewsFactory {
  private val database = AppDatabase.getDatabase(context)
  private val dateFormat = AppUtils.newDateFormat()
  private val items = mutableListOf<Entry>()

  override fun onCreate() {}

  override fun onDataSetChanged() {
    items.clear()
    runBlocking {
      val today = dateFormat.format(Date())
      val dayOfWeek = Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
      val all =
              database.appRestrictionDao().getAll().mapNotNull { restriction ->
                val quotaMinutes =
                        if (restriction.limitType == "weekly") {
                          restriction.weeklyQuotaMinutes
                        } else {
                          restriction.getDailyQuotaForDay(dayOfWeek)
                        }
                if (quotaMinutes <= 0) {
                  val expiresAt = restriction.expiresAt ?: return@mapNotNull null
                  if (expiresAt <= 0) return@mapNotNull null
                }

                val usedMinutes =
                        if (restriction.limitType == "weekly") {
                          val weekStart =
                                  AppUtils.getWeekStartDate(
                                          restriction.weeklyResetDay,
                                          restriction.weeklyResetHour,
                                          restriction.weeklyResetMinute,
                                          dateFormat
                                  )
                          val weekUsages =
                                  database.dailyUsageDao()
                                          .getUsageSince(restriction.packageName, weekStart)
                          weekUsages.sumOf { it.usedMinutes }
                        } else {
                          val usage =
                                  database.dailyUsageDao()
                                          .getUsage(restriction.packageName, today)
                          usage?.usedMinutes ?: 0
                        }

                val remaining = (quotaMinutes - usedMinutes).coerceAtLeast(0)
                val expiresAt = restriction.expiresAt ?: 0L
                val expired = expiresAt > 0 && System.currentTimeMillis() > expiresAt
                Entry(restriction.appName, restriction.packageName, usedMinutes, quotaMinutes, remaining, expired)
              }

      items.addAll(
              all.sortedWith(
                      compareBy<Entry> { if (it.expired) 1 else 0 }
                              .thenBy { if (it.remaining > 0) 0 else 1 }
              )
      )
    }
  }

  override fun onDestroy() {
    items.clear()
  }

  override fun getCount(): Int = items.size

  override fun getViewAt(position: Int): RemoteViews {
    val item = items[position]
    val views = RemoteViews(context.packageName, R.layout.widget_medium_item)

    views.setTextViewText(R.id.app_name, item.appName)
    val timeText =
            if (item.expired) {
              "Vencida"
            } else {
              AppUtils.formatRemainingLabel(item.remaining)
            }
    views.setTextViewText(R.id.app_time, timeText)

    try {
      val drawable = context.packageManager.getApplicationIcon(item.packageName)
      val bitmap = WidgetUtils.drawableToBitmap(drawable)
      if (bitmap != null) {
        views.setImageViewBitmap(R.id.app_icon, bitmap)
      }
    } catch (_: Exception) {}

    if (item.expired || item.quota <= 0) {
      views.setViewVisibility(R.id.app_progress, android.view.View.GONE)
    } else {
      val progress =
              if (item.quota > 0) ((item.used.toFloat() / item.quota.toFloat()) * 100)
                      .toInt()
                      .coerceIn(0, 100)
              else 0
      views.setProgressBar(R.id.app_progress, 100, progress, false)
      views.setViewVisibility(R.id.app_progress, android.view.View.VISIBLE)
      views.setTextColor(R.id.app_time, colorForProgress(item.used.toFloat() / item.quota.toFloat()))
    }

    return views
  }

  override fun getLoadingView(): RemoteViews? = null

  override fun getViewTypeCount(): Int = 1

  override fun getItemId(position: Int): Long = position.toLong()

  override fun hasStableIds(): Boolean = true

  private fun colorForProgress(progress: Float): Int {
    val clamped = progress.coerceIn(0f, 1f)
    return when {
      clamped >= 0.9f -> 0xFFE74C3C.toInt()
      clamped >= 0.75f -> 0xFFF39C12.toInt()
      else -> 0xFF27AE60.toInt()
    }
  }

  data class Entry(
          val appName: String,
          val packageName: String,
          val used: Int,
          val quota: Int,
          val remaining: Int,
          val expired: Boolean
  )
}

