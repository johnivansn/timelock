import 'package:flutter/material.dart';
import 'package:timelock/screens/app_list_screen.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';

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
        } catch (_) {
          r['usedMinutes'] = 0;
          r['isBlocked'] = false;
          r['usedMillis'] = 0;
        }
        try {
          final schedules =
              await NativeService.getSchedules(r['packageName'] as String);
          r['schedules'] = schedules.map(_normalizeScheduleDays).toList();
        } catch (_) {
          r['schedules'] = [];
        }
      }

      return list;
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _normalizeScheduleDays(Map<String, dynamic> s) {
    final days = (s['daysOfWeek'] as List<dynamic>? ?? [])
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .toList();
    final converted =
        days.contains(0) ? days.map((d) => d + 1).toList() : days;
    return {
      ...s,
      'daysOfWeek': converted.where((d) => d >= 1 && d <= 7).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
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
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_rounded,
                  size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'AppTimeControl',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Preparando la app...',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
