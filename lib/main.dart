import 'package:flutter/material.dart';
import 'package:timelock/screens/splash_screen.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.load();
  runApp(AppTimeControlApp());
}

class AppTimeControlApp extends StatelessWidget {
  AppTimeControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUiSettings>(
      valueListenable: AppSettings.notifier,
      builder: (context, settings, _) {
        final theme = settings.reduceAnimations
            ? AppTheme.withReducedAnimations(settings.theme)
            : settings.theme;
        return MaterialApp(
          title: 'AppTimeControl',
          debugShowCheckedModeBanner: false,
          theme: theme,
          themeMode: ThemeMode.dark,
          builder: (context, child) {
            final data = MediaQuery.of(context);
            return MediaQuery(
              data: data.copyWith(
                disableAnimations: settings.reduceAnimations,
              ),
              child: child ?? SizedBox.shrink(),
            );
          },
          home: SplashScreen(),
        );
      },
    );
  }
}

