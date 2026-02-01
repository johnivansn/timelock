import 'package:flutter/material.dart';
import 'package:timelock/screens/app_list_screen.dart';

void main() {
  runApp(const AppTimeControlApp());
}

class AppTimeControlApp extends StatelessWidget {
  const AppTimeControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppTimeControl',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A2E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        cardColor: const Color(0xFF1A1A2E),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A2E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        cardColor: const Color(0xFF1A1A2E),
      ),
      themeMode: ThemeMode.dark,
      home: const AppListScreen(),
    );
  }
}
