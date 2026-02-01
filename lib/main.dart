import 'package:flutter/material.dart';
import 'package:timelock/screens/app_list_screen.dart';

void main() {
  runApp(const AppTimeControlApp());
}

class AppTimeControlApp extends StatelessWidget {
  const AppTimeControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6C5CE7),
      brightness: Brightness.dark,
      // ignore: deprecated_member_use
      background: const Color(0xFF0F0F1A),
      surface: const Color(0xFF1A1A2E),
      // ignore: deprecated_member_use
      surfaceVariant: const Color(0xFF2A2A3E),
      onSurface: Colors.white,
      onSurfaceVariant: const Color(0xFFB0B0C0),
      primary: const Color(0xFF6C5CE7),
      secondary: const Color(0xFF27AE60),
      error: const Color(0xFFE74C3C),
    );

    return MaterialApp(
      title: 'AppTimeControl',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: colorScheme.surface,
        cardTheme: CardThemeData(
          color: colorScheme.surface,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: const Size(48, 48),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: const Size(48, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          elevation: 0,
          highlightElevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        dividerTheme: DividerThemeData(
          color: colorScheme.surfaceContainerHighest,
          thickness: 1,
          space: 1,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: colorScheme.surfaceContainerHighest,
          selectedColor: colorScheme.primary.withValues(alpha: 0.2),
          labelStyle: TextStyle(color: colorScheme.onSurface),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      home: const AppListScreen(),
    );
  }
}
