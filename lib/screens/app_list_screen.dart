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

class AppListScreen extends StatefulWidget {
  const AppListScreen({super.key, this.initialRestrictions});

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
  final Map<String, Uint8List> _iconCache = {};
  int _iconPrefetchCount = 0;
  String _sortMode = 'smart';
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
    final navigator = Navigator.of(context);
    final enabled = await NativeService.isAdminEnabled();
    if (!mounted) return;
    if (!enabled) {
      _accessVerified = true;
      return;
    }
    bool verified = false;
    while (mounted && !verified) {
      final result = await navigator.push<bool>(
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
    if (!mounted) return;
    final width = MediaQuery.sizeOf(context).width;
    final memoryClass = await NativeService.getMemoryClass();
    final powerSave = await NativeService.isBatterySaverEnabled();
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
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
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
        duration: const Duration(seconds: 3),
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

        final cachedIcon = _iconCache[pkg];
        if (cachedIcon != null && cachedIcon.isNotEmpty) {
          r['iconBytes'] = cachedIcon;
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
            final prevCount = (r['scheduleCount'] as int?) ?? 0;
            final prevActive = (r['scheduleActiveCount'] as int?) ?? 0;
            final schedules = await NativeService.getSchedules(pkg);
            final active = schedules
                .where((s) => (s['isEnabled'] as bool? ?? true))
                .length;
            r['scheduleCount'] = schedules.length;
            r['scheduleActiveCount'] = active;
            if (prevCount != schedules.length || prevActive != active) {
              changed = true;
            }
            _scheduleDirty.remove(pkg);
          } catch (_) {
            r['scheduleCount'] = 0;
            r['scheduleActiveCount'] = 0;
          }
        }

        if (r['dateBlockCount'] == null || _dateBlockDirty.contains(pkg)) {
          try {
            final prevCount = (r['dateBlockCount'] as int?) ?? 0;
            final prevActive = (r['dateBlockActiveCount'] as int?) ?? 0;
            final blocks = await NativeService.getDateBlocks(pkg);
            final active =
                blocks.where((b) => (b['isEnabled'] as bool? ?? true)).length;
            r['dateBlockCount'] = blocks.length;
            r['dateBlockActiveCount'] = active;
            if (prevCount != blocks.length || prevActive != active) {
              changed = true;
            }
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
              _iconCache[pkg] = bytes;
              r['iconBytes'] = bytes;
              changed = true;
            }
          } catch (_) {}
        }

        if (existing != null && _sameCardData(existing, r)) {
          filtered.add(existing);
        } else {
          filtered.add(r);
        }
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
          final existingDirect = existingByPkg[pkg];
          if (existingDirect != null && _sameCardData(existingDirect, direct)) {
            filtered.add(existingDirect);
          } else {
            filtered.add(direct);
            changed = true;
          }
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

    await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => RestrictionEditScreen(
          appName: r['appName'],
          packageName: r['packageName'],
          initial: r,
          initialSection: 'direct',
          initialDirectTab: 'schedule',
        ),
      ),
    );
    _scheduleDirty.add(r['packageName'].toString());
    _dateBlockDirty.add(r['packageName'].toString());
    _refreshWidgetsSoon();
    _reloadRestrictionsSoon();
  }

  Future<void> _openDateBlockEditor(Map<String, dynamic> r) async {
    final allowed = await _requireAdmin('Ingresa tu PIN para modificar fechas');
    if (!allowed || !mounted) return;

    await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => RestrictionEditScreen(
          appName: r['appName'],
          packageName: r['packageName'],
          initial: r,
          initialSection: 'direct',
          initialDirectTab: 'date',
        ),
      ),
    );
    _scheduleDirty.add(r['packageName'].toString());
    _dateBlockDirty.add(r['packageName'].toString());
    _refreshWidgetsSoon();
    _reloadRestrictionsSoon();
  }

  Future<void> _openDirectBlocksSelector(Map<String, dynamic> r) async {
    final scheduleCount = (r['scheduleCount'] as int?) ?? 0;
    final dateCount = (r['dateBlockCount'] as int?) ?? 0;
    final allowed =
        await _requireAdmin('Ingresa tu PIN para modificar bloqueos directos');
    if (!allowed || !mounted) return;
    final initialDirectTab =
        (dateCount > scheduleCount && dateCount > 0) ? 'date' : 'schedule';
    await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => RestrictionEditScreen(
          appName: r['appName'],
          packageName: r['packageName'],
          initial: r,
          initialSection: 'direct',
          initialDirectTab: initialDirectTab,
        ),
      ),
    );
    _scheduleDirty.add(r['packageName'].toString());
    _dateBlockDirty.add(r['packageName'].toString());
    _refreshWidgetsSoon();
    _reloadRestrictionsSoon();
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
                  itemBuilder: (_, i) => RepaintBoundary(
                      child: _restrictionCard(_restrictions[i])),
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
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    final sortLabel = _sortLabel(_sortMode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
            const SizedBox(width: AppSpacing.xs),
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
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.surfaceVariant.withValues(alpha: 0.72),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.sort_rounded,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Orden actual: $sortLabel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openSortOptions,
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Cambiar'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _quickSortChip('smart'),
                    const SizedBox(width: AppSpacing.xs),
                    _quickSortChip('ending_soon'),
                    const SizedBox(width: AppSpacing.xs),
                    _quickSortChip('blocked_first'),
                    const SizedBox(width: AppSpacing.xs),
                    _quickSortChip('usage_high'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickSortChip(String mode) {
    final selected = _sortMode == mode;
    return ChoiceChip(
      label: Text(_sortLabel(mode)),
      selected: selected,
      onSelected: (_) => _setSortMode(mode),
      selectedColor: AppColors.primary.withValues(alpha: 0.16),
      backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.36),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.45)
            : AppColors.surfaceVariant.withValues(alpha: 0.7),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  void _setSortMode(String mode) {
    if (_sortMode == mode) return;
    setState(() {
      _sortMode = mode;
      _sortRestrictions(_restrictions);
    });
  }

  String _sortLabel(String mode) {
    switch (mode) {
      case 'name_asc':
        return 'Nombre A-Z';
      case 'name_desc':
        return 'Nombre Z-A';
      case 'usage_high':
        return 'Uso alto';
      case 'usage_low':
        return 'Uso bajo';
      case 'active_first':
        return 'Activas primero';
      case 'blocked_first':
        return 'Bloqueadas primero';
      case 'ending_soon':
        return 'Por terminar';
      case 'starting_soon':
        return 'Por empezar';
      case 'dates_first':
        return 'Fechas primero';
      case 'schedules_first':
        return 'Horarios primero';
      default:
        return 'Inteligente';
    }
  }

  String _sortDescription(String mode) {
    switch (mode) {
      case 'name_asc':
        return 'Orden alfabético ascendente';
      case 'name_desc':
        return 'Orden alfabético descendente';
      case 'usage_high':
        return 'Apps con mayor consumo al inicio';
      case 'usage_low':
        return 'Apps con menor consumo al inicio';
      case 'active_first':
        return 'Prioriza las activas ahora';
      case 'blocked_first':
        return 'Muestra bloqueadas al principio';
      case 'ending_soon':
        return 'Prioriza cuotas próximas a agotarse';
      case 'starting_soon':
        return 'Prioriza bloqueos directos pendientes';
      case 'dates_first':
        return 'Prioriza restricciones por fecha';
      case 'schedules_first':
        return 'Prioriza restricciones por horario';
      default:
        return 'Balancea estado, riesgo y tipo';
    }
  }

  IconData _sortIcon(String mode) {
    switch (mode) {
      case 'name_asc':
      case 'name_desc':
        return Icons.sort_by_alpha_rounded;
      case 'usage_high':
      case 'usage_low':
        return Icons.hourglass_top_rounded;
      case 'active_first':
        return Icons.play_circle_fill_rounded;
      case 'blocked_first':
        return Icons.block_rounded;
      case 'ending_soon':
        return Icons.timer_rounded;
      case 'starting_soon':
        return Icons.schedule_rounded;
      case 'dates_first':
        return Icons.event_rounded;
      case 'schedules_first':
        return Icons.access_time_filled_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  Future<void> _openSortOptions() async {
    const modes = [
      'smart',
      'active_first',
      'blocked_first',
      'ending_soon',
      'starting_soon',
      'usage_high',
      'usage_low',
      'dates_first',
      'schedules_first',
      'name_asc',
      'name_desc',
    ];
    await _showBottomSheet(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(
            top: BorderSide(
                color: AppColors.surfaceVariant.withValues(alpha: .8)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ordenar lista',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                  itemCount: modes.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (_, i) {
                    final mode = modes[i];
                    final selected = _sortMode == mode;
                    return InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () {
                        _setSortMode(mode);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.surfaceVariant
                                  .withValues(alpha: 0.25),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.45)
                                : AppColors.surfaceVariant
                                    .withValues(alpha: 0.65),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _sortIcon(mode),
                              size: 18,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _sortLabel(mode),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: selected
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _sortDescription(mode),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              Icon(Icons.check_circle_rounded,
                                  size: 18, color: AppColors.primary),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
      transitionDuration: AppMotion.duration(const Duration(milliseconds: 260)),
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
                      const BorderRadius.horizontal(left: Radius.circular(28)),
                  border: Border.all(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.background.withValues(alpha: 0.55),
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
                            icon: const Icon(Icons.close_rounded),
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
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
                                    builder: (_) => const AppearanceScreen()),
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
                                    builder: (_) => const UpdateScreen()),
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
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
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.35), width: 1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
          const SizedBox(width: AppSpacing.sm),
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
              child: Icon(
                Icons.shield_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sin restricciones',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
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

    return Card(
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
          padding: const EdgeInsets.all(AppSpacing.md),
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
                  const SizedBox(width: AppSpacing.sm),
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
                            padding: const EdgeInsets.symmetric(
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.18),
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
                  (r['weeklyResetDay'] as int?) ?? 2,
                  (r['weeklyResetHour'] as int?) ?? 0,
                  (r['weeklyResetMinute'] as int?) ?? 0,
                  progressColor,
                ),
                const SizedBox(height: AppSpacing.xs),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.xs),
                _directBlocksRow(r),
              ] else ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Solo bloqueo por horario/fecha',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.xs),
                _directBlocksRow(r),
              ],
            ],
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
      return const SizedBox.shrink();
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
        columns.add(const SizedBox(width: AppSpacing.sm));
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
              const SizedBox(height: AppSpacing.sm),
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
        padding: const EdgeInsets.symmetric(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
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
    final pkg = r['packageName'] as String?;
    final cached = pkg != null ? _iconCache[pkg] : null;
    final bytes = cached ?? r['iconBytes'];
    if (bytes is Uint8List && bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    if (pkg != null && !_iconLoading.contains(pkg)) {
      _iconLoading.add(pkg);
      NativeService.getAppIcon(pkg).then((icon) {
        if (!mounted) return;
        if (icon != null && icon.isNotEmpty) {
          setState(() {
            _iconCache[pkg] = icon;
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

  bool _sameCardData(Map<String, dynamic> a, Map<String, dynamic> b) {
    int toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    bool toBool(dynamic v) => v == true;

    return (a['packageName'] ?? '') == (b['packageName'] ?? '') &&
        (a['appName'] ?? '') == (b['appName'] ?? '') &&
        toInt(a['dailyQuotaMinutes']) == toInt(b['dailyQuotaMinutes']) &&
        toInt(a['weeklyQuotaMinutes']) == toInt(b['weeklyQuotaMinutes']) &&
        (a['limitType'] ?? 'daily') == (b['limitType'] ?? 'daily') &&
        (a['dailyMode'] ?? 'same') == (b['dailyMode'] ?? 'same') &&
        '${a['dailyQuotas'] ?? ''}' == '${b['dailyQuotas'] ?? ''}' &&
        toInt(a['scheduleCount']) == toInt(b['scheduleCount']) &&
        toInt(a['scheduleActiveCount']) == toInt(b['scheduleActiveCount']) &&
        toInt(a['dateBlockCount']) == toInt(b['dateBlockCount']) &&
        toInt(a['dateBlockActiveCount']) == toInt(b['dateBlockActiveCount']) &&
        toInt(a['usedMinutes']) == toInt(b['usedMinutes']) &&
        toInt(a['usedMillis']) == toInt(b['usedMillis']) &&
        toInt(a['usedMinutesWeek']) == toInt(b['usedMinutesWeek']) &&
        toBool(a['isEnabled']) == toBool(b['isEnabled']) &&
        toBool(a['isBlocked']) == toBool(b['isBlocked']) &&
        toBool(a['isExpired']) == toBool(b['isExpired']) &&
        (a['expiresAt']?.toString() ?? '') ==
            (b['expiresAt']?.toString() ?? '');
  }

  void _sortRestrictions(List<Map<String, dynamic>> list) {
    bool isBlocked(Map<String, dynamic> r) =>
        (r['isBlocked'] as bool? ?? false) || _isExpired(r);

    bool isActive(Map<String, dynamic> r) {
      final enabled = r['isEnabled'] as bool? ?? true;
      final quota = _quotaMinutesFor(r);
      final scheduleActive = (r['scheduleActiveCount'] as int?) ?? 0;
      final dateActive = (r['dateBlockActiveCount'] as int?) ?? 0;
      return enabled &&
          !isBlocked(r) &&
          (quota > 0 || scheduleActive > 0 || dateActive > 0);
    }

    int statusRank(Map<String, dynamic> r) {
      if (isActive(r)) return 0; // activas
      if (isBlocked(r)) return 1; // bloqueadas
      return 2;
    }

    int endingSoonRank(Map<String, dynamic> r) {
      final quota = _quotaMinutesFor(r);
      if (quota <= 0) return 1;
      final limitType = (r['limitType'] ?? 'daily').toString();
      final used = limitType == 'weekly'
          ? (r['usedMinutesWeek'] as int? ?? 0)
          : (r['usedMinutes'] as int? ?? 0);
      final remaining = quota - used;
      if (remaining > 0 && remaining <= 15) return 0; // por terminar
      return 1;
    }

    int startingSoonRank(Map<String, dynamic> r) {
      final scheduleCount = (r['scheduleCount'] as int?) ?? 0;
      final scheduleActive = (r['scheduleActiveCount'] as int?) ?? 0;
      final dateCount = (r['dateBlockCount'] as int?) ?? 0;
      final dateActive = (r['dateBlockActiveCount'] as int?) ?? 0;
      final hasDirect = scheduleCount > 0 || dateCount > 0;
      final activeDirect = scheduleActive > 0 || dateActive > 0;
      if (hasDirect && !activeDirect) return 0; // por empezar
      return 1;
    }

    int directTypeRank(Map<String, dynamic> r) {
      final scheduleCount = (r['scheduleCount'] as int?) ?? 0;
      final dateCount = (r['dateBlockCount'] as int?) ?? 0;
      if (dateCount > 0 && scheduleCount == 0) return 0;
      if (scheduleCount > 0 && dateCount == 0) return 1;
      if (scheduleCount > 0 && dateCount > 0) return 2;
      return 3;
    }

    int typeRank(Map<String, dynamic> r) {
      final scheduleCount = (r['scheduleCount'] as int?) ?? 0;
      final dateCount = (r['dateBlockCount'] as int?) ?? 0;
      if (dateCount > 0 && scheduleCount == 0) return 0; // por fechas
      if (scheduleCount > 0 && dateCount == 0) return 1; // por horarios
      if (scheduleCount > 0 && dateCount > 0) return 2; // mixto
      if (_quotaMinutesFor(r) > 0) return 3; // solo cuota
      return 4;
    }

    list.sort((a, b) {
      if (_sortMode == 'name_asc') {
        final nameA = (a['appName'] ?? '').toString().toLowerCase();
        final nameB = (b['appName'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      }
      if (_sortMode == 'name_desc') {
        final nameA = (a['appName'] ?? '').toString().toLowerCase();
        final nameB = (b['appName'] ?? '').toString().toLowerCase();
        return nameB.compareTo(nameA);
      }
      if (_sortMode == 'usage_high') {
        final ua = _progressFor(a);
        final ub = _progressFor(b);
        if (ua != ub) return ub.compareTo(ua);
      }
      if (_sortMode == 'usage_low') {
        final ua = _progressFor(a);
        final ub = _progressFor(b);
        if (ua != ub) return ua.compareTo(ub);
      }
      if (_sortMode == 'blocked_first') {
        final ba = isBlocked(a);
        final bb = isBlocked(b);
        if (ba != bb) return ba ? -1 : 1;
      }
      if (_sortMode == 'active_first') {
        final aa = isActive(a);
        final ab = isActive(b);
        if (aa != ab) return aa ? -1 : 1;
      }
      if (_sortMode == 'ending_soon') {
        final ea = endingSoonRank(a);
        final eb = endingSoonRank(b);
        if (ea != eb) return ea.compareTo(eb);
      }
      if (_sortMode == 'starting_soon') {
        final pa = startingSoonRank(a);
        final pb = startingSoonRank(b);
        if (pa != pb) return pa.compareTo(pb);
      }
      if (_sortMode == 'dates_first') {
        final ta = directTypeRank(a);
        final tb = directTypeRank(b);
        if (ta != tb) return ta.compareTo(tb);
      }
      if (_sortMode == 'schedules_first') {
        final ta = directTypeRank(a);
        final tb = directTypeRank(b);
        if (ta != tb) {
          final sa = ta == 1
              ? 0
              : ta == 0
                  ? 1
                  : ta;
          final sb = tb == 1
              ? 0
              : tb == 0
                  ? 1
                  : tb;
          if (sa != sb) return sa.compareTo(sb);
        }
      }

      final sa = statusRank(a);
      final sb = statusRank(b);
      if (sa != sb) return sa.compareTo(sb);

      final ea = endingSoonRank(a);
      final eb = endingSoonRank(b);
      if (ea != eb) return ea.compareTo(eb);

      final pa = startingSoonRank(a);
      final pb = startingSoonRank(b);
      if (pa != pb) return pa.compareTo(pb);

      final ta = typeRank(a);
      final tb = typeRank(b);
      if (ta != tb) return ta.compareTo(tb);

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
