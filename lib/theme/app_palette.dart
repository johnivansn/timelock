import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette({
    required this.primary,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
  });

  final Color primary;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  static const classic = AppPalette(
    primary: Color(0xFF6C5CE7),
    success: Color(0xFF27AE60),
    warning: Color(0xFFF39C12),
    error: Color(0xFFE74C3C),
    info: Color(0xFF3498DB),
    background: Color(0xFF0F0F1A),
    surface: Color(0xFF1A1A2E),
    surfaceVariant: Color(0xFF2A2A3E),
    textPrimary: Colors.white,
    textSecondary: Colors.white70,
    textTertiary: Colors.white38,
  );

  static const highContrast = AppPalette(
    primary: Color(0xFFE74C3C),
    success: Color(0xFF2ECC71),
    warning: Color(0xFFF1C40F),
    error: Color(0xFFE74C3C),
    info: Color(0xFF74B9FF),
    background: Color(0xFF0B0B10),
    surface: Color(0xFF151520),
    surfaceVariant: Color(0xFF2B2B3A),
    textPrimary: Colors.white,
    textSecondary: Colors.white70,
    textTertiary: Colors.white38,
  );

  static const calm = AppPalette(
    primary: Color(0xFF4DA3FF),
    success: Color(0xFF2ECC71),
    warning: Color(0xFFF4A261),
    error: Color(0xFFE76F51),
    info: Color(0xFF5AA9E6),
    background: Color(0xFF0D1118),
    surface: Color(0xFF161B26),
    surfaceVariant: Color(0xFF252C3A),
    textPrimary: Colors.white,
    textSecondary: Colors.white70,
    textTertiary: Colors.white38,
  );

  static const forest = AppPalette(
    primary: Color(0xFF2ECC71),
    success: Color(0xFF27AE60),
    warning: Color(0xFFF39C12),
    error: Color(0xFFE74C3C),
    info: Color(0xFF1ABC9C),
    background: Color(0xFF0B1410),
    surface: Color(0xFF15201A),
    surfaceVariant: Color(0xFF223026),
    textPrimary: Colors.white,
    textSecondary: Colors.white70,
    textTertiary: Colors.white38,
  );

  static const sunset = AppPalette(
    primary: Color(0xFFFF7A59),
    success: Color(0xFF2ECC71),
    warning: Color(0xFFF6C453),
    error: Color(0xFFF25C54),
    info: Color(0xFF6DD6FF),
    background: Color(0xFF120C14),
    surface: Color(0xFF1E1623),
    surfaceVariant: Color(0xFF2A2031),
    textPrimary: Colors.white,
    textSecondary: Colors.white70,
    textTertiary: Colors.white38,
  );

  static const mono = AppPalette(
    primary: Color(0xFF9E9E9E),
    success: Color(0xFF7E7E7E),
    warning: Color(0xFF8C8C8C),
    error: Color(0xFFB0B0B0),
    info: Color(0xFF9E9E9E),
    background: Color(0xFF0E0E0E),
    surface: Color(0xFF171717),
    surfaceVariant: Color(0xFF242424),
    textPrimary: Colors.white,
    textSecondary: Colors.white70,
    textTertiary: Colors.white38,
  );
}

