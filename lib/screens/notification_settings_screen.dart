import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const _ch = MethodChannel('app.restriction/config');

  bool _quota25Enabled = true;
  bool _quota10Enabled = true;
  bool _blockedEnabled = true;
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
          _quota25Enabled = settings['quota25'] as bool? ?? true;
          _quota10Enabled = settings['quota10'] as bool? ?? true;
          _blockedEnabled = settings['blocked'] as bool? ?? true;
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
        'quota25': _quota25Enabled,
        'quota10': _quota10Enabled,
        'blocked': _blockedEnabled,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración guardada'),
            backgroundColor: Color(0xFF27AE60),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFF0F0F1A),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white70, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Notificaciones',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0x1A6C5CE7),
                    border:
                        Border.all(color: const Color(0xFF6C5CE7), width: 1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Color(0xFF6C5CE7), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Configura qué notificaciones quieres recibir',
                          style:
                              TextStyle(color: Color(0xFF6C5CE7), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 4),
                child: Text(
                  'ADVERTENCIAS DE CUOTA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white38,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _notificationToggle(
                  icon: Icons.warning_amber_outlined,
                  title: 'Queda 25% de tiempo',
                  description:
                      'Notificación cuando consumes el 75% de tu cuota diaria',
                  value: _quota25Enabled,
                  onChanged: (val) {
                    setState(() => _quota25Enabled = val);
                    _saveSettings();
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _notificationToggle(
                  icon: Icons.error_outline,
                  title: 'Últimos minutos (10%)',
                  description:
                      'Notificación cuando consumes el 90% de tu cuota diaria',
                  value: _quota10Enabled,
                  onChanged: (val) {
                    setState(() => _quota10Enabled = val);
                    _saveSettings();
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 4),
                child: Text(
                  'BLOQUEOS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white38,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _notificationToggle(
                  icon: Icons.lock_outline,
                  title: 'App bloqueada',
                  description:
                      'Notificación cuando una app es bloqueada automáticamente',
                  value: _blockedEnabled,
                  onChanged: (val) {
                    setState(() => _blockedEnabled = val);
                    _saveSettings();
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: value ? const Color(0x1A27AE60) : const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 22,
                color: value ? const Color(0xFF27AE60) : Colors.white38,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white38,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF27AE60),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: const Color(0xFF2A2A3E),
          ),
        ],
      ),
    );
  }
}
