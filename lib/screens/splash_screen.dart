import 'package:flutter/material.dart';
import 'package:timelock/screens/app_list_screen.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/schedule_utils.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await NativeService.startMonitoring();
    } catch (_) {}

    final initial = await _loadInitialRestrictions();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AppListScreen(initialRestrictions: initial),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadInitialRestrictions() async {
    try {
      final list = await NativeService.getRestrictions();

      for (final r in list) {
        try {
          final usage = await NativeService.getUsageToday(r['packageName']);
          r['usedMinutes'] = usage['usedMinutes'] ?? 0;
          r['isBlocked'] = usage['isBlocked'] ?? false;
          r['usedMillis'] = usage['usedMillis'] ?? (r['usedMinutes'] * 60000);
          r['usedMinutesWeek'] = usage['usedMinutesWeek'] ?? 0;
        } catch (_) {
          r['usedMinutes'] = 0;
          r['isBlocked'] = false;
          r['usedMillis'] = 0;
          r['usedMinutesWeek'] = 0;
        }
        try {
          final schedules =
              await NativeService.getSchedules(r['packageName'] as String);
          r['schedules'] = schedules.map(normalizeScheduleDays).toList();
        } catch (_) {
          r['schedules'] = [];
        }
      }

      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.surface, AppColors.surfaceVariant],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield_rounded,
                    size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'TimeLock',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Preparando la app...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
