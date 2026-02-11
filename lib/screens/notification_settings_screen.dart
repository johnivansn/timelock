import 'package:flutter/material.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  NotificationSettingsScreen({super.key});

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
      final overlayBlocked = permissionPrefs?['overlay_blocked'] == true;
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
          _notificationStyle =
              prefs['notify_style']?.toString() ?? 'pill';
          _overlayAvailable = overlayAvailable;
          _loading = false;
        });
        if (!_overlayAvailable && _notificationStyle == 'pill') {
          _notificationStyle = 'normal';
          await _saveSetting('notify_style', 'normal');
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
          SnackBar(
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
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
          SliverAppBar(
            pinned: true,
            title: Text('Notificaciones'),
          ),
          if (_loading)
            SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
            )
          else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Container(
                    padding: EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      border: Border.all(color: AppColors.info, width: 1),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: AppColors.info, size: 18),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Las notificaciones aparecen como píldoras flotantes en la parte superior de la pantalla',
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
                  padding: EdgeInsets.fromLTRB(
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
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _notificationStyleCard(),
                ),
              ),
            SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
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
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
                    SizedBox(height: AppSpacing.sm),
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
                    SizedBox(height: AppSpacing.sm),
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
                  padding: EdgeInsets.fromLTRB(
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
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _notificationToggle(
                    icon: Icons.lock_outline_rounded,
                    title: 'App bloqueada',
                    description: 'Cuando una app es bloqueada automáticamente',
                    value: _blockedEnabled,
                    onChanged: (val) {
                      setState(() => _blockedEnabled = val);
                      _saveSetting('notify_blocked', val);
                    },
                  ),
                    SizedBox(height: AppSpacing.sm),
                    _notificationToggle(
                      icon: Icons.schedule_rounded,
                      title: 'Horarios programados',
                      description: 'Avisos sobre bloqueos por horario',
                      value: _scheduleEnabled,
                    onChanged: (val) {
                      setState(() => _scheduleEnabled = val);
                      _saveSetting('notify_schedule', val);
                    },
                  ),
                    SizedBox(height: AppSpacing.sm),
                    _notificationToggle(
                      icon: Icons.event_busy_rounded,
                      title: 'Bloqueos por fechas',
                      description:
                          'Avisos con días restantes para terminar el bloqueo',
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
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xs,
                  ),
                  child: Text(
                    'NOTIFICACIÓN DEL SERVICIO',
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
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _notificationToggle(
                  icon: Icons.notifications_active_outlined,
                  title: 'Mostrar estado de monitoreo',
                  description:
                      'Notificación permanente que indica apps monitoreadas',
                  value: _serviceNotificationEnabled,
                  onChanged: (val) {
                    setState(() => _serviceNotificationEnabled = val);
                    _saveSetting('notify_service_status', val);
                  },
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

  Widget _notificationStyleCard() {
    final pillDisabled = !_overlayAvailable;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecciona el formato',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              pillDisabled
                  ? 'La opción píldora requiere permiso de overlay'
                  : 'Píldora flotante o notificación normal',
              style: TextStyle(
                fontSize: 11,
                color: pillDisabled
                    ? AppColors.warning
                    : AppColors.textTertiary,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                ChoiceChip(
                  label: Text('Píldora'),
                  selected: _notificationStyle == 'pill',
                  onSelected: pillDisabled
                      ? null
                      : (value) {
                          if (!value) return;
                          setState(() => _notificationStyle = 'pill');
                          _saveSetting('notify_style', 'pill');
                        },
                ),
                ChoiceChip(
                  label: Text('Normal'),
                  selected: _notificationStyle == 'normal',
                  onSelected: (value) {
                    if (!value) return;
                    setState(() => _notificationStyle = 'normal');
                    _saveSetting('notify_style', 'normal');
                  },
                ),
              ],
            ),
          ],
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
                            color: value
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(
                            icon,
                            size: 20,
                            color:
                                value ? AppColors.success : AppColors.textTertiary,
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
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
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
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
                      color: value ? AppColors.success : AppColors.textTertiary,
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
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
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
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

