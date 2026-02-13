package io.github.johnivansn.timelock.widget

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import io.github.johnivansn.timelock.R
import io.github.johnivansn.timelock.database.AppDatabase
import io.github.johnivansn.timelock.monitoring.ScheduleMonitor
import io.github.johnivansn.timelock.utils.AppComponentTheme
import io.github.johnivansn.timelock.utils.AppUtils
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking

class AppDirectListWidgetService : RemoteViewsService() {
  override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
    return DirectListFactory(applicationContext)
  }
}

private class DirectListFactory(private val context: Context) :
  RemoteViewsService.RemoteViewsFactory {
  private val scheduleMonitor = ScheduleMonitor()
  private var items: List<DirectItem> = emptyList()

  override fun onCreate() {}

  override fun onDataSetChanged() {
    runBlocking(Dispatchers.IO) {
      val database = AppDatabase.getDatabase(context)
      val schedulePackages =
              database.appScheduleDao().getAllEnabled().map { it.packageName }.toSet()
      val datePackages =
              database.dateBlockDao().getAll().filter { it.isEnabled }.map { it.packageName }.toSet()
      val restrictionsByPackage =
              database.appRestrictionDao().getAll().associateBy { it.packageName }
      val now = System.currentTimeMillis()
      val dateTimeFormat = SimpleDateFormat("dd/MM HH:mm", Locale.getDefault())

      val combined = (schedulePackages + datePackages).toList()
      val palette = AppComponentTheme.widgetPalette(context)

      items =
              combined.map { pkg ->
                        val schedules =
                                database.appScheduleDao().getByPackage(pkg).filter { it.isEnabled }
                        val dateBlocks = database.dateBlockDao().getEnabledByPackage(pkg)
                        val hasSchedule = schedules.isNotEmpty()
                        val hasDate = dateBlocks.isNotEmpty()
                        val restriction = restrictionsByPackage[pkg]
                        val expiresAt = restriction?.expiresAt ?: 0L
                        val isExpired = expiresAt > 0L && now > expiresAt
                        val activeNow =
                                !isExpired && (scheduleMonitor.isCurrentlyBlocked(schedules) ||
                                        isDateBlockedNow(dateBlocks, now))
                        val dateEndMillis = nearestDateBlockEndMillis(dateBlocks, now)
                        val scheduleEndMillis = nearestScheduleWindowEndMillis(schedules, now)
                        val ruleEndMillis = pickNearestEndMillis(dateEndMillis, scheduleEndMillis)
                        val effectiveEndMillis =
                                if (expiresAt > 0L && ruleEndMillis != null) minOf(expiresAt, ruleEndMillis)
                                else if (expiresAt > 0L) expiresAt
                                else ruleEndMillis
                        val type =
                                when {
                                  hasSchedule && hasDate -> "Mixto"
                                  hasSchedule -> "Horario"
                                  else -> "Fecha"
                                }
                        val typeLabel =
                                buildTypeLabel(
                                        type = type,
                                        isExpired = isExpired,
                                        activeNow = activeNow,
                                        endMillis = effectiveEndMillis,
                                        formatter = dateTimeFormat
                                )
                        val typeColor =
                                resolveStatusColor(palette, isExpired, effectiveEndMillis, now)
                        DirectItem(pkg, typeLabel, typeColor)
                      }
                      .sortedBy { it.type }
    }
  }

  override fun getViewAt(position: Int): RemoteViews {
    val item = items[position]
    val views = RemoteViews(context.packageName, R.layout.widget_list_item)
    val palette = AppComponentTheme.widgetPalette(context)
    val appName = resolveAppName(context, item.packageName)

    views.setTextViewText(R.id.item_name, appName)
    views.setTextViewText(R.id.item_detail, item.type)
    views.setTextColor(R.id.item_name, palette.text)
    views.setTextColor(R.id.item_detail, item.statusColor)
    views.setInt(R.id.item_container, "setBackgroundColor", palette.progressTrack)
    setAppIcon(context, views, R.id.item_icon, item.packageName)

    views.setOnClickFillInIntent(R.id.item_container, Intent())
    return views
  }

  override fun getLoadingView(): RemoteViews? = null

  override fun getViewTypeCount(): Int = 1

  override fun getItemId(position: Int): Long = position.toLong()

  override fun hasStableIds(): Boolean = true

  override fun getCount(): Int = items.size

  override fun onDestroy() {
    items = emptyList()
  }

  data class DirectItem(
          val packageName: String,
          val type: String,
          val statusColor: Int
  )

  private fun resolveAppName(context: Context, packageName: String): String {
    return try {
      val pm = context.packageManager
      val info = pm.getApplicationInfo(packageName, 0)
      pm.getApplicationLabel(info).toString()
    } catch (_: Exception) {
      packageName
    }
  }

  private fun setAppIcon(
          context: Context,
          views: RemoteViews,
          iconId: Int,
          packageName: String
  ) {
    try {
      val drawable = context.packageManager.getApplicationIcon(packageName)
      val bitmap = WidgetUtils.drawableToBitmap(drawable)
      if (bitmap != null) {
        views.setImageViewBitmap(iconId, bitmap)
      }
    } catch (_: Exception) {}
  }

  private fun buildTypeLabel(
          type: String,
          isExpired: Boolean,
          activeNow: Boolean,
          endMillis: Long?,
          formatter: SimpleDateFormat
  ): String {
    if (isExpired) return "$type • Vencida"
    if (endMillis == null) return if (activeNow) "$type • Activa ahora" else type
    val formatted = formatter.format(java.util.Date(endMillis))
    return if (activeNow) "$type • Hasta $formatted" else "$type • Vigente hasta $formatted"
  }

  private fun resolveStatusColor(
          palette: io.github.johnivansn.timelock.utils.WidgetThemePalette,
          isExpired: Boolean,
          endMillis: Long?,
          now: Long
  ): Int {
    if (isExpired) return palette.error
    if (endMillis == null) return palette.tertiary
    val remaining = endMillis - now
    if (remaining <= 0L) return palette.error
    if (remaining <= 60 * 60 * 1000L) return palette.error
    if (remaining <= 6 * 60 * 60 * 1000L) return palette.warning
    return palette.success
  }

  private fun pickNearestEndMillis(dateEnd: Long?, scheduleEnd: Long?): Long? {
    return when {
      dateEnd == null -> scheduleEnd
      scheduleEnd == null -> dateEnd
      else -> minOf(dateEnd, scheduleEnd)
    }
  }

  private fun nearestDateBlockEndMillis(
          blocks: List<io.github.johnivansn.timelock.database.DateBlock>,
          now: Long
  ): Long? {
    if (blocks.isEmpty()) return null
    val dateFormat = AppUtils.newDateFormat()
    val candidates = blocks.mapNotNull { block ->
      val end =
              toDateTimeMillis(
                      dateFormat,
                      block.endDate,
                      block.endHour,
                      block.endMinute
              )
      if (end != null && end > now) end else null
    }
    return candidates.minOrNull()
  }

  private fun nearestScheduleWindowEndMillis(
          schedules: List<io.github.johnivansn.timelock.database.AppSchedule>,
          nowMillis: Long
  ): Long? {
    if (schedules.isEmpty()) return null
    var bestEnd: Long? = null
    for (schedule in schedules) {
      if (!schedule.isEnabled) continue
      for (offset in 0..7) {
        val dayStart = Calendar.getInstance().apply {
          timeInMillis = nowMillis
          set(Calendar.SECOND, 0)
          set(Calendar.MILLISECOND, 0)
          set(Calendar.HOUR_OF_DAY, 0)
          set(Calendar.MINUTE, 0)
          add(Calendar.DAY_OF_MONTH, offset)
        }
        val dayOfWeek = dayStart.get(Calendar.DAY_OF_WEEK)
        val dayBit = 1 shl (dayOfWeek - 1)
        if ((schedule.daysOfWeek and dayBit) == 0) continue

        val start = Calendar.getInstance().apply {
          timeInMillis = dayStart.timeInMillis
          set(Calendar.HOUR_OF_DAY, schedule.startHour)
          set(Calendar.MINUTE, schedule.startMinute)
        }
        val end = Calendar.getInstance().apply {
          timeInMillis = dayStart.timeInMillis
          set(Calendar.HOUR_OF_DAY, schedule.endHour)
          set(Calendar.MINUTE, schedule.endMinute)
        }
        if (end.timeInMillis <= start.timeInMillis) {
          end.add(Calendar.DAY_OF_MONTH, 1)
        }
        if (end.timeInMillis <= nowMillis) continue
        if (bestEnd == null || end.timeInMillis < bestEnd) {
          bestEnd = end.timeInMillis
        }
      }
    }
    return bestEnd
  }

  private fun isDateBlockedNow(
          blocks: List<io.github.johnivansn.timelock.database.DateBlock>,
          now: Long
  ): Boolean {
    if (blocks.isEmpty()) return false
    val dateFormat = AppUtils.newDateFormat()
    return blocks.any { block ->
      val startMillis = toDateTimeMillis(dateFormat, block.startDate, block.startHour, block.startMinute)
      val endMillis = toDateTimeMillis(dateFormat, block.endDate, block.endHour, block.endMinute)
      startMillis != null && endMillis != null && now in startMillis..endMillis
    }
  }

  private fun toDateTimeMillis(
          dateFormat: java.text.SimpleDateFormat,
          dateValue: String,
          hour: Int,
          minute: Int
  ): Long? {
    val date = dateFormat.parse(dateValue) ?: return null
    val cal = Calendar.getInstance().apply {
      time = date
      set(Calendar.HOUR_OF_DAY, hour)
      set(Calendar.MINUTE, minute)
      set(Calendar.SECOND, 0)
      set(Calendar.MILLISECOND, 0)
    }
    return cal.timeInMillis
  }
}
