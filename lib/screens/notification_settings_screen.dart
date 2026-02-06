import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timelock/theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const _ch = MethodChannel('app.restriction/config');

  bool _quota50Enabled = true;
  bool _quota75Enabled = true;
  bool _lastMinuteEnabled = true;
  bool _blockedEnabled = true;
  bool _scheduleEnabled = true;
  bool _serviceNotificationEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _ch
          .invokeMethod<Map<dynamic, dynamic>>('getNotificationSettings');
      if (settings != null && mounted) {
        setState(() {
          _quota50Enabled = settings['quota50'] as bool? ?? true;
          _quota75Enabled = settings['quota75'] as bool? ?? true;
          _lastMinuteEnabled = settings['lastMinute'] as bool? ?? true;
          _blockedEnabled = settings['blocked'] as bool? ?? true;
          _scheduleEnabled = settings['schedule'] as bool? ?? true;
          _serviceNotificationEnabled =
              settings['serviceNotification'] as bool? ?? true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _ch.invokeMethod('saveNotificationSettings', {
        'quota50': _quota50Enabled,
        'quota75': _quota75Enabled,
        'lastMinute': _lastMinuteEnabled,
        'blocked': _blockedEnabled,
        'schedule': _scheduleEnabled,
        'serviceNotification': _serviceNotificationEnabled,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración guardada'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
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
                  AppSpacing.md,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    border: Border.all(color: AppColors.info, width: 1),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.info, size: 24),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Configura qué notificaciones quieres recibir',
                          style: TextStyle(
                            color: AppColors.info,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Text(
                  'ADVERTENCIAS DE CUOTA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.2,
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
                      _saveSettings();
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _notificationToggle(
                    icon: Icons.warning_amber_rounded,
                    title: 'Quedan pocos minutos (75%)',
                    description: 'Cuando consumes el 75% de tu cuota diaria',
                    value: _quota75Enabled,
                    onChanged: (val) {
                      setState(() => _quota75Enabled = val);
                      _saveSettings();
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _notificationToggle(
                    icon: Icons.error_outline_rounded,
                    title: 'Último minuto disponible',
                    description: 'Cuando solo queda 1 minuto de tu cuota',
                    value: _lastMinuteEnabled,
                    onChanged: (val) {
                      setState(() => _lastMinuteEnabled = val);
                      _saveSettings();
                    },
                  ),
                ]),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Text(
                  'BLOQUEOS Y HORARIOS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.2,
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
                    description: 'Cuando una app es bloqueada automáticamente',
                    value: _blockedEnabled,
                    onChanged: (val) {
                      setState(() => _blockedEnabled = val);
                      _saveSettings();
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _notificationToggle(
                    icon: Icons.schedule_rounded,
                    title: 'Horarios programados',
                    description: 'Avisos sobre bloqueos por horario',
                    value: _scheduleEnabled,
                    onChanged: (val) {
                      setState(() => _scheduleEnabled = val);
                      _saveSettings();
                    },
                  ),
                ]),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Text(
                  'NOTIFICACIÓN DEL SERVICIO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _notificationToggle(
                  icon: Icons.notifications_active_outlined,
                  title: 'Mostrar estado de monitoreo',
                  description:
                      'Notificación permanente que indica apps monitoreadas',
                  value: _serviceNotificationEnabled,
                  onChanged: (val) {
                    setState(() => _serviceNotificationEnabled = val);
                    _saveSettings();
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ],
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: value
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                icon,
                size: 24,
                color: value ? AppColors.success : AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
