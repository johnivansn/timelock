import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timelock/screens/permissions_screen.dart';
import 'package:timelock/screens/pin_verify_screen.dart';
import 'package:timelock/screens/notification_settings_screen.dart';
import 'package:timelock/screens/profile_screen.dart';
import 'package:timelock/widgets/app_picker_dialog.dart';
import 'package:timelock/widgets/time_picker_dialog.dart';
import 'package:timelock/widgets/wifi_picker_dialog.dart';
import 'package:timelock/screens/export_import_screen.dart';
import 'package:timelock/screens/backup_screen.dart';
import 'package:timelock/screens/activity_log_screen.dart';
import 'package:timelock/widgets/first_launch_dialog.dart';

class AppListScreen extends StatefulWidget {
  const AppListScreen({super.key});

  @override
  State<AppListScreen> createState() => _AppListScreenState();
}

class _AppListScreenState extends State<AppListScreen>
    with TickerProviderStateMixin {
  static const _ch = MethodChannel('app.restriction/config');

  List<Map<String, dynamic>> _restrictions = [];
  List<Map<String, dynamic>> _profiles = [];
  bool _loading = true;
  bool _permissionsOk = false;
  bool _adminEnabled = false;
  String? _activeProfileId;
  String _activeProfileName = 'Default';
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();
    _init();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _startMonitoring();
    await _checkPermissions();
    await _loadProfiles();
    await _loadRestrictions();
    if (mounted) {
      await FirstLaunchDialog.checkAndShow(context);
    }
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

  Future<void> _loadProfiles() async {
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('getProfiles') ?? [];
      final profiles = raw.map((e) => Map<String, dynamic>.from(e)).toList();
      final activeId =
          await _ch.invokeMethod<String>('getActiveProfileId') ?? 'default';
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _activeProfileId = activeId;
          _activeProfileName = profiles.firstWhere(
            (p) => p['id'] == activeId,
            orElse: () => {'name': 'Default'},
          )['name'] as String;
        });
      }
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

  Future<void> _refreshAll() async {
    await _loadProfiles();
    await _loadRestrictions();
  }

  Future<void> _addRestriction(String pkg, String name, int minutes) async {
    try {
      await _ch.invokeMethod('addRestriction', {
        'packageName': pkg,
        'appName': name,
        'dailyQuotaMinutes': minutes,
        'isEnabled': true,
        'blockedWifiSSIDs': [],
        'profileId': _activeProfileId ?? 'default',
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
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PinVerifyScreen(reason: reason),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    return result == true;
  }

  Future<void> _deleteRestriction(Map<String, dynamic> r) async {
    try {
      await _ch.invokeMethod('deleteRestriction', {
        'packageName': r['packageName'],
        'profileId': r['profileId'] ?? _activeProfileId ?? 'default',
      });
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
        profileId: r['profileId'] ?? _activeProfileId ?? 'default',
      ),
    );
    if (result != null) {
      await _loadRestrictions();
    }
  }

  Future<void> _switchProfile(Map<String, dynamic> profile) async {
    try {
      await _ch.invokeMethod('setActiveProfile', profile['id']);
      if (mounted) {
        setState(() {
          _activeProfileId = profile['id'];
          _activeProfileName = profile['name'] as String;
        });
        await _loadRestrictions();
      }
    } catch (_) {
      if (mounted) _showSnack('Error al cambiar perfil', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
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

    final minutes = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            pinned: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'AppTimeControl',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () => _showMenu(context),
                tooltip: 'Menú',
              ),
              const SizedBox(width: 8),
            ],
          ),
          if (!_permissionsOk)
            SliverToBoxAdapter(child: _permissionsBanner(colorScheme)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: _profileSelector(colorScheme),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_restrictions.isEmpty)
            SliverFillRemaining(child: _emptyState(colorScheme))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              sliver: SliverList.separated(
                itemCount: _restrictions.length,
                itemBuilder: (_, i) =>
                    _restrictionCard(_restrictions[i], colorScheme),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
              ),
            ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(parent: _fabController, curve: Curves.easeOut),
        child: FloatingActionButton.extended(
          onPressed: _openAddFlow,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Agregar'),
        ),
      ),
    );
  }

  Widget _profileSelector(ColorScheme colorScheme) {
    if (_profiles.length <= 1) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._profiles.map((p) {
            final isActive = p['id'] == _activeProfileId;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _switchProfile(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(Icons.check_rounded,
                              size: 16, color: colorScheme.onPrimary),
                        ),
                      Text(
                        p['name'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ).then((_) => _refreshAll()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.add_rounded,
                  size: 18, color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.layers_rounded),
              title: const Text('Perfiles'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ).then((_) => _refreshAll());
              },
            ),
            ListTile(
              leading: const Icon(Icons.security_rounded),
              title: const Text('Permisos'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PermissionsScreen()),
                ).then((_) => _checkPermissions());
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_rounded),
              title: const Text('Notificaciones'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('Historial de actividad'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ActivityLogScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.backup_rounded),
              title: const Text('Backups'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BackupScreen()),
                ).then((_) => _loadRestrictions());
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync_rounded),
              title: const Text('Export / Import'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExportImportScreen()),
                ).then((_) => _loadRestrictions());
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _permissionsBanner(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF39C12).withValues(alpha: 0.1),
        border: Border.all(color: const Color(0xFFF39C12)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF39C12)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Faltan permisos necesarios',
              style: TextStyle(
                  color: Color(0xFFF39C12), fontWeight: FontWeight.w500),
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

  Widget _emptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_rounded,
                size: 80, color: colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 24),
            Text(
              'Sin restricciones',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            Text(
              'Toca el botón para agregar\nuna aplicación con límite de tiempo',
              style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Perfil activo: $_activeProfileName',
              style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _restrictionCard(Map<String, dynamic> r, ColorScheme colorScheme) {
    final blocked = r['isBlocked'] as bool;
    final progress = _progressFor(r);
    final used = r['usedMinutes'] as int;
    final quota = r['dailyQuotaMinutes'] as int;
    final remaining = (quota - used).clamp(0, quota);

    final progressColor = blocked
        ? colorScheme.error
        : progress > 0.75
            ? const Color(0xFFF39C12)
            : colorScheme.secondary;

    return Dismissible(
      key: ValueKey('${r['packageName']}_${r['profileId']}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) =>
          _requireAdmin('Ingresa tu PIN para eliminar esta restricción'),
      background: Container(
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 24),
            child: Icon(Icons.delete_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
      onDismissed: (_) => _deleteRestriction(r),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: blocked
                  ? Border.all(color: colorScheme.error, width: 1.5)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r['appName'],
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (blocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'BLOQUEADA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.error,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    tween: Tween(begin: 0.0, end: progress),
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_timeLabel(used)} usados',
                      style: TextStyle(
                          fontSize: 13, color: colorScheme.onSurfaceVariant),
                    ),
                    Text(
                      blocked
                          ? 'Se abre a medianoche'
                          : '${_timeLabel(remaining)} restantes',
                      style: TextStyle(
                        fontSize: 13,
                        color: blocked
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                        fontWeight:
                            blocked ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: colorScheme.surfaceContainerHighest),
                const SizedBox(height: 12),
                _wifiRow(r, colorScheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _wifiRow(Map<String, dynamic> r, ColorScheme colorScheme) {
    final ssids = (r['blockedWifiSSIDs'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return Row(
      children: [
        Icon(Icons.wifi_rounded,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: ssids.isEmpty
              ? Text(
                  'Sin redes bloqueadas',
                  style: TextStyle(
                      fontSize: 13,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ssids
                      .map((ssid) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              ssid,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ))
                      .toList(),
                ),
        ),
        const SizedBox(width: 8),
        Material(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _openWifiPicker(r),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.settings_rounded,
                  color: colorScheme.onSurfaceVariant, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}
