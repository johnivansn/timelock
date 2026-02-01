import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timelock/screens/export_import_screen.dart';
import 'package:timelock/screens/notification_settings_screen.dart';
import 'package:timelock/screens/optimization_screen.dart';
import 'package:timelock/screens/permissions_screen.dart';
import 'package:timelock/screens/pin_verify_screen.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/widgets/app_picker_dialog.dart';
import 'package:timelock/widgets/time_picker_dialog.dart';
import 'package:timelock/widgets/wifi_picker_dialog.dart';

class AppListScreen extends StatefulWidget {
  const AppListScreen({super.key});

  @override
  State<AppListScreen> createState() => _AppListScreenState();
}

class _AppListScreenState extends State<AppListScreen> {
  static const _ch = MethodChannel('app.restriction/config');

  List<Map<String, dynamic>> _restrictions = [];
  bool _loading = true;
  bool _permissionsOk = false;
  bool _adminEnabled = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _startMonitoring();
    await _checkPermissions();
    await _loadRestrictions();
  }

  Future<void> _checkPermissions() async {
    try {
      final usage =
          await _ch.invokeMethod<bool>('checkUsagePermission') ?? false;
      final acc =
          await _ch.invokeMethod<bool>('checkAccessibilityPermission') ?? false;
      final admin = await _ch.invokeMethod<bool>('isAdminEnabled') ?? false;
      if (mounted) {
        setState(() {
          _permissionsOk = usage && acc;
          _adminEnabled = admin;
        });
      }
    } catch (_) {}
  }

  Future<void> _startMonitoring() async {
    try {
      await _ch.invokeMethod('startMonitoring');
    } catch (_) {}
  }

  Future<void> _loadRestrictions() async {
    try {
      final raw =
          await _ch.invokeMethod<List<dynamic>>('getRestrictions') ?? [];
      final list = raw.map((e) => Map<String, dynamic>.from(e)).toList();

      for (final r in list) {
        try {
          final usage = await _ch.invokeMethod<Map<dynamic, dynamic>>(
            'getUsageToday',
            r['packageName'],
          );
          r['usedMinutes'] = usage?['usedMinutes'] ?? 0;
          r['isBlocked'] = usage?['isBlocked'] ?? false;
        } catch (_) {
          r['usedMinutes'] = 0;
          r['isBlocked'] = false;
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
      await _ch.invokeMethod('addRestriction', {
        'packageName': pkg,
        'appName': name,
        'dailyQuotaMinutes': minutes,
        'isEnabled': true,
        'blockedWifiSSIDs': [],
      });
      await _loadRestrictions();
    } catch (e) {
      _showSnack('Error: $e', isError: true);
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
      await _ch.invokeMethod('deleteRestriction', r['packageName']);
      await _loadRestrictions();
    } catch (_) {
      _restrictions.removeWhere((x) => x['packageName'] == r['packageName']);
      if (mounted) setState(() {});
    }
  }

  Future<void> _openWifiPicker(Map<String, dynamic> r) async {
    final allowed =
        await _requireAdmin('Ingresa tu PIN para modificar bloqueos por WiFi');
    if (!allowed || !mounted) return;

    final current = (r['blockedWifiSSIDs'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WifiPickerDialog(
        appName: r['appName'],
        packageName: r['packageName'],
        currentSSIDs: current,
      ),
    );
    if (result != null) {
      await _loadRestrictions();
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppSpacing.md),
      ),
    );
  }

  void _openAddFlow() async {
    final existing =
        _restrictions.map((r) => r['packageName'] as String).toSet();

    if (!mounted) return;
    final app = await showModalBottomSheet<Map<String, String>>(
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

    await _addRestriction(app['packageName']!, app['appName']!, minutes);
  }

  double _progressFor(Map<String, dynamic> r) {
    final used = (r['usedMinutes'] as int).toDouble();
    final quota = (r['dailyQuotaMinutes'] as int).toDouble();
    return (used / quota).clamp(0.0, 1.0);
  }

  String _timeLabel(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    }
    return '${minutes}m';
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
    final remaining = (quota - used).clamp(0, quota);

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
                      '${_timeLabel(used)} usados',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    Text(
                      blocked
                          ? 'Se abre a medianoche'
                          : '${_timeLabel(remaining)} restantes',
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
                _wifiRow(r),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _wifiRow(Map<String, dynamic> r) {
    final ssids = (r['blockedWifiSSIDs'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          const Icon(Icons.wifi_outlined,
              color: AppColors.textTertiary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ssids.isEmpty
                ? const Text(
                    'Sin redes bloqueadas',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textTertiary),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: ssids
                          .map((ssid) => Padding(
                                padding:
                                    const EdgeInsets.only(right: AppSpacing.xs),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    ssid,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: () => _openWifiPicker(r),
            icon: const Icon(Icons.settings_outlined, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceVariant,
              padding: const EdgeInsets.all(AppSpacing.sm),
            ),
          ),
        ],
      ),
    );
  }
}
