import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:timelock/extensions/context_extensions.dart';
import 'package:timelock/screens/export_import_screen.dart';
import 'package:timelock/screens/notification_settings_screen.dart';
import 'package:timelock/screens/optimization_screen.dart';
import 'package:timelock/screens/permissions_screen.dart';
import 'package:timelock/screens/pin_verify_screen.dart';
import 'package:timelock/screens/restriction_edit_screen.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/app_utils.dart';
import 'package:timelock/screens/app_picker_screen.dart';
import 'package:timelock/widgets/schedule_editor_dialog.dart';

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
  final Set<String> _expandedSchedules = {};
  final Set<String> _scheduleDirty = {};

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
      final existingByPkg = {
        for (final r in _restrictions) r['packageName'] as String: r
      };
      var changed = false;

      for (final r in list) {
        final pkg = r['packageName'] as String;
        final existing = existingByPkg[pkg];

        // Preserve cached fields to avoid rebuild flicker.
        if (existing != null) {
          r['iconBytes'] = existing['iconBytes'];
          r['schedules'] = existing['schedules'];
          r['usedMinutes'] = existing['usedMinutes'];
          r['isBlocked'] = existing['isBlocked'];
          r['usedMillis'] = existing['usedMillis'];
          r['usedMinutesWeek'] = existing['usedMinutesWeek'];
        }

        try {
          final usage = await NativeService.getUsageToday(pkg);
          final usedMinutes = usage['usedMinutes'] ?? 0;
          final isBlocked = usage['isBlocked'] ?? false;
          final usedMillis = usage['usedMillis'] ?? (usedMinutes * 60000);
          final usedMinutesWeek = usage['usedMinutesWeek'] ?? 0;

          if (r['usedMinutes'] != usedMinutes ||
              r['isBlocked'] != isBlocked ||
              r['usedMillis'] != usedMillis ||
              r['usedMinutesWeek'] != usedMinutesWeek) {
            changed = true;
          }

          r['usedMinutes'] = usedMinutes;
          r['isBlocked'] = isBlocked;
          r['usedMillis'] = usedMillis;
          r['usedMinutesWeek'] = usedMinutesWeek;
        } catch (_) {
          // Keep previous values on error to avoid flicker.
        }

        if (r['schedules'] == null || _scheduleDirty.contains(pkg)) {
          try {
            final schedules = await NativeService.getSchedules(pkg);
            r['schedules'] = schedules.map(_normalizeScheduleDays).toList();
            changed = true;
            _scheduleDirty.remove(pkg);
          } catch (_) {
            r['schedules'] = [];
          }
        }

        if (r['iconBytes'] == null) {
          try {
            final bytes = await NativeService.getAppIcon(pkg);
            if (bytes != null && bytes.isNotEmpty) {
              r['iconBytes'] = bytes;
              changed = true;
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        if (changed || _loading || _restrictions.length != list.length) {
          setState(() {
            _restrictions = list;
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addRestriction(String pkg, String name, int minutes,
      {Map<String, dynamic>? limit}) async {
    try {
      await NativeService.addRestriction({
        'packageName': pkg,
        'appName': name,
        'dailyQuotaMinutes': minutes,
        'isEnabled': true,
        'limitType': limit?['limitType'] ?? 'daily',
        'dailyMode': limit?['dailyMode'] ?? 'same',
        'dailyQuotas': limit?['dailyQuotas'] ?? {},
        'weeklyQuotaMinutes': limit?['weeklyQuotaMinutes'] ?? 0,
        'weeklyResetDay': limit?['weeklyResetDay'] ?? 2,
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
    final app = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AppPickerScreen(excludedPackages: existing),
      ),
    );
    if (app == null || !mounted) return;
    final limit = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => RestrictionEditScreen(
          appName: app['appName'] as String,
          packageName: app['packageName'] as String,
          isCreate: true,
        ),
      ),
    );
    if (limit == null) return;

    await _addRestriction(
      app['packageName']! as String,
      app['appName']! as String,
      limit['dailyQuotaMinutes'] as int? ?? 30,
      limit: limit,
    );

    // Horarios se configuran desde la pantalla de edición.
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

  Future<void> _openLimitEditor(Map<String, dynamic> r) async {
    final allowed =
        await _requireAdmin('Ingresa tu PIN para modificar límites');
    if (!allowed || !mounted) return;

    final limit = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => RestrictionEditScreen(
          appName: r['appName'],
          initial: r,
        ),
      ),
    );
    if (limit == null) return;
    if (limit['deleted'] == true) {
      await _loadRestrictions();
      return;
    }
    if (limit['schedulesChanged'] == true) {
      _scheduleDirty.add(r['packageName'].toString());
    }

    await NativeService.updateRestriction({
      'packageName': r['packageName'],
      'dailyQuotaMinutes': limit['dailyQuotaMinutes'] ?? r['dailyQuotaMinutes'],
      'limitType': limit['limitType'] ?? r['limitType'],
      'dailyMode': limit['dailyMode'] ?? r['dailyMode'],
      'dailyQuotas': limit['dailyQuotas'] ?? r['dailyQuotas'],
      'weeklyQuotaMinutes': limit['weeklyQuotaMinutes'] ?? r['weeklyQuotaMinutes'],
      'weeklyResetDay': limit['weeklyResetDay'] ?? r['weeklyResetDay'],
    });
    await _loadRestrictions();
  }

  double _progressFor(Map<String, dynamic> r) {
    final quotaMinutes = _quotaMinutesFor(r);
    if (quotaMinutes <= 0) return 0.0;
    final limitType = (r['limitType'] ?? 'daily').toString();
    if (limitType == 'weekly') {
      final usedWeek = (r['usedMinutesWeek'] as int?) ?? 0;
      return (usedWeek / quotaMinutes).clamp(0.0, 1.0);
    }

    final usedMillis = (r['usedMillis'] as num?)?.toDouble();
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
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: _buildStatsCard(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.lg, AppSpacing.md, 0),
                child: _buildSectionHeader(),
              ),
            ),
            if (!_permissionsOk)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
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
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
                sliver: SliverList.separated(
                  itemCount: _restrictions.length,
                  itemBuilder: (_, i) => _restrictionCard(_restrictions[i]),
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                ),
              ),
          ],
        ),
      ),
    );
  }

    Widget _buildHeader() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
        child: Column(
        children: [
          Row(
            children: [
                const Expanded(
                  child: Text(
                    'AppTimeControl',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  onPressed: () => _showSettingsMenu(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          Container(
            height: 1,
            color: AppColors.surfaceVariant.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final active = _activeCount();
    final blocked = _blockedCount();
    final expiring = _expiringCount();
    final date = _formatShortDate();

      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1B1B2D),
            Color(0xFF1A1A2E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.surfaceVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Estado del día',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
            children: [
              _statItem(
                value: active.toString(),
                label: 'Apps activas',
                color: AppColors.info,
              ),
              _statItem(
                value: blocked.toString(),
                label: 'Bloqueadas',
                color: AppColors.error,
              ),
              _statItem(
                value: expiring.toString(),
                label: 'Por expirar',
                color: AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(
      {required String value, required String label, required Color color}) {
      return Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
          const Expanded(
            child: Text(
              'Aplicaciones restringidas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _openAddFlow,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Agregar'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
  }

  void _showSettingsMenu() {
    final screen = MediaQuery.of(context).size;
    final panelWidth = (screen.width * 0.78).clamp(240.0, 340.0);

    showGeneralDialog(
      context: context,
      barrierLabel: 'settings',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, _, __) {
        return Align(
          alignment: Alignment.centerRight,
          child: SafeArea(
            left: false,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: panelWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF21213A),
                      Color(0xFF1A1A2E),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(28)),
                  border: Border.all(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 28,
                      offset: const Offset(-8, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Row(
                        children: [
                          const Expanded(
                          child: Text(
                            'Configuración',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.sm,
                            AppSpacing.lg,
                            AppSpacing.xl),
                        children: [
                          _settingsItem(
                            icon: Icons.shield_rounded,
                            title: 'Permisos',
                            subtitle: 'Gestionar permisos del sistema',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const PermissionsScreen()),
                              ).then((_) => _checkPermissions());
                            },
                          ),
                          _settingsItem(
                            icon: Icons.lock_rounded,
                            title: 'Protección con PIN',
                            subtitle: 'Configurar PIN de administrador',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const PermissionsScreen()),
                              ).then((_) => _checkPermissions());
                            },
                          ),
                          _settingsItem(
                            icon: Icons.notifications_rounded,
                            title: 'Notificaciones',
                            subtitle: 'Configurar alertas y avisos',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const NotificationSettingsScreen()),
                              );
                            },
                          ),
                          _settingsItem(
                            icon: Icons.file_download_rounded,
                            title: 'Export / Import',
                            subtitle: 'Backup y restauración',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ExportImportScreen()),
                              ).then((_) => _loadRestrictions());
                            },
                          ),
                          _settingsItem(
                            icon: Icons.speed_rounded,
                            title: 'Optimización',
                            subtitle: 'Rendimiento y almacenamiento',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const OptimizationScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, __, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  Widget _settingsItem({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.surfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

    Widget _permissionsBanner() {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: const Color(0xFFF39C12).withValues(alpha: 0.12),
          border: Border.all(
              color: const Color(0xFFF39C12).withValues(alpha: 0.35), width: 1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 16),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                'Faltan permisos críticos',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PermissionsScreen()),
              ).then((_) => _checkPermissions()),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF39C12).withValues(alpha: 0.2),
                foregroundColor: AppColors.warning,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Configurar',
                style: TextStyle(fontSize: 12),
              ),
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
                width: 64,
                height: 64,
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
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Sin restricciones',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Toca "Agregar" para comenzar a\nmonitorear el tiempo de tus apps',
                style: TextStyle(
                  fontSize: 12,
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
    final limitType = (r['limitType'] ?? 'daily').toString();
    final quota = _quotaMinutesFor(r);
    final usedMinutes =
        limitType == 'weekly' ? (r['usedMinutesWeek'] as int? ?? 0) : (r['usedMinutes'] as int);
    final usedMillis = limitType == 'weekly'
        ? usedMinutes * 60000
        : (r['usedMillis'] as num?)?.toInt() ?? usedMinutes * 60000;
    final remainingMillis = (quota * 60000 - usedMillis).clamp(0, quota * 60000);
    final remainingMinutes = (quota - usedMinutes).clamp(0, quota);

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
          onTap: () => _openLimitEditor(r),
          borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1A1A2E),
                  Color(0xFF1C1C30),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: blocked
                    ? AppColors.error
                    : AppColors.surfaceVariant.withValues(alpha: 0.8),
                width: blocked ? 1.5 : 1,
              ),
            ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildAppIcon(r),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          r['appName'],
                          style: const TextStyle(
                            fontSize: 14,
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
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'BLOQUEADA',
                                style: TextStyle(
                                  fontSize: 9,
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
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      color: progressColor,
                      backgroundColor: AppColors.surfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                _usageSummaryTextRich(
                  usedMinutes,
                  usedMillis,
                  remainingMinutes,
                  remainingMillis,
                  quota,
                  limitType,
                  progressColor,
                ),
                  const SizedBox(height: AppSpacing.xs),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.xs),
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
    if (schedules.isEmpty) {
      return const SizedBox.shrink();
    }
    final activeSchedules = schedules
        .where((s) => (s['isEnabled'] as bool? ?? true) == true)
        .toList();
    if (activeSchedules.isEmpty) {
      return const SizedBox.shrink();
    }
    final pkg = r['packageName']?.toString() ?? '';
    final isExpanded = _expandedSchedules.contains(pkg);
    final summary = _scheduleSummary(activeSchedules);

    final titleRow = Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.surfaceVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.schedule_rounded,
                color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              summary,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
            if (activeSchedules.length > 1)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ),
        ],
      ),
    );

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            if (activeSchedules.length > 1)
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                    _expandedSchedules.remove(pkg);
                  } else {
                    _expandedSchedules.add(pkg);
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: titleRow,
              ),
            )
          else
            titleRow,
            if (activeSchedules.length > 1)
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topLeft,
                child: isExpanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.xs),
                          ..._scheduleDetails(activeSchedules),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
        ],
      ),
    );
  }

  List<Widget> _scheduleDetails(List<Map<String, dynamic>> schedules) {
    final active = schedules
        .where((s) => (s['isEnabled'] as bool? ?? true) == true)
        .toList();
    return active.map((s) {
      final days = (s['daysOfWeek'] as List<dynamic>? ?? [])
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((d) => d >= 1 && d <= 7)
          .toList();
      final timeText = _formatTimeRange(
        s['startHour'] as int? ?? 0,
        s['startMinute'] as int? ?? 0,
        s['endHour'] as int? ?? 0,
        s['endMinute'] as int? ?? 0,
      );
      final dayText = _formatDays(days);
      final enabled = s['isEnabled'] as bool? ?? true;
      final bgColor = enabled
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.error.withValues(alpha: 0.12);
      final borderColor = enabled
          ? AppColors.primary.withValues(alpha: 0.35)
          : AppColors.error.withValues(alpha: 0.35);

      return Padding(
        padding: const EdgeInsets.only(left: 20, bottom: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      timeText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        dayText,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

    Widget _buildAppIcon(Map<String, dynamic> r) {
      final bytes = r['iconBytes'];
      if (bytes is Uint8List && bytes.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        );
      }
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.apps_rounded,
          size: 20,
          color: AppColors.textTertiary,
        ),
      );
    }

  int _activeCount() {
    return _restrictions.where((r) => (r['isEnabled'] ?? true) == true).length;
  }

  int _blockedCount() {
    return _restrictions.where((r) => r['isBlocked'] == true).length;
  }

  int _expiringCount() {
    return _restrictions.where((r) {
      if (r['isBlocked'] == true) return false;
      final progress = _progressFor(r);
      return progress >= 0.8 && progress < 1.0;
    }).length;
  }

  String _formatShortDate() {
    final now = DateTime.now();
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic'
    ];
    final month = months[now.month - 1];
    return '${now.day} $month ${now.year}';
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
    if (schedules.length == 1) return '$dayText $timeText';
    return '$dayText $timeText  +${schedules.length - 1} más';
  }

  String _formatTimeRange(int sh, int sm, int eh, int em) {
    final start = _fmt(sh, sm);
    final end = _fmt(eh, em);
    if (eh * 60 + em <= sh * 60 + sm) {
      return '$start-$end (día sig.)';
    }
    return '$start-$end';
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
    return days.map((d) => labels[d] ?? '?').join('·');
  }

  int _quotaMinutesFor(Map<String, dynamic> r) {
    final limitType = (r['limitType'] ?? 'daily').toString();
    if (limitType == 'weekly') {
      return (r['weeklyQuotaMinutes'] as int?) ?? 0;
    }

    final dailyMode = (r['dailyMode'] ?? 'same').toString();
    if (dailyMode != 'per_day') {
      return (r['dailyQuotaMinutes'] as int?) ?? 0;
    }

    final day = _todayDayOfWeek();
    final map = _dailyQuotasMap(r['dailyQuotas']);
    return map[day] ?? 0;
  }

  int _todayDayOfWeek() {
    final weekday = DateTime.now().weekday; // 1=Mon..7=Sun
    return weekday == 7 ? 1 : weekday + 1; // 1=Sun..7=Sat
  }

  Map<int, int> _dailyQuotasMap(dynamic value) {
    if (value == null) return {};
    if (value is String) {
      final map = <int, int>{};
      for (final pair in value.split(',')) {
        final parts = pair.split(':');
        if (parts.length != 2) continue;
        final day = int.tryParse(parts[0]);
        final minutes = int.tryParse(parts[1]);
        if (day == null || minutes == null) continue;
        map[day] = minutes;
      }
      return map;
    }
    if (value is Map) {
      final map = <int, int>{};
      value.forEach((k, v) {
        final day = int.tryParse(k.toString());
        final minutes = int.tryParse(v.toString());
        if (day == null || minutes == null) return;
        map[day] = minutes;
      });
      return map;
    }
    return {};
  }

  String _formatUsageText(
      int usedMinutes, int usedMillis, int quotaMinutes, String limitType) {
    if (limitType == 'weekly') {
      return '${AppUtils.formatTime(usedMinutes)} usados';
    }
    if (quotaMinutes <= 1) {
      final seconds = (usedMillis / 1000).floor();
      return '${seconds}s usados';
    }
    return '${AppUtils.formatTime(usedMinutes)} usados';
  }

  String _formatRemainingText(
      int remainingMinutes, int remainingMillis, int quotaMinutes, String limitType) {
    if (limitType == 'weekly') {
      return '${AppUtils.formatTime(remainingMinutes)} restantes';
    }
    if (quotaMinutes <= 1) {
      final seconds = (remainingMillis / 1000).ceil();
      return '${seconds}s restantes';
    }
    return '${AppUtils.formatTime(remainingMinutes)} restantes';
  }

  String _usageSummaryText(int usedMinutes, int usedMillis, int remainingMinutes,
      int remainingMillis, int quotaMinutes, String limitType) {
    final used = _formatUsageText(usedMinutes, usedMillis, quotaMinutes, limitType);
    final remaining =
        _formatRemainingText(remainingMinutes, remainingMillis, quotaMinutes, limitType);
    return '$used · $remaining';
  }

    Widget _usageSummaryTextRich(
        int usedMinutes,
        int usedMillis,
        int remainingMinutes,
        int remainingMillis,
        int quotaMinutes,
        String limitType,
        Color usedColor) {
      final used = _formatUsageText(usedMinutes, usedMillis, quotaMinutes, limitType);
      final remaining =
          _formatRemainingText(remainingMinutes, remainingMillis, quotaMinutes, limitType);
      return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: used,
              style: TextStyle(
                fontSize: 11,
                color: usedColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const TextSpan(
              text: ' · ',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
            TextSpan(
              text: remaining,
              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
          ],
        ),
      );
    }
}
