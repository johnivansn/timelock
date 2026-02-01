import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timelock/screens/permissions_screen.dart';
import 'package:timelock/screens/pin_verify_screen.dart';
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

    final result = await showDialog<List<String>>(
      context: context,
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
        backgroundColor:
            isError ? const Color(0xFFE74C3C) : const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _openAddFlow() async {
    final existing =
        _restrictions.map((r) => r['packageName'] as String).toSet();

    if (!mounted) return;
    final app = await showDialog<Map<String, String>>(
      context: context,
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
          _buildSliver(),
          if (!_permissionsOk) SliverToBoxAdapter(child: _permissionsBanner()),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_restrictions.isEmpty)
            SliverFillRemaining(child: _emptyState())
          else
            SliverList.separated(
              itemCount: _restrictions.length,
              itemBuilder: (_, i) => _restrictionCard(_restrictions[i]),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddFlow,
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        elevation: 0,
        child: const Icon(Icons.add, size: 24),
      ),
    );
  }

  SliverAppBar _buildSliver() {
    return SliverAppBar(
      expandedHeight: 100,
      pinned: true,
      backgroundColor: const Color(0xFF0F0F1A),
      flexibleSpace: const FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          'AppTimeControl',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined,
              color: Colors.white70, size: 22),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PermissionsScreen()),
          ).then((_) => _checkPermissions()),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _permissionsBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1B00),
        border: Border.all(color: const Color(0xFFF39C12), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Color(0xFFF39C12), size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Faltan permisos necesarios',
              style: TextStyle(
                  color: Color(0xFFF39C12),
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PermissionsScreen()),
            ).then((_) => _checkPermissions()),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text('Configurar',
                style: TextStyle(color: Color(0xFFF39C12), fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 64, color: Color(0xFF6C5CE7)),
            SizedBox(height: 24),
            Text(
              'Sin restricciones',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
            SizedBox(height: 8),
            Text(
              'Toca el botón + para agregar\nuna aplicación con límite de tiempo',
              style:
                  TextStyle(fontSize: 14, color: Colors.white38, height: 1.5),
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
        ? const Color(0xFFE74C3C)
        : progress > 0.75
            ? const Color(0xFFF39C12)
            : const Color(0xFF27AE60);

    return Dismissible(
      key: ValueKey(r['packageName']),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) =>
          _requireAdmin('Ingresa tu PIN para eliminar esta restricción'),
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFE74C3C),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 20),
            child: Icon(Icons.delete_outline, color: Colors.white, size: 24),
          ),
        ),
      ),
      onDismissed: (_) => _deleteRestriction(r),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: blocked
              ? Border.all(color: const Color(0xFFE74C3C), width: 1)
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (blocked)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0x33E74C3C),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'BLOQUEADA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE74C3C),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF2A2A3E),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_timeLabel(used)} usados',
                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                ),
                Text(
                  blocked
                      ? 'Se abre a medianoche'
                      : '${_timeLabel(remaining)} restantes',
                  style: TextStyle(
                      fontSize: 12,
                      color:
                          blocked ? const Color(0xFFE74C3C) : Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2A2A3E), height: 1),
            const SizedBox(height: 10),
            _wifiRow(r),
          ],
        ),
      ),
    );
  }

  Widget _wifiRow(Map<String, dynamic> r) {
    final ssids = (r['blockedWifiSSIDs'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return Row(
      children: [
        const Icon(Icons.wifi_outlined, color: Colors.white24, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: ssids.isEmpty
              ? const Text(
                  'Sin redes bloqueadas',
                  style: TextStyle(fontSize: 12, color: Colors.white24),
                )
              : Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: ssids
                      .map((ssid) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0x1A6C5CE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              ssid,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6C5CE7),
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ))
                      .toList(),
                ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _openWifiPicker(r),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.settings_outlined,
                color: Colors.white38, size: 16),
          ),
        ),
      ],
    );
  }
}
