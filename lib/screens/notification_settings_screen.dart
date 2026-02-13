import 'package:flutter/material.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/app_motion.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _quota50Enabled = true;
  bool _quota75Enabled = true;
  bool _lastMinuteEnabled = true;
  bool _blockedEnabled = true;
  bool _scheduleEnabled = true;
  bool _dateBlockEnabled = true;
  bool _serviceNotificationEnabled = true;
  String _notificationStyle = 'pill';
  bool _overlayForPillEnabled = true;
  bool _overlayAvailable = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs =
          await NativeService.getSharedPreferences('notification_prefs');
      final permissionPrefs =
          await NativeService.getSharedPreferences('permission_prefs');
      final overlay = await NativeService.checkOverlayPermission();
      final prefOverlayBlocked = permissionPrefs?['overlay_blocked'] == true;
      final overlayBlocked = !overlay && prefOverlayBlocked;
      if (overlay && prefOverlayBlocked) {
        await NativeService.saveSharedPreference({
          'prefsName': 'permission_prefs',
          'key': 'overlay_blocked',
          'value': false,
        });
      }
      final overlayAvailable = overlay && !overlayBlocked;
      if (prefs != null && mounted) {
        setState(() {
          _quota50Enabled = prefs['notify_quota_50'] as bool? ?? true;
          _quota75Enabled = prefs['notify_quota_75'] as bool? ?? true;
          _lastMinuteEnabled = prefs['notify_last_minute'] as bool? ?? true;
          _blockedEnabled = prefs['notify_blocked'] as bool? ?? true;
          _scheduleEnabled = prefs['notify_schedule'] as bool? ?? true;
          _dateBlockEnabled = prefs['notify_date_block'] as bool? ?? true;
          _serviceNotificationEnabled =
              prefs['notify_service_status'] as bool? ?? true;
          _notificationStyle = prefs['notify_style']?.toString() ?? 'pill';
          _overlayForPillEnabled =
              prefs['notify_overlay_enabled'] as bool? ?? true;
          _overlayAvailable = overlayAvailable;
          _loading = false;
        });
        if (!_overlayAvailable) {
          if (_notificationStyle != 'normal') {
            _notificationStyle = 'normal';
            await NativeService.saveSharedPreference({
              'prefsName': 'notification_prefs',
              'key': 'notify_style',
              'value': 'normal',
            });
          }
          if (_overlayForPillEnabled) {
            _overlayForPillEnabled = false;
            await NativeService.saveSharedPreference({
              'prefsName': 'notification_prefs',
              'key': 'notify_overlay_enabled',
              'value': false,
            });
          }
          if (mounted) setState(() {});
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      await NativeService.saveSharedPreference({
        'prefsName': 'notification_prefs',
        'key': key,
        'value': value,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración guardada'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              pinned: true,
              title: Text('Notificaciones'),
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
                    AppSpacing.sm,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      border: Border.all(color: AppColors.info, width: 1),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: AppColors.info, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Configura cómo quieres recibir avisos: píldora flotante o notificación normal.',
                            style: TextStyle(
                              color: AppColors.info,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                    'TIPO DE NOTIFICACIÓN',
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
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _notificationStyleCard(),
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
                    'ADVERTENCIAS DE CUOTA',
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _notificationToggle(
                      icon: Icons.hourglass_bottom_rounded,
                      title: 'Mitad del tiempo usado (50%)',
                      description: 'Cuando consumes el 50% de tu cuota diaria',
                      value: _quota50Enabled,
                      onChanged: (val) {
                        setState(() => _quota50Enabled = val);
                        _saveSetting('notify_quota_50', val);
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _notificationToggle(
                      icon: Icons.warning_amber_rounded,
                      title: 'Quedan pocos minutos (75%)',
                      description: 'Cuando consumes el 75% de tu cuota diaria',
                      value: _quota75Enabled,
                      onChanged: (val) {
                        setState(() => _quota75Enabled = val);
                        _saveSetting('notify_quota_75', val);
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _notificationToggle(
                      icon: Icons.error_outline_rounded,
                      title: 'Último minuto disponible',
                      description: 'Cuando solo queda 1 minuto de tu cuota',
                      value: _lastMinuteEnabled,
                      onChanged: (val) {
                        setState(() => _lastMinuteEnabled = val);
                        _saveSetting('notify_last_minute', val);
                      },
                    ),
                  ]),
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
                    'BLOQUEOS Y HORARIOS',
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _notificationToggle(
                      icon: Icons.lock_outline_rounded,
                      title: 'App bloqueada',
                      description:
                          'Cuando una app es bloqueada automáticamente',
                      value: _blockedEnabled,
                      onChanged: (val) {
                        setState(() => _blockedEnabled = val);
                        _saveSetting('notify_blocked', val);
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _notificationToggle(
                      icon: Icons.schedule_rounded,
                      title: 'Horarios programados',
                      description:
                          'Aviso 5 min antes de activar restricción (con rango horario)',
                      value: _scheduleEnabled,
                      onChanged: (val) {
                        setState(() => _scheduleEnabled = val);
                        _saveSetting('notify_schedule', val);
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _notificationToggle(
                      icon: Icons.event_busy_rounded,
                      title: 'Bloqueos por fechas',
                      description:
                          'Avisos de fecha: "Mañana se activa..." y "En 5 min..." (con horario). Si varias apps comparten etiqueta, se agrupan en una sola notificación.',
                      value: _dateBlockEnabled,
                      onChanged: (val) {
                        setState(() => _dateBlockEnabled = val);
                        _saveSetting('notify_date_block', val);
                      },
                    ),
                  ]),
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
                    'MONITOREO EN SEGUNDO PLANO',
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
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _notificationToggle(
                    icon: Icons.notifications_active_outlined,
                    title: 'Activar monitoreo continuo',
                    description:
                        'Si se desactiva, el monitoreo y bloqueo automático en segundo plano se detienen',
                    value: _serviceNotificationEnabled,
                    onChanged: (val) {
                      setState(() => _serviceNotificationEnabled = val);
                      _saveSetting('notify_service_status', val);
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _notificationStyleCard() {
    final pillDisabled = !_overlayAvailable;
    final overlayToggleEnabled = _overlayAvailable;
    final usingPill = _notificationStyle == 'pill';
    final styleLabel = usingPill ? 'Píldora' : 'Normal';
    final overlayLabel = _overlayForPillEnabled
        ? 'Bloqueo en pantalla activo'
        : 'Bloqueo en pantalla inactivo';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    usingPill
                        ? Icons.view_stream_rounded
                        : Icons.notifications_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Formato de alertas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '$styleLabel • $overlayLabel',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              pillDisabled
                  ? 'La opción píldora requiere "Mostrar sobre otras apps"'
                  : 'Píldora flotante o notificación normal',
              style: TextStyle(
                fontSize: 11,
                color:
                    pillDisabled ? AppColors.warning : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _styleOptionCard(
                    icon: Icons.view_stream_rounded,
                    title: 'Píldora',
                    subtitle: 'Flotante',
                    selected: usingPill,
                    enabled: !pillDisabled,
                    onTap: () {
                      setState(() => _notificationStyle = 'pill');
                      _saveSetting('notify_style', 'pill');
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _styleOptionCard(
                    icon: Icons.notifications_active_outlined,
                    title: 'Normal',
                    subtitle: 'Sistema',
                    selected: !usingPill,
                    enabled: true,
                    onTap: () {
                      setState(() => _notificationStyle = 'normal');
                      _saveSetting('notify_style', 'normal');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: overlayToggleEnabled
                    ? AppColors.surfaceVariant.withValues(alpha: 0.35)
                    : AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: overlayToggleEnabled
                      ? AppColors.surfaceVariant.withValues(alpha: 0.75)
                      : AppColors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    overlayToggleEnabled
                        ? Icons.layers_outlined
                        : Icons.layers_clear_outlined,
                    size: 16,
                    color: overlayToggleEnabled
                        ? AppColors.textSecondary
                        : AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mostrar bloqueo en pantalla',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: overlayToggleEnabled
                                ? AppColors.textSecondary
                                : AppColors.warning,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          overlayToggleEnabled
                              ? (_overlayForPillEnabled
                                  ? 'Se muestra una pantalla flotante al bloquear.'
                                  : 'Se usa notificación normal al bloquear.')
                              : 'No disponible sin permiso "Mostrar sobre otras apps".',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _overlayForPillEnabled
                          ? AppColors.success.withValues(alpha: 0.16)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _overlayForPillEnabled
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.surfaceVariant,
                      ),
                    ),
                    child: Text(
                      _overlayForPillEnabled ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _overlayForPillEnabled
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Switch(
                    value: _overlayForPillEnabled,
                    onChanged: overlayToggleEnabled
                        ? (value) {
                            setState(() => _overlayForPillEnabled = value);
                            _saveSetting('notify_overlay_enabled', value);
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _styleOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final active = selected && enabled;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: AppMotion.duration(const Duration(milliseconds: 180)),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: !enabled
                ? AppColors.surfaceVariant.withValues(alpha: 0.22)
                : active
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: !enabled
                  ? AppColors.surfaceVariant
                  : active
                      ? AppColors.primary
                      : AppColors.surfaceVariant.withValues(alpha: 0.8),
              width: active ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: !enabled
                    ? AppColors.textTertiary
                    : active
                        ? AppColors.primary
                        : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: !enabled
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notificationToggle({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
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
                          color: value
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: value
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Switch(
                        value: value,
                        onChanged: onChanged,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
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
                    color: value
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: value ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Switch(
                  value: value,
                  onChanged: onChanged,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
