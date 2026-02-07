package com.example.timelock.utils

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import java.text.SimpleDateFormat
import java.util.Calendar
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
