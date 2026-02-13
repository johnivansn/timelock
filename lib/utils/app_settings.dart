import 'package:flutter/material.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_palette.dart';
import 'package:timelock/theme/app_theme.dart';

class AppUiSettings {
  AppUiSettings({
    required this.themeChoice,
    required this.widgetThemeChoice,
    required this.overlayThemeChoice,
    required this.reduceAnimations,
    required this.theme,
  });

  final String themeChoice;
  final String widgetThemeChoice;
  final String overlayThemeChoice;
  final bool reduceAnimations;
  final ThemeData theme;

  AppUiSettings copyWith({
    String? themeChoice,
    String? widgetThemeChoice,
    String? overlayThemeChoice,
    bool? reduceAnimations,
    ThemeData? theme,
  }) {
    return AppUiSettings(
      themeChoice: themeChoice ?? this.themeChoice,
      widgetThemeChoice: widgetThemeChoice ?? this.widgetThemeChoice,
      overlayThemeChoice: overlayThemeChoice ?? this.overlayThemeChoice,
      reduceAnimations: reduceAnimations ?? this.reduceAnimations,
      theme: theme ?? this.theme,
    );
  }
}

class AppSettings {
  static const _prefsName = 'ui_prefs';
  static const _themeKey = 'theme_choice';
  static const _widgetThemeKey = 'widget_theme_choice';
  static const _overlayThemeKey = 'overlay_theme_choice';
  static const _reduceKey = 'reduce_animations';

  static final ValueNotifier<AppUiSettings> notifier =
      ValueNotifier<AppUiSettings>(
    AppUiSettings(
      themeChoice: 'auto',
      widgetThemeChoice: 'auto',
      overlayThemeChoice: 'auto',
      reduceAnimations: false,
      theme: AppTheme.darkTheme,
    ),
  );

  static Future<void> load() async {
    final prefs = await NativeService.getSharedPreferences(_prefsName);
    final choice = _normalizeThemeChoice(prefs?[_themeKey]?.toString());
    final widgetChoice = _normalizeThemeChoice(
      prefs?[_widgetThemeKey]?.toString(),
      fallback: choice,
    );
    final overlayChoice = _normalizeThemeChoice(
      prefs?[_overlayThemeKey]?.toString(),
      fallback: choice,
    );
    final reduce = prefs?[_reduceKey] == true;
    final theme = await _resolveTheme(choice);
    notifier.value = AppUiSettings(
      themeChoice: choice,
      widgetThemeChoice: widgetChoice,
      overlayThemeChoice: overlayChoice,
      reduceAnimations: reduce,
      theme: theme,
    );
  }

  static Future<void> update({
    String? themeChoice,
    String? widgetThemeChoice,
    String? overlayThemeChoice,
    bool? reduceAnimations,
  }) async {
    final current = notifier.value;
    final newChoice = _normalizeThemeChoice(themeChoice ?? current.themeChoice);
    final newWidgetChoice = _normalizeThemeChoice(
      widgetThemeChoice ?? current.widgetThemeChoice,
      fallback: newChoice,
    );
    final newOverlayChoice = _normalizeThemeChoice(
      overlayThemeChoice ?? current.overlayThemeChoice,
      fallback: newChoice,
    );
    final widgetChoiceChanged = newWidgetChoice != current.widgetThemeChoice;
    final overlayChoiceChanged = newOverlayChoice != current.overlayThemeChoice;
    final newReduce = reduceAnimations ?? current.reduceAnimations;
    await NativeService.saveSharedPreference({
      'prefsName': _prefsName,
      'key': _themeKey,
      'value': newChoice,
    });
    await NativeService.saveSharedPreference({
      'prefsName': _prefsName,
      'key': _widgetThemeKey,
      'value': newWidgetChoice,
    });
    await NativeService.saveSharedPreference({
      'prefsName': _prefsName,
      'key': _overlayThemeKey,
      'value': newOverlayChoice,
    });
    await NativeService.saveSharedPreference({
      'prefsName': _prefsName,
      'key': _reduceKey,
      'value': newReduce,
    });
    final theme = await _resolveTheme(newChoice);
    notifier.value = current.copyWith(
      themeChoice: newChoice,
      widgetThemeChoice: newWidgetChoice,
      overlayThemeChoice: newOverlayChoice,
      reduceAnimations: newReduce,
      theme: theme,
    );

    if (widgetChoiceChanged) {
      await NativeService.refreshWidgetsNow();
    }
    if (overlayChoiceChanged) {
      await NativeService.notifyOverlayThemeChanged();
    }
  }

  static Future<void> refreshFromSystemIfNeeded() async {
    final current = notifier.value;
    final uiAuto = current.themeChoice == 'auto';
    final widgetAuto = current.widgetThemeChoice == 'auto';
    final overlayAuto = current.overlayThemeChoice == 'auto';
    if (!uiAuto && !widgetAuto && !overlayAuto) return;

    if (uiAuto) {
      final theme = await _resolveTheme('auto');
      notifier.value = current.copyWith(theme: theme);
    }
    if (widgetAuto) {
      await NativeService.refreshWidgetsNow();
    }
    if (overlayAuto) {
      await NativeService.notifyOverlayThemeChanged();
    }
  }

  static Future<ThemeData> _resolveTheme(String choice) async {
    switch (choice) {
      case 'dark':
        AppColors.apply(AppPalette.dark);
        return AppTheme.darkTheme;
      case 'light':
        AppColors.apply(AppPalette.light);
        return AppTheme.lightTheme;
      case 'auto':
      default:
        final brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        final dark = brightness == Brightness.dark;
        AppColors.apply(dark ? AppPalette.dark : AppPalette.light);
        return dark ? AppTheme.darkTheme : AppTheme.lightTheme;
    }
  }

  static String _normalizeThemeChoice(String? raw, {String fallback = 'auto'}) {
    switch (raw) {
      case 'light':
      case 'dark':
      case 'auto':
        return raw!;
      default:
        return fallback;
    }
  }
}
