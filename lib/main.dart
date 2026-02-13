import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:timelock/screens/splash_screen.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.load();
  if (kDebugMode) {
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      debugPaintBaselinesEnabled = false;
      debugPaintSizeEnabled = false;
      debugPaintPointersEnabled = false;
      debugPaintLayerBordersEnabled = false;
      debugRepaintRainbowEnabled = false;
    });
  }
  runApp(const TimeLockApp());
}

class TimeLockApp extends StatefulWidget {
  const TimeLockApp({super.key});

  @override
  State<TimeLockApp> createState() => _TimeLockAppState();
}

class _TimeLockAppState extends State<TimeLockApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    AppSettings.refreshFromSystemIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUiSettings>(
      valueListenable: AppSettings.notifier,
      builder: (context, settings, _) {
        final theme = settings.reduceAnimations
            ? AppTheme.withReducedAnimations(settings.theme)
            : settings.theme;
        return MaterialApp(
          key: ValueKey(
              '${settings.themeChoice}-${settings.reduceAnimations}-${theme.brightness.name}'),
          title: 'TimeLock',
          debugShowCheckedModeBanner: false,
          theme: theme,
          themeMode: ThemeMode.light,
          locale: const Locale('es', 'ES'),
          supportedLocales: const [
            Locale('es', 'ES'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final data = MediaQuery.of(context);
            return MediaQuery(
              data: data.copyWith(
                disableAnimations: settings.reduceAnimations,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
