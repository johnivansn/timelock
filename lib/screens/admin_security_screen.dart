import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:timelock/screens/pin_setup_screen.dart';
import 'package:timelock/screens/pin_verify_screen.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/app_utils.dart';

class AdminSecurityScreen extends StatefulWidget {
  const AdminSecurityScreen({super.key});

  @override
  State<AdminSecurityScreen> createState() => _AdminSecurityScreenState();
}

class _AdminSecurityScreenState extends State<AdminSecurityScreen> {
  bool _loading = true;
  bool _adminEnabled = false;
  bool _deviceAdmin = false;
  int _adminLockUntilMs = 0;
  bool _adminLockJustExpired = false;
  bool _adminLockExpiryNotified = false;
  Timer? _adminLockTimer;
  int _selectedHours = 0;
  int _selectedMinutes = 0;
  bool _hasSelectedDuration = false;

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
      final lockPrefs =
          await NativeService.getSharedPreferences('admin_lock_prefs');
      final admin = await NativeService.isAdminEnabled();
      final deviceAdmin = await NativeService.isDeviceAdminEnabled();
      final lockUntil = (lockPrefs?['lock_until_ms'] as num?)?.toInt() ?? 0;
      final lockActive = lockUntil > DateTime.now().millisecondsSinceEpoch;
      if (!mounted) return;
      setState(() {
        _adminEnabled = admin;
        _deviceAdmin = deviceAdmin;
        _adminLockUntilMs = lockUntil;
        if (lockActive) {
          _adminLockJustExpired = false;
          _adminLockExpiryNotified = false;
        }
        _loading = false;
      });
      _startAdminLockCountdown();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

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
    final until =
        DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds;
    if (mounted) {
      setState(() {
        _adminLockUntilMs = until;
        _adminLockJustExpired = false;
        _adminLockExpiryNotified = false;
      });
    } else {
      _adminLockUntilMs = until;
      _adminLockJustExpired = false;
      _adminLockExpiryNotified = false;
    }
    await _setAdminLockUntil(until);
    _startAdminLockCountdown();
  }

  Future<void> _clearAdminLockIfExpired() async {
    if (_adminLockUntilMs <= 0) return;
    if (_adminLockActive) return;
    if (mounted) {
      setState(() {
        _adminLockUntilMs = 0;
        _adminLockJustExpired = true;
      });
    } else {
      _adminLockUntilMs = 0;
      _adminLockJustExpired = true;
    }
    await _setAdminLockUntil(0);
    if (mounted && !_adminLockExpiryNotified) {
      _adminLockExpiryNotified = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El bloqueo temporal terminó. Ya puedes hacer cambios.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _startAdminLockCountdown() {
    _adminLockTimer?.cancel();
    if (!_adminLockActive) {
      _clearAdminLockIfExpired();
      return;
    }
    _adminLockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_adminLockActive) {
        _adminLockTimer?.cancel();
        _clearAdminLockIfExpired();
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _requestDeviceAdmin() async {
    try {
      await NativeService.enableDeviceAdmin();
      await Future.delayed(const Duration(seconds: 2));
      await _refresh();
    } catch (_) {}
  }

  Future<void> _pickAdminLockUntil() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    final selected =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (selected.isBefore(now.add(const Duration(minutes: 1)))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecciona una fecha/hora futura'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final duration = selected.difference(now);
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar bloqueo'),
        content: Text(
          'Se bloquearán los cambios hasta la fecha elegida.\n\n'
          'Tiempo estimado: ${AppUtils.formatDurationMillis(duration.inMilliseconds)}.\n\n'
          '¿Deseas aplicar este bloqueo temporal?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await _startAdminLock(duration);
  }

  Future<void> _pickAdminLockDurationCarousel() async {
    var hours = _selectedHours;
    var minutes = _selectedMinutes;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.surfaceVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Elegir duración',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 180,
                    child: Row(
                      children: [
                        Expanded(
                          child: _durationWheel(
                            initial: hours,
                            max: 23,
                            label: 'Horas',
                            onChanged: (v) => hours = v,
                          ),
                        ),
                        Expanded(
                          child: _durationWheel(
                            initial: minutes,
                            max: 59,
                            label: 'Min',
                            onChanged: (v) => minutes = v,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _selectedHours = hours;
                          _selectedMinutes = minutes;
                          _hasSelectedDuration = true;
                        });
                        Navigator.pop(dialogContext);
                        _applySelectedAdminLockDuration();
                      },
                      child: const Text('Aplicar tiempo'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _durationWheel({
    required int initial,
    required int max,
    required String label,
    required ValueChanged<int> onChanged,
  }) {
    final rangeCount = max + 1;
    const virtualItems = 10000;
    final middleBase = (virtualItems ~/ 2) - ((virtualItems ~/ 2) % rangeCount);
    final controller = FixedExtentScrollController(
      initialItem: middleBase + initial,
    );
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: CupertinoPicker.builder(
            itemExtent: 34,
            scrollController: controller,
            selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
              background: AppColors.primary.withValues(alpha: 0.08),
            ),
            onSelectedItemChanged: (index) => onChanged(index % rangeCount),
            childCount: virtualItems,
            itemBuilder: (_, index) {
              final value = index % rangeCount;
              return Center(
                child: Text(
                  value.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _applySelectedAdminLockDuration() {
    final totalMinutes = _selectedHours * 60 + _selectedMinutes;
    if (totalMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un tiempo mayor a 0 minutos.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _startAdminLock(Duration(minutes: totalMinutes));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              pinned: true,
              title: Text('Admin y seguridad'),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xs,
                  ),
                  child: Text(
                    'SEGURIDAD CON PIN',
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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _adminCard(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xs,
                  ),
                  child: Text(
                    'BLOQUEO TEMPORAL',
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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _adminLockCard(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xs,
                  ),
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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _deviceAdminCard(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _adminCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
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
            const SizedBox(width: AppSpacing.sm),
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
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _adminEnabled
                        ? 'Activa: se requiere PIN para cambios sensibles.'
                        : 'Desactivada: cualquier persona con acceso al teléfono puede cambiar límites.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _adminEnabled ? _disableAdminButton() : _enableAdminButton(),
          ],
        ),
      ),
    );
  }

  Widget _enableAdminButton() {
    return TextButton(
      onPressed: () {
        Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const PinSetupScreen()),
        ).then((result) {
          if (result == true) _refresh();
        });
      },
      child: const Text('Activar'),
    );
  }

  Widget _disableAdminButton() {
    return TextButton(
      onPressed: () {
        Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => const PinVerifyScreen(
              reason: 'Ingresa tu PIN para desactivar la protección con PIN',
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
      child: const Text('Desactivar'),
    );
  }

  Widget _adminLockCard() {
    final statusText = _adminLockActive
        ? 'Restante: ${AppUtils.formatDurationMillis(_adminLockRemainingMs)}'
        : _adminLockJustExpired
            ? 'Vencido'
            : 'Inactivo';
    final statusColor = _adminLockActive
        ? AppColors.warning
        : _adminLockJustExpired
            ? AppColors.success
            : AppColors.textTertiary;
    final badgeBg = _adminLockActive
        ? AppColors.warning.withValues(alpha: 0.15)
        : _adminLockJustExpired
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.surfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bloqueo temporal sin PIN',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _adminLockActive
                  ? 'No podrás cambiar ajustes hasta que termine.'
                  : _adminLockJustExpired
                      ? 'El bloqueo terminó. Ya puedes cambiar ajustes.'
                      : 'Selecciona cuánto tiempo quieres mantener este bloqueo.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_hasSelectedDuration) ...[
              Text(
                'Tiempo elegido: ${_selectedHours}h ${_selectedMinutes}m',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: FilledButton(
                      onPressed: _adminLockActive
                          ? null
                          : _pickAdminLockDurationCarousel,
                      style: FilledButton.styleFrom(
                        backgroundColor: _adminLockActive
                            ? AppColors.surfaceVariant
                            : AppColors.primary,
                        foregroundColor: _adminLockActive
                            ? AppColors.textTertiary
                            : AppColors.onColor(AppColors.primary),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Elegir tiempo'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _adminLockCustomButton(),
              ],
            ),
          ],
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        child: const Text('Elegir fecha'),
      ),
    );
  }

  Widget _deviceAdminCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _deviceAdmin
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                Icons.security_rounded,
                size: 20,
                color: _deviceAdmin ? AppColors.success : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Evitar desinstalación',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _deviceAdmin
                        ? 'Activa: ayuda a evitar que se desinstale la app por accidente.'
                        : 'Actívala para agregar una capa extra contra la desinstalación de la app.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (_deviceAdmin)
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
            else
              TextButton(
                onPressed: _requestDeviceAdmin,
                child: const Text('Activar'),
              ),
          ],
        ),
      ),
    );
  }
}
