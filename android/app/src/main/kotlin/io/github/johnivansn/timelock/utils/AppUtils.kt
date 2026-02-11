package io.github.johnivansn.timelock.utils

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

object AppUtils {
  fun drawableToBitmap(drawable: Drawable, maxSize: Int? = null): Bitmap {
    if (drawable is BitmapDrawable) {
      return drawable.bitmap
    }

    val width = drawable.intrinsicWidth.coerceAtLeast(1)
    val height = drawable.intrinsicHeight.coerceAtLeast(1)
    val targetWidth = if (maxSize != null) minOf(width, maxSize) else width
    val targetHeight = if (maxSize != null) minOf(height, maxSize) else height

    val bitmap =
            Bitmap.createBitmap(
                    targetWidth,
                    targetHeight,
                    Bitmap.Config.ARGB_8888
            )
    val canvas = Canvas(bitmap)
    drawable.setBounds(0, 0, canvas.width, canvas.height)
    drawable.draw(canvas)
    return bitmap
  }

  fun formatTime(minutes: Int): String {
    return if (minutes >= 60) {
      val hours = minutes / 60
      val mins = minutes % 60
      if (mins == 0) "${hours}h" else "${hours}h ${mins}m"
    } else {
      "${minutes}m"
    }
  }

  fun formatRemainingLabel(minutes: Int): String {
    return "${formatTime(minutes)} restantes"
  }

  fun formatDurationMillis(millis: Long): String {
    val totalSeconds = (millis / 1000).coerceAtLeast(0)
    var remaining = totalSeconds
    val days = remaining / 86400
    remaining %= 86400
    val hours = remaining / 3600
    remaining %= 3600
    val minutes = remaining / 60
    val seconds = remaining % 60

    val parts = mutableListOf<String>()
    if (days > 0) parts.add("${days}d")
    if (hours > 0) parts.add("${hours}h")
    if (minutes > 0) parts.add("${minutes}m")
    if (seconds > 0 || parts.isEmpty()) parts.add("${seconds}s")
    return parts.joinToString(" ")
  }

  fun formatWeeklyResetLabel(
    resetDay: Int,
    resetHour: Int,
    resetMinute: Int
  ): String {
    val cal = Calendar.getInstance()
    val current = cal.get(Calendar.DAY_OF_WEEK)
    var diff = current - resetDay
    if (diff < 0) diff += 7
    cal.add(Calendar.DAY_OF_MONTH, -diff)
    cal.set(Calendar.HOUR_OF_DAY, resetHour)
    cal.set(Calendar.MINUTE, resetMinute)
    cal.set(Calendar.SECOND, 0)
    cal.set(Calendar.MILLISECOND, 0)
    if (Calendar.getInstance().before(cal)) {
      cal.add(Calendar.DAY_OF_MONTH, -7)
    }
    val labels = mapOf(
      Calendar.MONDAY to "Lun",
      Calendar.TUESDAY to "Mar",
      Calendar.WEDNESDAY to "Mié",
      Calendar.THURSDAY to "Jue",
      Calendar.FRIDAY to "Vie",
      Calendar.SATURDAY to "Sáb",
      Calendar.SUNDAY to "Dom"
    )
    val dayLabel = labels[cal.get(Calendar.DAY_OF_WEEK)] ?: "Día"
    val h = cal.get(Calendar.HOUR_OF_DAY).toString().padStart(2, '0')
    val m = cal.get(Calendar.MINUTE).toString().padStart(2, '0')
    return "desde $dayLabel $h:$m"
  }

  fun formatWeeklyNextResetLabel(
    resetDay: Int,
    resetHour: Int,
    resetMinute: Int
  ): String {
    val formatter = newDateFormat()
    val last = getWeekStartDate(resetDay, resetHour, resetMinute, formatter)
    val cal = Calendar.getInstance()
    cal.time = formatter.parse(last) ?: Date()
    cal.add(Calendar.DAY_OF_MONTH, 7)
    val labels = mapOf(
      Calendar.MONDAY to "Lun",
      Calendar.TUESDAY to "Mar",
      Calendar.WEDNESDAY to "Mié",
      Calendar.THURSDAY to "Jue",
      Calendar.FRIDAY to "Vie",
      Calendar.SATURDAY to "Sáb",
      Calendar.SUNDAY to "Dom"
    )
    val dayLabel = labels[cal.get(Calendar.DAY_OF_WEEK)] ?: "Día"
    val h = cal.get(Calendar.HOUR_OF_DAY).toString().padStart(2, '0')
    val m = cal.get(Calendar.MINUTE).toString().padStart(2, '0')
    return "hasta $dayLabel $h:$m"
  }

  fun newDateFormat(): SimpleDateFormat {
    return SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
  }

  fun getWeekStartDate(
    resetDay: Int,
    resetHour: Int,
    resetMinute: Int,
    formatter: SimpleDateFormat
  ): String {
    val now = Calendar.getInstance()
    val cal = Calendar.getInstance()
    val current = cal.get(Calendar.DAY_OF_WEEK)
    var diff = current - resetDay
    if (diff < 0) diff += 7
    cal.add(Calendar.DAY_OF_MONTH, -diff)
    cal.set(Calendar.HOUR_OF_DAY, resetHour)
    cal.set(Calendar.MINUTE, resetMinute)
    cal.set(Calendar.SECOND, 0)
    cal.set(Calendar.MILLISECOND, 0)
    if (now.before(cal)) {
      cal.add(Calendar.DAY_OF_MONTH, -7)
    }
    return formatter.format(cal.time)
  }

  fun getWeekStartDate(resetDay: Int): String {
    val formatter = newDateFormat()
    return getWeekStartDate(resetDay, 0, 0, formatter)
  }
}

