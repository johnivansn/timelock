package io.github.johnivansn.timelock.utils

import android.content.Context
import android.content.res.Configuration
import io.github.johnivansn.timelock.R

enum class ComponentTheme {
  DARK,
  LIGHT
}

data class WidgetThemePalette(
        val backgroundRes: Int,
        val title: Int,
        val text: Int,
        val tertiary: Int,
        val accent: Int,
        val success: Int,
        val warning: Int,
        val error: Int,
        val progressTrack: Int
)

data class OverlayThemePalette(
        val rootBackground: Int,
        val scrim: Int,
        val contentCard: Int,
        val reasonChip: Int,
        val appName: Int,
        val title: Int,
        val reason: Int,
        val message: Int,
        val footer: Int,
        val extra: Int,
        val countdownBox: Int,
        val countdownTitle: Int,
        val countdownValue: Int,
        val separator: Int,
        val badgeTint: Int
)

object AppComponentTheme {
  private const val UI_PREFS = "ui_prefs"
  private const val THEME_CHOICE = "theme_choice"
  private const val WIDGET_THEME_CHOICE = "widget_theme_choice"
  private const val OVERLAY_THEME_CHOICE = "overlay_theme_choice"

  fun resolveWidgetTheme(context: Context): ComponentTheme {
    return resolveTheme(context, WIDGET_THEME_CHOICE)
  }

  fun resolveOverlayTheme(context: Context): ComponentTheme {
    return resolveTheme(context, OVERLAY_THEME_CHOICE)
  }

  fun widgetPalette(context: Context): WidgetThemePalette {
    return when (resolveWidgetTheme(context)) {
      ComponentTheme.DARK ->
              WidgetThemePalette(
                      backgroundRes = R.drawable.widget_background_dark,
                      title = 0xFFFFFFFF.toInt(),
                      text = 0xFFD6DEFF.toInt(),
                      tertiary = 0xFFB4C2E3.toInt(),
                      accent = 0xFF89A5FB.toInt(),
                      success = 0xFF6CD9A6.toInt(),
                      warning = 0xFFF1C47B.toInt(),
                      error = 0xFFD46A6A.toInt(),
                      progressTrack = 0xFF2A3E66.toInt()
              )
      ComponentTheme.LIGHT ->
              WidgetThemePalette(
                      backgroundRes = R.drawable.widget_background_light,
                      title = 0xFF140F07.toInt(),
                      text = 0xFF16294A.toInt(),
                      tertiary = 0xFF4F607D.toInt(),
                      accent = 0xFF16294A.toInt(),
                      success = 0xFF2F8F6A.toInt(),
                      warning = 0xFFB87910.toInt(),
                      error = 0xFFB24747.toInt(),
                      progressTrack = 0xFFDCE6FB.toInt()
              )
    }
  }

  fun overlayPalette(context: Context): OverlayThemePalette {
    return when (resolveOverlayTheme(context)) {
      ComponentTheme.DARK ->
              OverlayThemePalette(
                      rootBackground = 0xF2000000.toInt(),
                      scrim = 0xCC1A1A1A.toInt(),
                      contentCard = 0x3310172A.toInt(),
                      reasonChip = 0x33222A40.toInt(),
                      appName = 0xFFFFFFFF.toInt(),
                      title = 0xFFFF6B6B.toInt(),
                      reason = 0xFFFFCA28.toInt(),
                      message = 0xFFE8E8E8.toInt(),
                      footer = 0xFFBDBDBD.toInt(),
                      extra = 0xFF9FA8DA.toInt(),
                      countdownBox = 0xFF2A2A3E.toInt(),
                      countdownTitle = 0xFFBDBDBD.toInt(),
                      countdownValue = 0xFFFF6B6B.toInt(),
                      separator = 0xFFFF6B6B.toInt(),
                      badgeTint = 0xFFFF6B6B.toInt()
              )
      ComponentTheme.LIGHT ->
              OverlayThemePalette(
                      rootBackground = 0xD9EAF0F8.toInt(),
                      scrim = 0xA3C8D6EE.toInt(),
                      contentCard = 0xF5FFFFFF.toInt(),
                      reasonChip = 0xFFE3EBFA.toInt(),
                      appName = 0xFF140F07.toInt(),
                      title = 0xFFB24747.toInt(),
                      reason = 0xFFB87910.toInt(),
                      message = 0xFF16294A.toInt(),
                      footer = 0xFF4F607D.toInt(),
                      extra = 0xFF4762AC.toInt(),
                      countdownBox = 0xFFDCE6FB.toInt(),
                      countdownTitle = 0xFF4F607D.toInt(),
                      countdownValue = 0xFFB24747.toInt(),
                      separator = 0xFFB24747.toInt(),
                      badgeTint = 0xFFB24747.toInt()
              )
    }
  }

  private fun resolveTheme(context: Context, key: String): ComponentTheme {
    val prefs = context.getSharedPreferences(UI_PREFS, Context.MODE_PRIVATE)
    val raw = prefs.getString(key, null)
    val fallback = prefs.getString(THEME_CHOICE, "dark")
    val choice = normalize(raw ?: fallback)
    return when (choice) {
      "light" -> ComponentTheme.LIGHT
      "dark" -> ComponentTheme.DARK
      else -> {
        val night =
                context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        if (night == Configuration.UI_MODE_NIGHT_YES) ComponentTheme.DARK else ComponentTheme.LIGHT
      }
    }
  }

  private fun normalize(value: String?): String {
    return when (value) {
      "light", "dark", "auto" -> value
      else -> "dark"
    }
  }
}
