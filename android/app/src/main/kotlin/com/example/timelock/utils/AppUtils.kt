package com.example.timelock.utils

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable

object AppUtils {
  fun drawableToBitmap(drawable: Drawable): Bitmap {
    if (drawable is BitmapDrawable) {
      return drawable.bitmap
    }

    val bitmap =
            Bitmap.createBitmap(
                    drawable.intrinsicWidth.coerceAtLeast(1),
                    drawable.intrinsicHeight.coerceAtLeast(1),
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
}
