import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:timelock/extensions/context_extensions.dart';
import 'package:timelock/screens/export_import_screen.dart';
import 'package:timelock/screens/appearance_screen.dart';
import 'package:timelock/screens/notification_settings_screen.dart';
import 'package:timelock/screens/optimization_screen.dart';
import 'package:timelock/screens/permissions_screen.dart';
import 'package:timelock/screens/pin_verify_screen.dart';
import 'package:timelock/screens/restriction_edit_screen.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/app_utils.dart';
import 'package:timelock/utils/app_motion.dart';
import 'package:timelock/utils/date_utils.dart';
import 'package:timelock/utils/schedule_utils.dart';
import 'package:timelock/screens/app_picker_screen.dart';
import 'package:timelock/widgets/schedule_editor_dialog.dart';
import 'package:timelock/widgets/date_block_editor_dialog.dart';

class AppListScreen extends StatefulWidget {
  AppListScreen({super.key, this.initialRestrictions});

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
  final Set<String> _expandedDateBlocks = {};
  final Set<String> _dateBlockDirty = {};
  final Set<String> _iconLoading = {};
  int _iconPrefetchCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialRestrictions != null) {
      _restrictions = widget.initialRestrictions!;
      _loading = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updatePrefetchCount();
    });
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

  Future<void> _updatePrefetchCount() async {
    final memoryClass = await NativeService.getMemoryClass();
    final powerSave = await NativeService.isBatterySaverEnabled();
    final width = MediaQuery.of(context).size.width;
    if (!mounted) return;
    setState(() {
      _iconPrefetchCount = AppUtils.computeIconPrefetchCount(
        screenWidth: width,
        memoryClassMb: memoryClass,
        powerSave: powerSave,
      );
    });
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(seconds: 10), (_) {
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
      final prefetchCount =
          _iconPrefetchCount == 0 ? 12 : _iconPrefetchCount;
      final prefetchSet = list
          .take(prefetchCount.clamp(0, list.length))
          .map((r) => r['packageName'] as String)
          .toSet();
      var changed = false;

      for (final r in list) {
        final pkg = r['packageName'] as String;
        final existing = existingByPkg[pkg];

        // Preserve cached fields to avoid rebuild flicker.
        if (existing != null) {
          r['iconBytes'] = existing['iconBytes'];
          r['schedules'] = existing['schedules'];
          r['dateBlocks'] = existing['dateBlocks'];
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
            r['schedules'] = schedules.map(normalizeScheduleDays).toList();
            changed = true;
            _scheduleDirty.remove(pkg);
          } catch (_) {
            r['schedules'] = [];
          }
        }

        if (r['dateBlocks'] == null || _dateBlockDirty.contains(pkg)) {
          try {
            final blocks = await NativeService.getDateBlocks(pkg);
            r['dateBlocks'] = blocks;
            changed = true;
            _dateBlockDirty.remove(pkg);
          } catch (_) {
            r['dateBlocks'] = [];
          }
        }

        if (r['iconBytes'] == null && prefetchSet.contains(pkg)) {
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
        'weeklyResetHour': limit?['weeklyResetHour'] ?? 0,
        'weeklyResetMinute': limit?['weeklyResetMinute'] ?? 0,
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

  Future<void> _openDateBlockEditor(Map<String, dynamic> r) async {
    final allowed =
        await _requireAdmin('Ingresa tu PIN para modificar fechas');
    if (!allowed || !mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DateBlockEditorDialog(
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
    if (limit['dateBlocksChanged'] == true) {
      _dateBlockDirty.add(r['packageName'].toString());
    }

    await NativeService.updateRestriction({
      'packageName': r['packageName'],
      'dailyQuotaMinutes': limit['dailyQuotaMinutes'] ?? r['dailyQuotaMinutes'],
      'limitType': limit['limitType'] ?? r['limitType'],
      'dailyMode': limit['dailyMode'] ?? r['dailyMode'],
      'dailyQuotas': limit['dailyQuotas'] ?? r['dailyQuotas'],
      'weeklyQuotaMinutes': limit['weeklyQuotaMinutes'] ?? r['weeklyQuotaMinutes'],
      'weeklyResetDay': limit['weeklyResetDay'] ?? r['weeklyResetDay'],
      'weeklyResetHour': limit['weeklyResetHour'] ?? r['weeklyResetHour'],
      'weeklyResetMinute': limit['weeklyResetMinute'] ?? r['weeklyResetMinute'],
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
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: _buildStatsCard(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.lg, AppSpacing.md, 0),
                child: _buildSectionHeader(),
              ),
            ),
            if (!_permissionsOk)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                  child: _permissionsBanner(),
                ),
              ),
            if (_loading)
              SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              )
            else if (_restrictions.isEmpty)
              SliverFillRemaining(child: _emptyState())
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
                sliver: SliverList.separated(
                  itemCount: _restrictions.length,
                  itemBuilder: (_, i) => _restrictionCard(_restrictions[i]),
                  separatorBuilder: (_, __) =>
                      SizedBox(height: AppSpacing.md),
                ),
              ),
          ],
        ),
      ),
    );
  }

    Widget _buildHeader() {
      return Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
        child: Column(
        children: [
          Row(
            children: [
                Expanded(
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
                  icon: Icon(Icons.settings_outlined, size: 20),
                  onPressed: () => _showSettingsMenu(),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
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
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.background,
              AppColors.surface,
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
                Expanded(
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
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
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
            SizedBox(height: 2),
            Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
          Expanded(
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
            icon: Icon(Icons.add_rounded, size: 16),
            label: Text('Agregar'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              foregroundColor: AppColors.primary,
              textStyle: TextStyle(
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
      barrierColor: AppColors.background.withValues(alpha: 0.55),
      transitionDuration: AppMotion.duration(Duration(milliseconds: 260)),
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
                  gradient: LinearGradient(
                    colors: [
                      AppColors.surfaceVariant,
                      AppColors.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.horizontal(left: Radius.circular(28)),
                  border: Border.all(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.7),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.background.withValues(alpha: 0.55),
                      blurRadius: 28,
                      offset: Offset(-8, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(height: AppSpacing.md),
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Row(
                        children: [
                          Expanded(
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
                            icon: Icon(Icons.close_rounded),
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
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
                                    builder: (_) => PermissionsScreen()),
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
                                    builder: (_) => PermissionsScreen()),
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
                                        NotificationSettingsScreen()),
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
                                    builder: (_) => ExportImportScreen()),
                              ).then((_) => _loadRestrictions());
                            },
                          ),
                          _settingsItem(
                            icon: Icons.palette_rounded,
                            title: 'Apariencia',
                            subtitle: 'Tema y animaciones',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => AppearanceScreen()),
                              );
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
                                        OptimizationScreen()),
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
            begin: Offset(1, 0),
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
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(AppSpacing.md),
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
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
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
        padding: EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.35), width: 1),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 16),
            SizedBox(width: AppSpacing.sm),
            Expanded(
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
                MaterialPageRoute(builder: (_) => PermissionsScreen()),
              ).then((_) => _checkPermissions()),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.warning.withValues(alpha: 0.2),
                      foregroundColor: AppColors.onColor(AppColors.warning),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
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
          padding: EdgeInsets.all(AppSpacing.xxl),
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
                child: Icon(
                  Icons.shield_outlined,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                'Sin restricciones',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
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
        child: Align(
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
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
                gradient: LinearGradient(
                  colors: [
                    AppColors.surface,
                    AppColors.surfaceVariant,
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
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          r['appName'],
                          style: TextStyle(
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
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
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
                  SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      color: progressColor,
                      backgroundColor: AppColors.surfaceVariant,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                _usageSummaryTextRich(
                  usedMinutes,
                  usedMillis,
                  remainingMinutes,
                  remainingMillis,
                  quota,
                  limitType,
                  (r['weeklyResetDay'] as int?) ?? 2,
                  (r['weeklyResetHour'] as int?) ?? 0,
                  (r['weeklyResetMinute'] as int?) ?? 0,
                  progressColor,
                ),
                  SizedBox(height: AppSpacing.xs),
                  Divider(height: 1),
                  SizedBox(height: AppSpacing.xs),
                  _directBlocksRow(r),
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
      return SizedBox.shrink();
    }
    final activeSchedules = schedules
        .where((s) => (s['isEnabled'] as bool? ?? true) == true)
        .toList();
    if (activeSchedules.isEmpty) {
      return SizedBox.shrink();
    }
    final totalCount = schedules.length;
    final activeCount = activeSchedules.length;
    final pkg = r['packageName']?.toString() ?? '';
    final isExpanded = _expandedSchedules.contains(pkg);
    final summary = _scheduleSummary(activeSchedules);

    final titleRow = Container(
      padding: EdgeInsets.symmetric(
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
            child: Icon(Icons.schedule_rounded,
                color: AppColors.primary, size: 16),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              summary,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (totalCount > 0)
            _countBadge(totalCount, activeCount),
          IconButton(
            onPressed: () => _openScheduleEditor(r),
            icon: Icon(Icons.edit_outlined, size: 16),
            style: IconButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              backgroundColor: AppColors.surface,
              minimumSize: Size(28, 28),
              fixedSize: Size(28, 28),
              padding: EdgeInsets.all(4),
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
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: titleRow,
                ),
              )
            else
              titleRow,
            if (activeSchedules.length > 1)
              AnimatedSize(
                duration: AppMotion.duration(Duration(milliseconds: 200)),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topLeft,
                child: isExpanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: AppSpacing.xs),
                          ..._scheduleDetails(activeSchedules),
                        ],
                      )
                    : SizedBox.shrink(),
              ),
        ],
      ),
    );
  }

  Widget _dateBlockRow(Map<String, dynamic> r) {
    final blocks = (r['dateBlocks'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (blocks.isEmpty) {
      return SizedBox.shrink();
    }
    final activeBlocks =
        blocks.where((b) => (b['isEnabled'] as bool? ?? true)).toList();
    if (activeBlocks.isEmpty) {
      return SizedBox.shrink();
    }
    final totalCount = blocks.length;
    final activeCount = activeBlocks.length;
    final pkg = r['packageName']?.toString() ?? '';
    final isExpanded = _expandedDateBlocks.contains(pkg);
    final summary = _dateBlockSummary(activeBlocks);

    final titleRow = Container(
      margin: EdgeInsets.only(top: AppSpacing.xs),
      padding:
          EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
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
              color: AppColors.info.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.event_busy_rounded,
                color: AppColors.info, size: 16),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              summary,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (totalCount > 0)
            _countBadge(totalCount, activeCount),
          IconButton(
            onPressed: () => _openDateBlockEditor(r),
            icon: Icon(Icons.edit_outlined, size: 16),
            style: IconButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              backgroundColor: AppColors.surface,
              minimumSize: Size(28, 28),
              fixedSize: Size(28, 28),
              padding: EdgeInsets.all(4),
            ),
          ),
          if (activeBlocks.length > 1)
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
          if (activeBlocks.length > 1)
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedDateBlocks.remove(pkg);
                  } else {
                    _expandedDateBlocks.add(pkg);
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: titleRow,
              ),
            )
          else
            titleRow,
          if (activeBlocks.length > 1)
            AnimatedSize(
              duration: AppMotion.duration(Duration(milliseconds: 200)),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              child: isExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: AppSpacing.xs),
                        ..._dateBlockDetails(activeBlocks),
                      ],
                    )
                  : SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  Widget _directBlocksRow(Map<String, dynamic> r) {
    final schedules = (r['schedules'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final blocks = (r['dateBlocks'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final scheduleActive = schedules
        .where((s) => (s['isEnabled'] as bool? ?? true))
        .length;
    final dateActive =
        blocks.where((b) => (b['isEnabled'] as bool? ?? true)).length;

    return Row(
      children: [
        Expanded(
          child: _countColumn(
            title: 'Horarios',
            total: schedules.length,
            active: scheduleActive,
            onTap: () => _openScheduleEditor(r),
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _countColumn(
            title: 'Fechas',
            total: blocks.length,
            active: dateActive,
            onTap: () => _openDateBlockEditor(r),
          ),
        ),
      ],
    );
  }

  Widget _countColumn({
    required String title,
    required int total,
    required int active,
    required VoidCallback onTap,
  }) {
    final hasActive = active > 0;
    final inactive = (total - active).clamp(0, total);
    final label = total <= 1 ? '$total' : '2+';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.surfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasActive
                        ? AppColors.success.withValues(alpha: 0.18)
                        : AppColors.surfaceVariant.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: hasActive
                          ? AppColors.success.withValues(alpha: 0.45)
                          : AppColors.surfaceVariant.withValues(alpha: 0.9),
                    ),
                  ),
                  child: Text(
                    'A:$active',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: hasActive
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: inactive > 0
                        ? AppColors.warning.withValues(alpha: 0.18)
                        : AppColors.surfaceVariant.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: inactive > 0
                          ? AppColors.warning.withValues(alpha: 0.45)
                          : AppColors.surfaceVariant.withValues(alpha: 0.9),
                    ),
                  ),
                  child: Text(
                    'I:$inactive',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: inactive > 0
                          ? AppColors.warning
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
      final timeText = formatTimeRange(
        s['startHour'] as int? ?? 0,
        s['startMinute'] as int? ?? 0,
        s['endHour'] as int? ?? 0,
        s['endMinute'] as int? ?? 0,
        dash: '-',
        nextDaySuffix: ' (día sig.)',
      );
      final dayText = formatDays(days, separator: '·');
      final enabled = s['isEnabled'] as bool? ?? true;
      final bgColor = enabled
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.error.withValues(alpha: 0.12);
      final borderColor = enabled
          ? AppColors.primary.withValues(alpha: 0.35)
          : AppColors.error.withValues(alpha: 0.35);

      return Padding(
        padding: EdgeInsets.only(left: 20, bottom: 6),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
            ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.background.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: Offset(0, 2),
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
                child: Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      timeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        dayText,
                        style: TextStyle(
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

  List<Widget> _dateBlockDetails(List<Map<String, dynamic>> blocks) {
    final active = blocks
        .where((b) => (b['isEnabled'] as bool? ?? true) == true)
        .toList();
    return active.map((b) {
      final start = b['startDate']?.toString() ?? '';
      final end = b['endDate']?.toString() ?? '';
      final label = b['label']?.toString();
      final rangeText = formatDateRangeLabel(start, end);
      final bgColor = AppColors.info.withValues(alpha: 0.12);
      final borderColor = AppColors.info.withValues(alpha: 0.35);

      return Padding(
        padding: EdgeInsets.only(left: 20, bottom: 6),
        child: Container(
          padding:
              EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.background.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  Icons.event_busy_rounded,
                  size: 12,
                  color: AppColors.info,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      rangeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: label?.isNotEmpty == true
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color:
                                        AppColors.info.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  label!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.info,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              'Bloqueo por fecha',
                              style: TextStyle(
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

  Widget _countBadge(int totalCount, int activeCount) {
    final hasActive = activeCount > 0;
    final label = totalCount <= 1 ? '$totalCount' : '2+';
    return Container(
      margin: EdgeInsets.only(right: 6),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: hasActive
            ? AppColors.success.withValues(alpha: 0.18)
            : AppColors.surfaceVariant.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: hasActive
              ? AppColors.success.withValues(alpha: 0.45)
              : AppColors.surfaceVariant.withValues(alpha: 0.9),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: hasActive ? AppColors.success : AppColors.textSecondary,
        ),
      ),
    );
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
    final pkg = r['packageName'] as String?;
    if (pkg != null && !_iconLoading.contains(pkg)) {
      _iconLoading.add(pkg);
      NativeService.getAppIcon(pkg).then((icon) {
        if (!mounted) return;
        if (icon != null && icon.isNotEmpty) {
          setState(() {
            r['iconBytes'] = icon;
          });
        }
      }).whenComplete(() => _iconLoading.remove(pkg));
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
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

  String _scheduleSummary(List<Map<String, dynamic>> schedules) {
    if (schedules.isEmpty) return 'Sin horarios';
    final first = schedules.first;
    final days = (first['daysOfWeek'] as List<dynamic>? ?? [])
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .where((d) => d >= 1 && d <= 7)
        .toList();
    final dayText = formatDays(days, separator: '·');
    final timeText = formatTimeRange(
      first['startHour'] as int? ?? 0,
      first['startMinute'] as int? ?? 0,
      first['endHour'] as int? ?? 0,
      first['endMinute'] as int? ?? 0,
      dash: '-',
      nextDaySuffix: ' (día sig.)',
    );
    if (schedules.length == 1) return '$dayText $timeText';
    return '$dayText $timeText  +${schedules.length - 1} más';
  }

  String _dateBlockSummary(List<Map<String, dynamic>> blocks) {
    if (blocks.isEmpty) return 'Sin fechas';
    final first = blocks.first;
    final start = first['startDate']?.toString() ?? '';
    final end = first['endDate']?.toString() ?? '';
    final range = formatDateRangeLabel(start, end);
    if (blocks.length == 1) return range;
    return '$range  +${blocks.length - 1} más';
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

  String _usageSummaryText(
      int usedMinutes,
      int usedMillis,
      int remainingMinutes,
      int remainingMillis,
      int quotaMinutes,
      String limitType,
      int weeklyResetDay,
      int weeklyResetHour,
      int weeklyResetMinute) {
    final used = AppUtils.formatUsageText(
      usedMinutes: usedMinutes,
      usedMillis: usedMillis,
      limitType: limitType,
      weeklyResetDay: weeklyResetDay,
      weeklyResetHour: weeklyResetHour,
      weeklyResetMinute: weeklyResetMinute,
    );
    final remaining = AppUtils.formatRemainingText(
      remainingMinutes: remainingMinutes,
      remainingMillis: remainingMillis,
      quotaMinutes: quotaMinutes,
      limitType: limitType,
      weeklyResetDay: weeklyResetDay,
      weeklyResetHour: weeklyResetHour,
      weeklyResetMinute: weeklyResetMinute,
    );
    return '$used · $remaining';
  }

  Widget _usageSummaryTextRich(
      int usedMinutes,
      int usedMillis,
      int remainingMinutes,
      int remainingMillis,
      int quotaMinutes,
      String limitType,
      int weeklyResetDay,
      int weeklyResetHour,
      int weeklyResetMinute,
      Color usedColor) {
    final used = AppUtils.formatUsageText(
      usedMinutes: usedMinutes,
      usedMillis: usedMillis,
      limitType: limitType,
      weeklyResetDay: weeklyResetDay,
      weeklyResetHour: weeklyResetHour,
      weeklyResetMinute: weeklyResetMinute,
    );
    final remaining = AppUtils.formatRemainingText(
      remainingMinutes: remainingMinutes,
      remainingMillis: remainingMillis,
      quotaMinutes: quotaMinutes,
      limitType: limitType,
      weeklyResetDay: weeklyResetDay,
      weeklyResetHour: weeklyResetHour,
      weeklyResetMinute: weeklyResetMinute,
    );
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
            TextSpan(
              text: ' · ',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
            TextSpan(
              text: remaining,
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
          ],
        ),
      );
    }
}

