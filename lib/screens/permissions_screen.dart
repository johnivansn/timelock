import 'package:flutter/material.dart';
import 'dart:async';
import 'package:timelock/screens/pin_setup_screen.dart';
import 'package:timelock/screens/pin_verify_screen.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/app_utils.dart';

class PermissionsScreen extends StatefulWidget {
  PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _usage = false;
  bool _accessibility = false;
  bool _overlay = false;
  bool _overlayBlocked = false;
  bool _adminEnabled = false;
  bool _loading = true;
  bool _deviceAdmin = false;
  int _adminLockUntilMs = 0;
  Timer? _adminLockTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _adminLockTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final prefs = await NativeService.getSharedPreferences('permission_prefs');
      final lockPrefs =
          await NativeService.getSharedPreferences('admin_lock_prefs');
      final u = await NativeService.checkUsagePermission();
      final a = await NativeService.checkAccessibilityPermission();
      final o = await NativeService.checkOverlayPermission();
      final prefOverlayBlocked = prefs?['overlay_blocked'] == true;
      final effectiveOverlayBlocked = !o && prefOverlayBlocked;
      if (o && prefOverlayBlocked) {
        await _setOverlayBlocked(false);
      }
      final admin = await NativeService.isAdminEnabled();
      final deviceAdmin = await NativeService.isDeviceAdminEnabled();
      final lockUntil =
          (lockPrefs?['lock_until_ms'] as num?)?.toInt() ?? 0;
      if (mounted) {
        setState(() {
          _usage = u;
          _accessibility = a;
          _overlay = o;
          _overlayBlocked = effectiveOverlayBlocked;
          _adminEnabled = admin;
          _deviceAdmin = deviceAdmin;
          _adminLockUntilMs = lockUntil;
          _loading = false;
        });
        _startAdminLockCountdown();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestDeviceAdmin() async {
    try {
      await NativeService.enableDeviceAdmin();
      await Future.delayed(Duration(seconds: 2));
      await _refresh();
    } catch (_) {}
  }

  Future<void> _requestUsage() async {
    try {
      await NativeService.requestUsagePermission();
      await Future.delayed(Duration(seconds: 2));
      await _refresh();
    } catch (_) {}
  }

  Future<void> _requestAccessibility() async {
    try {
      await NativeService.requestAccessibilityPermission();
      await Future.delayed(Duration(seconds: 2));
      await _refresh();
    } catch (_) {}
  }

  Future<void> _requestOverlay() async {
    try {
      await NativeService.requestOverlayPermission();
      await Future.delayed(Duration(seconds: 2));
      await _refresh();
      if (mounted && !_overlay) {
        await _setOverlayBlocked(true);
        _showOverlayBlockedMessage();
      }
    } catch (_) {}
  }

  Future<void> _configureAll() async {
    if (!_usage) await _requestUsage();
    if (!_accessibility) await _requestAccessibility();
  }

  Future<void> _setOverlayBlocked(bool value) async {
    _overlayBlocked = value;
    await NativeService.saveSharedPreference({
      'prefsName': 'permission_prefs',
      'key': 'overlay_blocked',
      'value': value,
    });
  }

  void _showOverlayBlockedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Función no disponible: este dispositivo bloquea el permiso '
          '"Mostrar sobre otras apps" por rendimiento.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  bool get _allOk => _usage && _accessibility;
  bool get _adminLockActive =>
      _adminLockUntilMs > DateTime.now().millisecondsSinceEpoch;
  int get _adminLockRemainingMs {
    final remaining = _adminLockUntilMs - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? remaining : 0;
  }

  Future<void> _setAdminLockUntil(int untilMs) async {
    _adminLockUntilMs = untilMs;
    await NativeService.saveSharedPreference({
      'prefsName': 'admin_lock_prefs',
      'key': 'lock_until_ms',
      'value': untilMs > 0 ? untilMs : null,
    });
  }

  Future<void> _startAdminLock(Duration duration) async {
    final until = DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds;
    if (mounted) {
      setState(() => _adminLockUntilMs = until);
    } else {
      _adminLockUntilMs = until;
    }
    await _setAdminLockUntil(until);
    _startAdminLockCountdown();
  }

  Future<void> _clearAdminLockIfExpired() async {
    if (_adminLockUntilMs <= 0) return;
    if (_adminLockActive) return;
    if (mounted) {
      setState(() => _adminLockUntilMs = 0);
    } else {
      _adminLockUntilMs = 0;
    }
    await _setAdminLockUntil(0);
  }

  void _startAdminLockCountdown() {
    _adminLockTimer?.cancel();
    if (!_adminLockActive) {
      _clearAdminLockIfExpired();
      return;
    }
    _adminLockTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_adminLockActive) {
        _adminLockTimer?.cancel();
        _clearAdminLockIfExpired();
      } else {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text('Permisos'),
            ),
            if (_loading)
              SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                  child: _statusCard(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                      AppSpacing.lg, AppSpacing.xs),
                  child: Text(
                    'PERMISOS CRÍTICOS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _permissionCard(
                      icon: Icons.bar_chart_rounded,
                      title: 'Estadísticas de Uso',
                      description: 'Mide el tiempo de uso de cada aplicación',
                      granted: _usage,
                      critical: true,
                      onRequest: _requestUsage,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    _permissionCard(
                      icon: Icons.accessibility_new_rounded,
                      title: 'Accesibilidad',
                      description: 'Muestra el overlay de bloqueo sobre apps',
                      granted: _accessibility,
                      critical: true,
                      onRequest: _requestAccessibility,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    _permissionCard(
                      icon: Icons.layers_rounded,
                      title: 'Mostrar sobre otras apps',
                      description: _overlayBlocked
                          ? 'No disponible en este dispositivo'
                          : 'Permite dibujar la pantalla de bloqueo encima de cualquier app',
                      granted: _overlay,
                      critical: false,
                      onRequest: _requestOverlay,
                    ),
                  ]),
                ),
              ),
              if (!_allOk)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: SizedBox(
                      height: 44,
                      child: FilledButton.icon(
                        onPressed: _configureAll,
                        icon: Icon(Icons.settings_rounded, size: 18),
                        label: Text('Configurar Todo'),
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                      AppSpacing.lg, AppSpacing.xs),
                  child: Text(
                    'MODO ADMINISTRADOR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    children: [
                      _adminCard(),
                      SizedBox(height: AppSpacing.sm),
                      _adminLockCard(),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                      AppSpacing.lg, AppSpacing.xs),
                  child: Text(
                    'PROTECCIÓN ADICIONAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    children: [
                      _permissionCard(
                        icon: Icons.security_rounded,
                        title: 'Protección básica (Device Admin)',
                        description:
                            'Disuade desinstalación, pero puede desactivarse en Ajustes',
                        granted: _deviceAdmin,
                        critical: false,
                        onRequest: _requestDeviceAdmin,
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    if (_allOk) {
      return Container(
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          border: Border.all(color: AppColors.success, width: 1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 320;
            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 20),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '¡Todo configurado correctamente!',
                          style: TextStyle(
                              color: AppColors.success,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 20),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '¡Todo configurado correctamente!',
                    style: TextStyle(
                        color: AppColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.warning, width: 1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 320;
          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.warning, size: 20),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'La app requiere estos permisos para funcionar',
                        style: TextStyle(color: AppColors.warning, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'La app requiere estos permisos para funcionar',
                  style: TextStyle(color: AppColors.warning, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _permissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool granted,
    required bool critical,
    required VoidCallback onRequest,
  }) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 320;
            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: granted
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: granted ? AppColors.success : AppColors.error,
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.sm,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (critical)
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'REQUERIDO',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.error,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (granted)
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 20)
                      else
                        TextButton(onPressed: onRequest, child: Text('Habilitar')),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        height: 1.4),
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: granted
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: granted ? AppColors.success : AppColors.error,
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.sm,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (critical)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'REQUERIDO',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        description,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                if (granted)
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 20)
                else
                  TextButton(onPressed: onRequest, child: Text('Habilitar')),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _adminCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 320;
            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _adminEnabled
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          _adminEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                          size: 20,
                          color: _adminEnabled ? AppColors.success : AppColors.primary,
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Protección con PIN',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: AppSpacing.xs),
                            Text(
                              _adminEnabled
                                  ? 'Se requiere PIN para modificar restricciones'
                                  : 'Protege contra cambios accidentales',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                  height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _adminEnabled ? _disableAdminButton() : _enableAdminButton(),
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _adminEnabled
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    _adminEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                    size: 20,
                    color: _adminEnabled ? AppColors.success : AppColors.primary,
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Protección con PIN',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        _adminEnabled
                            ? 'Se requiere PIN para modificar restricciones'
                            : 'Protege contra cambios accidentales',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                _adminEnabled ? _disableAdminButton() : _enableAdminButton(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _enableAdminButton() {
    return TextButton(
      onPressed: () {
        Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => PinSetupScreen()),
        ).then((result) {
          if (result == true) _refresh();
        });
      },
      child: Text('Activar'),
    );
  }

  Widget _disableAdminButton() {
    return TextButton(
      onPressed: () {
        Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PinVerifyScreen(
              reason: 'Ingresa tu PIN para desactivar el modo administrador',
            ),
          ),
        ).then((result) async {
          if (result == true) {
            await NativeService.disableAdmin();
            _refresh();
          }
        });
      },
      style: TextButton.styleFrom(foregroundColor: AppColors.error),
      child: Text('Desactivar'),
    );
  }

  Widget _adminLockCard() {
    final remainingText = _adminLockActive
        ? 'Restante: ${AppUtils.formatDurationMillis(_adminLockRemainingMs)}'
        : 'Activa un bloqueo temporal sin PIN';
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 320;
            final header = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bloqueo temporal sin PIN',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  _adminLockActive
                      ? 'No se puede desactivar hasta que expire'
                      : 'Bloquea cambios por un tiempo definido',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    height: 1.4,
                  ),
                ),
              ],
            );
            final badge = Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: _adminLockActive
                    ? AppColors.warning.withValues(alpha: 0.15)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _adminLockActive ? remainingText : 'Inactivo',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _adminLockActive
                      ? AppColors.warning
                      : AppColors.textTertiary,
                ),
              ),
            );
            final actions = Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _adminLockButton('1h', Duration(hours: 1)),
                _adminLockButton('3h', Duration(hours: 3)),
                _adminLockButton('6h', Duration(hours: 6)),
                _adminLockButton('1 día', Duration(days: 1)),
                _adminLockCustomButton(),
              ],
            );
            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  SizedBox(height: AppSpacing.sm),
                  Align(alignment: Alignment.centerLeft, child: badge),
                  SizedBox(height: AppSpacing.sm),
                  actions,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: header),
                SizedBox(width: AppSpacing.sm),
                badge,
                SizedBox(width: AppSpacing.sm),
                Expanded(child: actions),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _adminLockButton(String label, Duration duration) {
    return SizedBox(
      height: 34,
      child: FilledButton(
        onPressed: _adminLockActive ? null : () => _startAdminLock(duration),
        style: FilledButton.styleFrom(
          backgroundColor:
              _adminLockActive ? AppColors.surfaceVariant : AppColors.primary,
          foregroundColor: _adminLockActive
              ? AppColors.textTertiary
              : AppColors.onColor(AppColors.primary),
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          textStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _adminLockCustomButton() {
    return SizedBox(
      height: 34,
      child: OutlinedButton(
        onPressed: _adminLockActive ? null : _pickAdminLockUntil,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: BorderSide(color: AppColors.surfaceVariant),
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          textStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        child: Text('Por fecha'),
      ),
    );
  }

  Future<void> _pickAdminLockUntil() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(Duration(hours: 1))),
    );
    if (time == null) return;
    final selected =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (selected.isBefore(now.add(Duration(minutes: 1)))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selecciona una fecha/hora futura'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    await _startAdminLock(selected.difference(now));
  }
}

