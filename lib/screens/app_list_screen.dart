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
import 'package:timelock/screens/update_screen.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/app_utils.dart';
import 'package:timelock/utils/app_motion.dart';
import 'package:timelock/screens/app_picker_screen.dart';
import 'package:timelock/widgets/schedule_editor_dialog.dart';
import 'package:timelock/widgets/date_block_editor_dialog.dart';

class AppListScreen extends StatefulWidget {
  AppListScreen({super.key, this.initialRestrictions});

  final List<Map<String, dynamic>>? initialRestrictions;

  @override
  State<AppListScreen> createState() => _AppListScreenState();
}

class _AppListScreenState extends State<AppListScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _restrictions = [];
  bool _loading = true;
  bool _permissionsOk = false;
  bool? _lastPermissionsOk;
  bool _adminEnabled = false;
  int _adminLockUntilMs = 0;
  bool _accessVerified = false;
  Timer? _refreshTimer;
  final Set<String> _scheduleDirty = {};
  final Set<String> _dateBlockDirty = {};
  final Set<String> _iconLoading = {};
  int _iconPrefetchCount = 0;
  String _expiredAction = 'none';
  bool _expiredPrefsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensureAppAccess();
      _checkPermissions();
      _loadAdminLockPrefs();
      if (widget.initialRestrictions == null) {
        _loadRestrictions();
      }
    }
  }

  Future<void> _init() async {
    await _startMonitoring();
    await _checkPermissions();
    await _ensureAppAccess();
    await _loadExpiredPrefs();
    await _loadAdminLockPrefs();
    if (widget.initialRestrictions == null) {
      await _loadRestrictions();
    }
    _startAutoRefresh();
  }

  Future<void> _ensureAppAccess() async {
    if (_accessVerified || !mounted) return;
    final enabled = await NativeService.isAdminEnabled();
    if (!mounted) return;
    if (!enabled) {
      _accessVerified = true;
      return;
    }
    bool verified = false;
    while (mounted && !verified) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PinVerifyScreen(
            reason: 'Ingresa tu PIN para acceder a la app',
          ),
        ),
      );
      verified = result == true;
      if (!verified) {
        final stillEnabled = await NativeService.isAdminEnabled();
        if (!mounted || !stillEnabled) {
          verified = true;
        }
      }
    }
    if (mounted) {
      setState(() => _accessVerified = true);
    } else {
      _accessVerified = true;
    }
  }

  Future<void> _loadAdminLockPrefs() async {
    try {
      final prefs =
          await NativeService.getSharedPreferences('admin_lock_prefs');
      final until = (prefs?['lock_until_ms'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      setState(() => _adminLockUntilMs = until);
      await _clearAdminLockIfExpired();
    } catch (_) {}
  }

  bool get _adminLockActive =>
      _adminLockUntilMs > DateTime.now().millisecondsSinceEpoch;

  int get _adminLockRemainingMs {
    final remaining = _adminLockUntilMs - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? remaining : 0;
  }

  Future<void> _clearAdminLockIfExpired() async {
    if (_adminLockUntilMs <= 0) return;
    if (_adminLockActive) return;
    _adminLockUntilMs = 0;
    await NativeService.saveSharedPreference({
      'prefsName': 'admin_lock_prefs',
      'key': 'lock_until_ms',
      'value': null,
    });
    if (mounted) setState(() {});
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
      _checkPermissions();
      _loadRestrictions();
    });
  }

  void _notifyPermissionChange(bool nowOk) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          nowOk
              ? 'Permisos críticos habilitados'
              : 'Faltan permisos críticos para funcionar',
        ),
        action: nowOk
            ? null
            : SnackBarAction(
                label: 'Configurar',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PermissionsScreen()),
                ).then((_) => _checkPermissions()),
              ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<bool> _checkPermissions() async {
    try {
      final usage = await NativeService.checkUsagePermission();
      final acc = await NativeService.checkAccessibilityPermission();
      final admin = await NativeService.isAdminEnabled();
      final nowOk = usage && acc;
      if (mounted) {
        final prevOk = _lastPermissionsOk;
        setState(() {
          _permissionsOk = nowOk;
          _adminEnabled = admin;
          _lastPermissionsOk = nowOk;
        });
        if (prevOk != null && prevOk != nowOk) {
          _notifyPermissionChange(nowOk);
        }
      }
      return nowOk;
    } catch (_) {}
    return _permissionsOk;
  }

  Future<void> _startMonitoring() async {
    try {
      await NativeService.startMonitoring();
    } catch (_) {}
  }

  void _refreshWidgetsSoon() {
    unawaited(NativeService.refreshWidgetsNow());
  }

  void _reloadRestrictionsSoon() {
    unawaited(_loadRestrictions());
  }

  Future<void> _loadExpiredPrefs() async {
    if (_expiredPrefsLoaded) return;
    try {
      final prefs =
          await NativeService.getSharedPreferences('restriction_prefs');
      final action = prefs?['expired_action']?.toString();
      if (action != null &&
          (action == 'none' || action == 'archive' || action == 'delete')) {
        _expiredAction = action;
      }
    } catch (_) {}
    _expiredPrefsLoaded = true;
  }

  bool _isExpired(Map<String, dynamic> r) {
    final raw = r['expiresAt'];
    if (raw == null) return false;
    final expiresAt =
        raw is num ? raw.toInt() : int.tryParse(raw.toString()) ?? 0;
    if (expiresAt <= 0) return false;
    return DateTime.now().millisecondsSinceEpoch > expiresAt;
  }

  Future<void> _loadRestrictions() async {
    try {
      await _loadExpiredPrefs();
      final list = await NativeService.getRestrictions();
      final existingByPkg = {
        for (final r in _restrictions) r['packageName'] as String: r
      };
      final prefetchCount = _iconPrefetchCount == 0 ? 12 : _iconPrefetchCount;
      final prefetchSet = list
          .take(prefetchCount.clamp(0, list.length))
          .map((r) => r['packageName'] as String)
          .toSet();
      var changed = false;

      final filtered = <Map<String, dynamic>>[];
      final toDelete = <String>[];
      final restrictionPkgs = <String>{};
      for (final r in list) {
        final pkg = r['packageName'] as String;
        restrictionPkgs.add(pkg);
        final expired = _isExpired(r);
        r['isExpired'] = expired;
        if (expired && _expiredAction == 'delete') {
          toDelete.add(pkg);
          continue;
        }
        if (expired &&
            _expiredAction == 'archive' &&
            (r['isEnabled'] as bool? ?? true)) {
          try {
            await NativeService.updateRestriction({
              'packageName': pkg,
              'isEnabled': false,
            });
            r['isEnabled'] = false;
            changed = true;
          } catch (_) {}
        }
        final existing = existingByPkg[pkg];

        // Preserve cached fields to avoid rebuild flicker.
        if (existing != null) {
          r['iconBytes'] = existing['iconBytes'];
          r['scheduleCount'] = existing['scheduleCount'];
          r['scheduleActiveCount'] = existing['scheduleActiveCount'];
          r['dateBlockCount'] = existing['dateBlockCount'];
          r['dateBlockActiveCount'] = existing['dateBlockActiveCount'];
          r['usedMinutes'] = existing['usedMinutes'];
          r['isBlocked'] = existing['isBlocked'];
          r['usedMillis'] = existing['usedMillis'];
          r['usedMinutesWeek'] = existing['usedMinutesWeek'];
          r['isExpired'] = expired;
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

        if (r['scheduleCount'] == null || _scheduleDirty.contains(pkg)) {
          try {
            final schedules = await NativeService.getSchedules(pkg);
            final active = schedules
                .where((s) => (s['isEnabled'] as bool? ?? true))
                .length;
            r['scheduleCount'] = schedules.length;
            r['scheduleActiveCount'] = active;
            changed = true;
            _scheduleDirty.remove(pkg);
          } catch (_) {
            r['scheduleCount'] = 0;
            r['scheduleActiveCount'] = 0;
          }
        }

        if (r['dateBlockCount'] == null || _dateBlockDirty.contains(pkg)) {
          try {
            final blocks = await NativeService.getDateBlocks(pkg);
            final active =
                blocks.where((b) => (b['isEnabled'] as bool? ?? true)).length;
            r['dateBlockCount'] = blocks.length;
            r['dateBlockActiveCount'] = active;
            changed = true;
            _dateBlockDirty.remove(pkg);
          } catch (_) {
            r['dateBlockCount'] = 0;
            r['dateBlockActiveCount'] = 0;
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

        filtered.add(r);
      }

      // Add packages that only have direct blocks (schedules/date blocks).
      try {
        final directPkgs = await NativeService.getDirectBlockPackages();
        for (final pkg in directPkgs) {
          if (restrictionPkgs.contains(pkg)) continue;
          final name = await NativeService.getAppName(pkg) ?? pkg;
          final direct = {
            'packageName': pkg,
            'appName': name,
            'dailyQuotaMinutes': 0,
            'isEnabled': true,
            'limitType': 'none',
            'dailyMode': 'same',
            'dailyQuotas': '',
            'weeklyQuotaMinutes': 0,
            'weeklyResetDay': 2,
            'weeklyResetHour': 0,
            'weeklyResetMinute': 0,
            'isBlocked': false,
            'usedMinutes': 0,
            'usedMillis': 0,
            'usedMinutesWeek': 0,
            'scheduleCount': null,
            'scheduleActiveCount': null,
            'dateBlockCount': null,
            'dateBlockActiveCount': null,
            'isDirectOnly': true,
          };
          try {
            final schedules = await NativeService.getSchedules(pkg);
            final activeSchedules = schedules
                .where((s) => (s['isEnabled'] as bool? ?? true))
                .length;
            direct['scheduleCount'] = schedules.length;
            direct['scheduleActiveCount'] = activeSchedules;
          } catch (_) {}
          try {
            final blocks = await NativeService.getDateBlocks(pkg);
            final activeBlocks =
                blocks.where((b) => (b['isEnabled'] as bool? ?? true)).length;
            direct['dateBlockCount'] = blocks.length;
            direct['dateBlockActiveCount'] = activeBlocks;
          } catch (_) {}
          try {
            final usage = await NativeService.getUsageToday(pkg);
            direct['isBlocked'] = usage['isBlocked'] ?? false;
          } catch (_) {}
          filtered.add(direct);
          changed = true;
        }
      } catch (_) {}

      _sortRestrictions(filtered);

      for (final pkg in toDelete) {
        try {
          await NativeService.deleteRestriction(pkg);
          changed = true;
        } catch (_) {}
      }

      if (mounted) {
        if (changed || _loading || _restrictions.length != filtered.length) {
          setState(() {
            _restrictions = filtered;
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
        'expiresAt': limit?['expiresAt'],
      });
      final optimistic = <String, dynamic>{
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
        'expiresAt': limit?['expiresAt'],
        'usedMinutes': 0,
        'isBlocked': false,
        'usedMillis': 0,
        'usedMinutesWeek': 0,
        'scheduleCount': 0,
        'scheduleActiveCount': 0,
        'dateBlockCount': 0,
        'dateBlockActiveCount': 0,
      };
      if (mounted) {
        setState(() {
          _restrictions.removeWhere((x) => x['packageName'] == pkg);
          _restrictions.add(optimistic);
          _sortRestrictions(_restrictions);
        });
      }
      _refreshWidgetsSoon();
      _reloadRestrictionsSoon();
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  Future<bool> _requireAdmin(String reason) async {
    await _loadAdminLockPrefs();
    if (_adminLockActive) {
      if (mounted) {
        context.showSnack(
          'Modo admin temporal activo · '
          '${AppUtils.formatDurationMillis(_adminLockRemainingMs)}',
          isError: true,
        );
      }
      return false;
    }
    if (!_adminEnabled) return true;
    if (!mounted) return false;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PinVerifyScreen(reason: reason)),
    );
    return result == true;
  }

  Future<void> _deleteRestriction(Map<String, dynamic> r) async {
    final pkg = r['packageName']?.toString() ?? '';
    if (pkg.isEmpty) return;
    final previous = List<Map<String, dynamic>>.from(_restrictions);
    if (mounted) {
      setState(() {
        _restrictions.removeWhere((x) => x['packageName'] == pkg);
      });
    }
    _refreshWidgetsSoon();
    try {
      await NativeService.deleteRestriction(pkg);
      _reloadRestrictionsSoon();
    } catch (_) {
      if (mounted) {
        setState(() {
          _restrictions = previous;
        });
      }
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

    await _showBottomSheet(
      child: ScheduleEditorDialog(
        appName: r['appName'],
        packageName: r['packageName'],
      ),
    );
    _scheduleDirty.add(r['packageName'].toString());
    _refreshWidgetsSoon();
    _reloadRestrictionsSoon();
  }

  Future<void> _deleteDirectBlocks(Map<String, dynamic> r) async {
    final pkg = r['packageName']?.toString() ?? '';
    if (pkg.isEmpty) return;
    final previous = List<Map<String, dynamic>>.from(_restrictions);
    if (mounted) {
      setState(() {
        _restrictions.removeWhere((x) => x['packageName'] == pkg);
      });
    }
    _refreshWidgetsSoon();
    try {
      await NativeService.deleteDirectBlocks(pkg);
      _reloadRestrictionsSoon();
    } catch (_) {
      if (mounted) {
        setState(() {
          _restrictions = previous;
        });
      }
    }
  }

  Future<void> _openDateBlockEditor(Map<String, dynamic> r) async {
    final allowed = await _requireAdmin('Ingresa tu PIN para modificar fechas');
    if (!allowed || !mounted) return;

    await _showBottomSheet(
      child: DateBlockEditorDialog(
        appName: r['appName'],
        packageName: r['packageName'],
      ),
    );
    _dateBlockDirty.add(r['packageName'].toString());
    _refreshWidgetsSoon();
    _reloadRestrictionsSoon();
  }

  Future<void> _openDirectBlocksSelector(Map<String, dynamic> r) async {
    final scheduleCount = (r['scheduleCount'] as int?) ?? 0;
    final dateCount = (r['dateBlockCount'] as int?) ?? 0;
    if (scheduleCount > 0 && dateCount == 0) {
      return _openScheduleEditor(r);
    }
    if (dateCount > 0 && scheduleCount == 0) {
      return _openDateBlockEditor(r);
    }
    await _showBottomSheet(
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bloqueos directos',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openScheduleEditor(r);
                    },
                    icon: Icon(Icons.schedule_rounded, size: 16),
                    label: Text('Horarios'),
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openDateBlockEditor(r);
                    },
                    icon: Icon(Icons.event_busy_rounded, size: 16),
                    label: Text('Fechas'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showBottomSheet({required Widget child}) {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (!reduce) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => child,
      );
    }
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'sheet',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (context, _, __) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
    );
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
      final pkg = r['packageName']?.toString() ?? '';
      if (pkg.isNotEmpty && mounted) {
        setState(() {
          _restrictions.removeWhere((x) => x['packageName'] == pkg);
        });
      }
      _refreshWidgetsSoon();
      _reloadRestrictionsSoon();
      return;
    }
    if (limit['schedulesChanged'] == true) {
      _scheduleDirty.add(r['packageName'].toString());
    }
    if (limit['dateBlocksChanged'] == true) {
      _dateBlockDirty.add(r['packageName'].toString());
    }

    final previous = Map<String, dynamic>.from(r);
    final pkg = r['packageName']?.toString() ?? '';
    final next = {
      ...r,
      'dailyQuotaMinutes': limit['dailyQuotaMinutes'] ?? r['dailyQuotaMinutes'],
      'limitType': limit['limitType'] ?? r['limitType'],
      'dailyMode': limit['dailyMode'] ?? r['dailyMode'],
      'dailyQuotas': limit['dailyQuotas'] ?? r['dailyQuotas'],
      'weeklyQuotaMinutes':
          limit['weeklyQuotaMinutes'] ?? r['weeklyQuotaMinutes'],
      'weeklyResetDay': limit['weeklyResetDay'] ?? r['weeklyResetDay'],
      'weeklyResetHour': limit['weeklyResetHour'] ?? r['weeklyResetHour'],
      'weeklyResetMinute': limit['weeklyResetMinute'] ?? r['weeklyResetMinute'],
      'expiresAt':
          limit.containsKey('expiresAt') ? limit['expiresAt'] : r['expiresAt'],
    };
    if (mounted && pkg.isNotEmpty) {
      setState(() {
        final idx = _restrictions.indexWhere((x) => x['packageName'] == pkg);
        if (idx >= 0) {
          _restrictions[idx] = Map<String, dynamic>.from(next);
          _sortRestrictions(_restrictions);
        }
      });
    }
    try {
      await NativeService.updateRestriction({
        'packageName': pkg,
        'dailyQuotaMinutes': next['dailyQuotaMinutes'],
        'limitType': next['limitType'],
        'dailyMode': next['dailyMode'],
        'dailyQuotas': next['dailyQuotas'],
        'weeklyQuotaMinutes': next['weeklyQuotaMinutes'],
        'weeklyResetDay': next['weeklyResetDay'],
        'weeklyResetHour': next['weeklyResetHour'],
        'weeklyResetMinute': next['weeklyResetMinute'],
        'expiresAt': next['expiresAt'],
      });
      _refreshWidgetsSoon();
      _reloadRestrictionsSoon();
    } catch (_) {
      if (mounted && pkg.isNotEmpty) {
        setState(() {
          final idx = _restrictions.indexWhere((x) => x['packageName'] == pkg);
          if (idx >= 0) {
            _restrictions[idx] = previous;
            _sortRestrictions(_restrictions);
          }
        });
      }
      if (mounted) {
        context.showSnack('No se pudo guardar el cambio', isError: true);
      }
    }
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
                  separatorBuilder: (_, __) => SizedBox(height: AppSpacing.md),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding:
          EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TimeLock',
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
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
                        padding: EdgeInsets.fromLTRB(AppSpacing.lg,
                            AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
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
                                    builder: (_) => OptimizationScreen()),
                              );
                            },
                          ),
                          _settingsItem(
                            icon: Icons.system_update_alt_rounded,
                            title: 'Actualizaciones',
                            subtitle: 'Buscar nuevas versiones',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => UpdateScreen()),
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
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
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
    final expired = r['isExpired'] == true || _isExpired(r);
    final blocked = !expired && (r['isBlocked'] as bool);
    final directOnly = _isDirectOnlyCard(r);
    final progress = _progressFor(r);
    final limitType = (r['limitType'] ?? 'daily').toString();
    final quota = _quotaMinutesFor(r);
    final usedMinutes = limitType == 'weekly'
        ? (r['usedMinutesWeek'] as int? ?? 0)
        : (r['usedMinutes'] as int);
    final usedMillis = limitType == 'weekly'
        ? usedMinutes * 60000
        : (r['usedMillis'] as num?)?.toInt() ?? usedMinutes * 60000;
    final remainingMillis =
        (quota * 60000 - usedMillis).clamp(0, quota * 60000);
    final remainingMinutes = (quota - usedMinutes).clamp(0, quota);

    final progressColor = blocked
        ? AppColors.error
        : progress > 0.75
            ? AppColors.warning
            : AppColors.success;

    return Dismissible(
      key: ValueKey(r['packageName']),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _requireAdmin(
        directOnly
            ? 'Ingresa tu PIN para eliminar estos bloqueos'
            : 'Ingresa tu PIN para eliminar esta restricción',
      ),
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
      onDismissed: (_) {
        if (directOnly) {
          _deleteDirectBlocks(r);
        } else {
          _deleteRestriction(r);
        }
      },
      child: Card(
        child: InkWell(
          onTap: () {
            if (directOnly) {
              _openDirectBlocksSelector(r);
            } else {
              _openLimitEditor(r);
            }
          },
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
                    if (blocked || expired)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        alignment: WrapAlignment.end,
                        children: [
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
                              child: Text(
                                'BLOQUEADA',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          if (expired)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.warning.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'VENCIDA',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warning,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                if (!directOnly) ...[
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
                ] else ...[
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Solo bloqueo por horario/fecha',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Divider(height: 1),
                  SizedBox(height: AppSpacing.xs),
                  _directBlocksRow(r),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _directBlocksRow(Map<String, dynamic> r) {
    final scheduleCount = (r['scheduleCount'] as int?) ?? 0;
    final scheduleActive = (r['scheduleActiveCount'] as int?) ?? 0;
    final dateCount = (r['dateBlockCount'] as int?) ?? 0;
    final dateActive = (r['dateBlockActiveCount'] as int?) ?? 0;
    if (scheduleCount == 0 && dateCount == 0) {
      return SizedBox.shrink();
    }

    final columns = <Widget>[];
    if (scheduleCount > 0) {
      columns.add(
        Expanded(
          child: _countColumn(
            title: 'Horarios',
            total: scheduleCount,
            active: scheduleActive,
            onTap: () => _openScheduleEditor(r),
          ),
        ),
      );
    }
    if (dateCount > 0) {
      if (columns.isNotEmpty) {
        columns.add(SizedBox(width: AppSpacing.sm));
      }
      columns.add(
        Expanded(
          child: _countColumn(
            title: 'Fechas',
            total: dateCount,
            active: dateActive,
            onTap: () => _openDateBlockEditor(r),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 280 && columns.length > 1) {
          return Column(
            children: [
              columns[0],
              SizedBox(height: AppSpacing.sm),
              columns[2],
            ],
          );
        }
        return Row(children: columns);
      },
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
            if (total > 0)
              Wrap(
                spacing: 6,
                runSpacing: 4,
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
                  if (inactive > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        'I:$inactive',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
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

  int _quotaMinutesFor(Map<String, dynamic> r) {
    final limitType = (r['limitType'] ?? 'daily').toString();
    if (limitType == 'none') return 0;
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

  bool _isDirectOnlyCard(Map<String, dynamic> r) {
    final scheduleCount = (r['scheduleCount'] as int?) ?? 0;
    final dateCount = (r['dateBlockCount'] as int?) ?? 0;
    final quota = _quotaMinutesFor(r);
    return quota <= 0 && (scheduleCount > 0 || dateCount > 0);
  }

  void _sortRestrictions(List<Map<String, dynamic>> list) {
    int typeRank(Map<String, dynamic> r) {
      final scheduleCount = (r['scheduleCount'] as int?) ?? 0;
      final dateCount = (r['dateBlockCount'] as int?) ?? 0;
      final quota = _quotaMinutesFor(r);
      if (quota > 0) return 0; // tiempo
      if (scheduleCount > 0 && dateCount == 0) return 1; // horario
      if (dateCount > 0 && scheduleCount == 0) return 2; // fecha
      if (scheduleCount > 0 && dateCount > 0) return 3; // mixto
      return 4;
    }

    list.sort((a, b) {
      final ra = typeRank(a);
      final rb = typeRank(b);
      if (ra != rb) return ra.compareTo(rb);
      final nameA = (a['appName'] ?? '').toString().toLowerCase();
      final nameB = (b['appName'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });
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
