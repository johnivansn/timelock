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
    final choice = prefs?[_themeKey]?.toString() ?? 'auto';
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
    final newChoice = themeChoice ?? current.themeChoice;
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
      case 'high_contrast':
        AppColors.apply(AppPalette.highContrast);
        return AppTheme.darkHighContrast;
      case 'calm':
        AppColors.apply(AppPalette.calm);
        return AppTheme.darkCalm;
      case 'forest':
        AppColors.apply(AppPalette.forest);
        return AppTheme.darkForest;
      case 'sunset':
        AppColors.apply(AppPalette.sunset);
        return AppTheme.darkSunset;
      case 'mono':
        AppColors.apply(AppPalette.mono);
        return AppTheme.darkMono;
      case 'classic':
        AppColors.apply(AppPalette.classic);
        return AppTheme.darkTheme;
      case 'auto':
      default:
        final powerSave = await NativeService.isBatterySaverEnabled();
        final palette = powerSave ? AppPalette.calm : AppPalette.classic;
        AppColors.apply(palette);
        return powerSave ? AppTheme.darkCalm : AppTheme.darkTheme;
    }
  }
}

