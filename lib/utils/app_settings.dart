import 'package:flutter/material.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_palette.dart';
import 'package:timelock/theme/app_theme.dart';

class AppUiSettings {
  AppUiSettings({
    required this.themeChoice,
    required this.reduceAnimations,
    required this.theme,
  });

  final String themeChoice;
  final bool reduceAnimations;
  final ThemeData theme;

  AppUiSettings copyWith({
    String? themeChoice,
    bool? reduceAnimations,
    ThemeData? theme,
  }) {
    return AppUiSettings(
      themeChoice: themeChoice ?? this.themeChoice,
      reduceAnimations: reduceAnimations ?? this.reduceAnimations,
      theme: theme ?? this.theme,
    );
  }
}

class AppSettings {
  static const _prefsName = 'ui_prefs';
  static const _themeKey = 'theme_choice';
  static const _reduceKey = 'reduce_animations';

  static final ValueNotifier<AppUiSettings> notifier =
      ValueNotifier<AppUiSettings>(
    AppUiSettings(
      themeChoice: 'auto',
      reduceAnimations: false,
      theme: AppTheme.darkTheme,
    ),
  );

  static Future<void> load() async {
    final prefs = await NativeService.getSharedPreferences(_prefsName);
    final choice = _normalizeThemeChoice(prefs?[_themeKey]?.toString());
    final reduce = prefs?[_reduceKey] == true;
    final theme = await _resolveTheme(choice);
    notifier.value = AppUiSettings(
      themeChoice: choice,
      reduceAnimations: reduce,
      theme: theme,
    );
  }

  static Future<void> update({
    String? themeChoice,
    bool? reduceAnimations,
  }) async {
    final current = notifier.value;
    final newChoice = _normalizeThemeChoice(themeChoice ?? current.themeChoice);
    final newReduce = reduceAnimations ?? current.reduceAnimations;
    await NativeService.saveSharedPreference({
      'prefsName': _prefsName,
      'key': _themeKey,
      'value': newChoice,
    });
    await NativeService.saveSharedPreference({
      'prefsName': _prefsName,
      'key': _reduceKey,
      'value': newReduce,
    });
    final theme = await _resolveTheme(newChoice);
    notifier.value = current.copyWith(
      themeChoice: newChoice,
      reduceAnimations: newReduce,
      theme: theme,
    );
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

  static String _normalizeThemeChoice(String? raw) {
    switch (raw) {
      case 'light':
      case 'dark':
      case 'auto':
        return raw!;
      default:
        return 'dark';
    }
  }
}

