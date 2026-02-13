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

  static const dark = AppPalette(
    primary: Color(0xFF89A5FB),
    success: Color(0xFF6CD9A6),
    warning: Color(0xFFF1C47B),
    error: Color(0xFFD46A6A),
    info: Color(0xFF89A5FB),
    background: Color(0xFF080E1A),
    surface: Color(0xFF16294A),
    surfaceVariant: Color(0xFF2A3E66),
    textPrimary: Colors.white,
    textSecondary: Color(0xFFD6DEFF),
    textTertiary: Color(0xFFB4C2E3),
  );

  static const light = AppPalette(
    primary: Color(0xFF16294A),
    success: Color(0xFF2F8F6A),
    warning: Color(0xFFB87910),
    error: Color(0xFFB24747),
    info: Color(0xFF4762AC),
    background: Color(0xFFEAF0F8),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFDCE6FB),
    textPrimary: Color(0xFF140F07),
    textSecondary: Color(0xFF16294A),
    textTertiary: Color(0xFF4F607D),
  );
}
