package io.github.johnivansn.timelock.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import io.github.johnivansn.timelock.R
import io.github.johnivansn.timelock.database.AppDatabase
import io.github.johnivansn.timelock.monitoring.ScheduleMonitor
import io.github.johnivansn.timelock.utils.AppUtils
import java.util.Calendar
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

class AppDirectBlockWidget : AppWidgetProvider() {
  private val scope = CoroutineScope(Dispatchers.IO + Job())
  private val scheduleMonitor = ScheduleMonitor()

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
      val schedulePackages =
              database.appScheduleDao().getAllEnabled().map { it.packageName }.toSet()
      val datePackages =
              database.dateBlockDao().getAll().filter { it.isEnabled }.map { it.packageName }.toSet()
      val restrictionsByPackage =
              database.appRestrictionDao().getAll().associateBy { it.packageName }

      val combined = (schedulePackages + datePackages).toList()
      val views = RemoteViews(context.packageName, R.layout.widget_direct)

      if (combined.isEmpty()) {
        views.setTextViewText(R.id.widget_title, "Sin bloqueos directos")
        views.setViewVisibility(R.id.block_list_container, android.view.View.GONE)
      } else {
        views.setTextViewText(R.id.widget_title, "Bloqueos directos")
        views.setViewVisibility(R.id.block_list_container, android.view.View.VISIBLE)

        val list = combined.take(3).map { pkg ->
          val schedules = database.appScheduleDao().getByPackage(pkg).filter { it.isEnabled }
          val dateBlocks = database.dateBlockDao().getEnabledByPackage(pkg)
          val hasSchedule = schedules.isNotEmpty()
          val hasDate = dateBlocks.isNotEmpty()
          val restriction = restrictionsByPackage[pkg]
          val expiresAt = restriction?.expiresAt ?: 0L
          val isExpired = expiresAt > 0L && System.currentTimeMillis() > expiresAt
          val activeNow =
                  !isExpired && (scheduleMonitor.isCurrentlyBlocked(schedules) || isDateBlockedNow(dateBlocks))
          val type =
                  when {
                    hasSchedule && hasDate -> "Mixto"
                    hasSchedule -> "Horario"
                    else -> "Fecha"
                  }
          DirectItem(pkg, type, isExpired, activeNow)
        }

        for (i in 0 until 3) {
          val containerId = getContainerId(i)
          val nameId = getNameId(i)
          val typeId = getTypeId(i)
          val iconId = getIconId(i)
          if (i < list.size) {
            val item = list[i]
            val appName = resolveAppName(context, item.packageName)
            views.setTextViewText(nameId, appName)
            val typeLabel =
                    when {
                      item.isExpired -> "${item.type} • Vencida"
                      item.activeNow -> "${item.type} • Activa ahora"
                      else -> item.type
                    }
            views.setTextViewText(typeId, typeLabel)
            views.setTextColor(
                    typeId,
                    when {
                      item.isExpired -> 0xFFE74C3C.toInt()
                      item.activeNow -> 0xFFF39C12.toInt()
                      else -> 0xFFCCCCCC.toInt()
                    }
            )
            setAppIcon(context, views, iconId, item.packageName)
            views.setViewVisibility(containerId, android.view.View.VISIBLE)
          } else {
            views.setViewVisibility(containerId, android.view.View.GONE)
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

  private fun getContainerId(index: Int): Int {
    return when (index) {
      0 -> R.id.block1_container
      1 -> R.id.block2_container
      2 -> R.id.block3_container
      else -> R.id.block1_container
    }
  }

  private fun getNameId(index: Int): Int {
    return when (index) {
      0 -> R.id.block1_name
      1 -> R.id.block2_name
      2 -> R.id.block3_name
      else -> R.id.block1_name
    }
  }

  private fun getTypeId(index: Int): Int {
    return when (index) {
      0 -> R.id.block1_type
      1 -> R.id.block2_type
      2 -> R.id.block3_type
      else -> R.id.block1_type
    }
  }

  private fun getIconId(index: Int): Int {
    return when (index) {
      0 -> R.id.block1_icon
      1 -> R.id.block2_icon
      2 -> R.id.block3_icon
      else -> R.id.block1_icon
    }
  }

  data class DirectItem(
          val packageName: String,
          val type: String,
          val isExpired: Boolean,
          val activeNow: Boolean
  )

  private fun isDateBlockedNow(blocks: List<io.github.johnivansn.timelock.database.DateBlock>): Boolean {
    if (blocks.isEmpty()) return false
    val now = System.currentTimeMillis()
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

  companion object {
    fun updateWidget(context: Context) {
      WidgetUtils.updateWidget(context, AppDirectBlockWidget::class.java)
    }
  }
}

