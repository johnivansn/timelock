import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timelock/extensions/context_extensions.dart';
import 'package:timelock/screens/export_import_screen.dart';
import 'package:timelock/screens/notification_settings_screen.dart';
import 'package:timelock/screens/optimization_screen.dart';
import 'package:timelock/screens/permissions_screen.dart';
import 'package:timelock/screens/pin_verify_screen.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/app_utils.dart';
import 'package:timelock/widgets/app_picker_dialog.dart';
import 'package:timelock/widgets/schedule_editor_dialog.dart';
import 'package:timelock/widgets/time_picker_dialog.dart';

class AppListScreen extends StatefulWidget {
  const AppListScreen({super.key, this.initialRestrictions});

  final List<Map<String, dynamic>>? initialRestrictions;

  @override
  State<AppListScreen> createState() => _AppListScreenState();
}

class _AppListScreenState extends State<AppListScreen> {
  List<Map<String, dynamic>> _restrictions = [];
  bool _loading = true;
  bool _permissionsOk = false;
  bool _adminEnabled = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialRestrictions != null) {
      _restrictions = widget.initialRestrictions!;
      _loading = false;
    }
    _init();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _startMonitoring();
    await _checkPermissions();
    if (widget.initialRestrictions == null) {
      await _loadRestrictions();
    }
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || _loading) return;
      _loadRestrictions();
    });
  }

  Future<bool> _checkPermissions() async {
    try {
      final usage = await NativeService.checkUsagePermission();
      final acc = await NativeService.checkAccessibilityPermission();
      final admin = await NativeService.isAdminEnabled();
      if (mounted) {
        setState(() {
          _permissionsOk = usage && acc;
          _adminEnabled = admin;
        });
      }
    } catch (_) {}
    return false;
  }

  Future<void> _startMonitoring() async {
    try {
      await NativeService.startMonitoring();
    } catch (_) {}
  }

  Future<void> _loadRestrictions() async {
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

      if (mounted) {
        setState(() {
          _restrictions = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addRestriction(String pkg, String name, int minutes) async {
    try {
      await NativeService.addRestriction({
        'packageName': pkg,
        'appName': name,
        'dailyQuotaMinutes': minutes,
        'isEnabled': true,
      });
      await _loadRestrictions();
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  Future<bool> _requireAdmin(String reason) async {
    if (!_adminEnabled) return true;
    if (!mounted) return false;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PinVerifyScreen(reason: reason)),
    );
    return result == true;
  }

  Future<void> _deleteRestriction(Map<String, dynamic> r) async {
    try {
      await NativeService.deleteRestriction(r['packageName']);
      await _loadRestrictions();
    } catch (_) {
      _restrictions.removeWhere((x) => x['packageName'] == r['packageName']);
      if (mounted) setState(() {});
    }
  }

  void _openAddFlow() async {
    final existing =
        _restrictions.map((r) => r['packageName'] as String).toSet();

    if (!mounted) return;
    final app = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppPickerDialog(excludedPackages: existing),
    );
    if (app == null || !mounted) return;

    final minutes = await showDialog<int>(
      context: context,
      builder: (_) => const QuotaTimePicker(),
    );
    if (minutes == null) return;

    await _addRestriction(
        app['packageName']! as String, app['appName']! as String, minutes);
  }

  Future<void> _openScheduleEditor(Map<String, dynamic> r) async {
    final allowed =
        await _requireAdmin('Ingresa tu PIN para modificar horarios');
    if (!allowed || !mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleEditorDialog(
        appName: r['appName'],
        packageName: r['packageName'],
      ),
    );
    await _loadRestrictions();
  }

  double _progressFor(Map<String, dynamic> r) {
    final usedMillis = (r['usedMillis'] as num?)?.toDouble();
    final quotaMinutes = (r['dailyQuotaMinutes'] as int).toDouble();
    if (usedMillis != null) {
      final quotaMillis = quotaMinutes * 60000.0;
      return (usedMillis / quotaMillis).clamp(0.0, 1.0);
    }
    final used = (r['usedMinutes'] as int).toDouble();
    return (used / quotaMinutes).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (!_permissionsOk)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
                child: _permissionsBanner(),
              ),
            ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            )
          else if (_restrictions.isEmpty)
            SliverFillRemaining(child: _emptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverList.separated(
                itemCount: _restrictions.length,
                itemBuilder: (_, i) => _restrictionCard(_restrictions[i]),
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddFlow,
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text('Agregar'),
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      flexibleSpace: const FlexibleSpaceBar(
        titlePadding:
            EdgeInsets.only(left: AppSpacing.lg, bottom: AppSpacing.md),
        title: Text('AppTimeControl'),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 24),
          onPressed: () => _showSettingsMenu(),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _menuItem(
              icon: Icons.security_outlined,
              title: 'Permisos',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PermissionsScreen()),
                ).then((_) => _checkPermissions());
              },
            ),
            _menuItem(
              icon: Icons.notifications_outlined,
              title: 'Notificaciones',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen()),
                );
              },
            ),
            _menuItem(
              icon: Icons.sync_outlined,
              title: 'Export / Import',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExportImportScreen()),
                ).then((_) => _loadRestrictions());
              },
            ),
            _menuItem(
              icon: Icons.speed_outlined,
              title: 'Optimización',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OptimizationScreen()),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    );
  }

  Widget _permissionsBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.warning, width: 1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 24),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text(
              'Faltan permisos necesarios',
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PermissionsScreen()),
            ).then((_) => _checkPermissions()),
            child: const Text('Configurar'),
          ),
        ],
      ),
    );
  }


  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Sin restricciones',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Toca "Agregar" para comenzar a\nmonitorear el tiempo de tus apps',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textTertiary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _restrictionCard(Map<String, dynamic> r) {
    final blocked = r['isBlocked'] as bool;
    final progress = _progressFor(r);
    final used = r['usedMinutes'] as int;
    final quota = r['dailyQuotaMinutes'] as int;
    final usedMillis = (r['usedMillis'] as num?)?.toInt() ?? used * 60000;
    final remainingMillis = (quota * 60000 - usedMillis).clamp(0, quota * 60000);
    final remainingMinutes = (quota - used).clamp(0, quota);

    final progressColor = blocked
        ? AppColors.error
        : progress > 0.75
            ? AppColors.warning
            : AppColors.success;

    return Dismissible(
      key: ValueKey(r['packageName']),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) =>
          _requireAdmin('Ingresa tu PIN para eliminar esta restricción'),
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: AppSpacing.lg),
            child: Icon(Icons.delete_outline_rounded,
                color: Colors.white, size: 28),
          ),
        ),
      ),
      onDismissed: (_) => _deleteRestriction(r),
      child: Card(
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: blocked
                ? BoxDecoration(
                    border: Border.all(color: AppColors.error, width: 2),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r['appName'],
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (blocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded,
                                color: AppColors.error, size: 14),
                            SizedBox(width: AppSpacing.xs),
                            Text(
                              'BLOQUEADA',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: progressColor,
                    backgroundColor: AppColors.surfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatUsageText(used, usedMillis, quota),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    Text(
                      blocked
                          ? 'Se abre a medianoche'
                          : _formatRemainingText(remainingMinutes, remainingMillis, quota),
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            blocked ? AppColors.error : AppColors.textTertiary,
                        fontWeight:
                            blocked ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.md),
                _scheduleRow(r),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scheduleRow(Map<String, dynamic> r) {
    final schedules = (r['schedules'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final summary = _scheduleSummary(schedules);

    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded,
              color: AppColors.textTertiary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              summary,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textTertiary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: () => _openScheduleEditor(r),
            icon: const Icon(Icons.edit_calendar_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceVariant,
              padding: const EdgeInsets.all(AppSpacing.sm),
            ),
          ),
        ],
      ),
    );
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

  String _scheduleSummary(List<Map<String, dynamic>> schedules) {
    if (schedules.isEmpty) return 'Sin horarios';
    final first = schedules.first;
    final days = (first['daysOfWeek'] as List<dynamic>? ?? [])
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .where((d) => d >= 1 && d <= 7)
        .toList();
    final dayText = _formatDays(days);
    final timeText = _formatTimeRange(
      first['startHour'] as int? ?? 0,
      first['startMinute'] as int? ?? 0,
      first['endHour'] as int? ?? 0,
      first['endMinute'] as int? ?? 0,
    );
    if (schedules.length == 1) return '$dayText · $timeText';
    return '$dayText · $timeText  +${schedules.length - 1} más';
  }

  String _formatTimeRange(int sh, int sm, int eh, int em) {
    final start = _fmt(sh, sm);
    final end = _fmt(eh, em);
    if (eh * 60 + em <= sh * 60 + sm) {
      return '$start – $end (día sig.)';
    }
    return '$start – $end';
  }

  String _fmt(int h, int m) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _formatDays(List<int> days) {
    if (days.isEmpty) return 'Sin días';
    const labels = {
      1: 'D',
      2: 'L',
      3: 'M',
      4: 'X',
      5: 'J',
      6: 'V',
      7: 'S',
    };
    return days.map((d) => labels[d] ?? '?').join(' ');
  }

  String _formatUsageText(int usedMinutes, int usedMillis, int quotaMinutes) {
    if (quotaMinutes <= 1) {
      final seconds = (usedMillis / 1000).floor();
      return '${seconds}s usados';
    }
    return '${AppUtils.formatTime(usedMinutes)} usados';
  }

  String _formatRemainingText(
      int remainingMinutes, int remainingMillis, int quotaMinutes) {
    if (quotaMinutes <= 1) {
      final seconds = (remainingMillis / 1000).ceil();
      return '${seconds}s restantes';
    }
    return '${AppUtils.formatTime(remainingMinutes)} restantes';
  }
}
