import 'package:flutter/material.dart';
import 'package:timelock/theme/app_palette.dart';

class AppTheme {
  static ThemeData get darkTheme =>
      _buildTheme(AppPalette.dark, Brightness.dark);
  static ThemeData get lightTheme =>
      _buildTheme(AppPalette.light, Brightness.light);

  static ThemeData _buildTheme(AppPalette palette, Brightness brightness) {
    final onPrimary = _onColor(palette.primary);
    final baseText = ThemeData(
      useMaterial3: true,
      brightness: brightness,
    ).textTheme;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
      // ignore: deprecated_member_use
      background: palette.background,
      surface: palette.surface,
      // ignore: deprecated_member_use
      surfaceVariant: palette.surfaceVariant,
    ).copyWith(
      onPrimary: onPrimary,
      onSurface: palette.textPrimary,
      onSurfaceVariant: palette.textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(
          color: palette.textSecondary,
          size: 20,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        hintStyle: TextStyle(color: palette.textTertiary),
      ),
      dividerTheme: DividerThemeData(
        color: palette.surfaceVariant,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(
        color: palette.textSecondary,
        size: 20,
      ),
      textTheme: baseText.copyWith(
        bodyLarge: baseText.bodyLarge?.copyWith(color: palette.textPrimary),
        bodyMedium: baseText.bodyMedium?.copyWith(color: palette.textPrimary),
        bodySmall: baseText.bodySmall?.copyWith(color: palette.textTertiary),
        titleLarge: baseText.titleLarge?.copyWith(color: palette.textPrimary),
        titleMedium: baseText.titleMedium?.copyWith(color: palette.textPrimary),
        titleSmall: baseText.titleSmall?.copyWith(color: palette.textSecondary),
        labelLarge: baseText.labelLarge?.copyWith(color: palette.textPrimary),
        labelMedium:
            baseText.labelMedium?.copyWith(color: palette.textSecondary),
        labelSmall: baseText.labelSmall?.copyWith(color: palette.textTertiary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
        linearTrackColor: palette.surfaceVariant,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.success;
          }
          return Color.lerp(
                  palette.textTertiary, palette.surfaceVariant, 0.4) ??
              palette.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.success.withValues(alpha: 0.5);
          }
          return palette.surfaceVariant;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surface,
        contentTextStyle: TextStyle(color: palette.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  static Color _onColor(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  static ThemeData withReducedAnimations(ThemeData base) {
    return base.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _NoTransitionsBuilder(),
          TargetPlatform.iOS: _NoTransitionsBuilder(),
        },
      ),
    );
  }
}

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class AppColors {
  static AppPalette _palette = AppPalette.dark;

  static void apply(AppPalette palette) {
    _palette = palette;
  }

  static Color get primary => _palette.primary;
  static Color get success => _palette.success;
  static Color get warning => _palette.warning;
  static Color get error => _palette.error;
  static Color get info => _palette.info;
  static Color get background => _palette.background;
  static Color get surface => _palette.surface;
  static Color get surfaceVariant => _palette.surfaceVariant;
  static Color get textPrimary => _palette.textPrimary;
  static Color get textSecondary => _palette.textSecondary;
  static Color get textTertiary => _palette.textTertiary;

  static Color onColor(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 28.0;
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
}
