import 'package:flutter/material.dart';
import 'package:timelock/screens/splash_screen.dart';
import 'package:timelock/theme/app_theme.dart';

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
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const SplashScreen(),
    );
  }
}
