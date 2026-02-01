import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timelock/screens/pin_setup_screen.dart';
import 'package:timelock/screens/pin_verify_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  static const _ch = MethodChannel('app.restriction/config');

  bool _usage = false;
  bool _accessibility = false;
  bool _adminEnabled = false;
  bool _loading = true;
  bool _deviceAdmin = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final u = await _ch.invokeMethod<bool>('checkUsagePermission') ?? false;
      final a =
          await _ch.invokeMethod<bool>('checkAccessibilityPermission') ?? false;
      final admin = await _ch.invokeMethod<bool>('isAdminEnabled') ?? false;
      final deviceAdmin =
          await _ch.invokeMethod<bool>('isDeviceAdminEnabled') ?? false;
      if (mounted) {
        setState(() {
          _usage = u;
          _accessibility = a;
          _adminEnabled = admin;
          _deviceAdmin = deviceAdmin;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestDeviceAdmin() async {
    try {
      await _ch.invokeMethod('enableDeviceAdmin');
      await Future.delayed(const Duration(seconds: 2));
      await _refresh();
    } catch (_) {}
  }

  Future<void> _requestUsage() async {
    try {
      await _ch.invokeMethod('requestUsagePermission');
      await Future.delayed(const Duration(seconds: 2));
      await _refresh();
    } catch (_) {}
  }

  Future<void> _requestAccessibility() async {
    try {
      await _ch.invokeMethod('requestAccessibilityPermission');
      await Future.delayed(const Duration(seconds: 2));
      await _refresh();
    } catch (_) {}
  }

  Future<void> _configureAll() async {
    if (!_usage) await _requestUsage();
    if (!_accessibility) await _requestAccessibility();
  }

  bool get _allOk => _usage && _accessibility;

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
              'Permisos',
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
                child: _statusCard(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _permissionItem(
                  icon: Icons.bar_chart_outlined,
                  title: 'Estadísticas de Uso',
                  description:
                      'Necesario para medir el tiempo de uso de cada aplicación.',
                  granted: _usage,
                  critical: true,
                  onRequest: _requestUsage,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _permissionItem(
                  icon: Icons.accessibility_new_outlined,
                  title: 'Accesibilidad',
                  description:
                      'Permite mostrar el overlay de bloqueo sobre las aplicaciones.',
                  granted: _accessibility,
                  critical: true,
                  onRequest: _requestAccessibility,
                ),
              ),
            ),
            if (!_allOk)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _configureAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Configurar Todo',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 4),
                child: Text(
                  'MODO ADMINISTRADOR',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white38,
                      letterSpacing: 1.0),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _adminCard(),
              ),

            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 4),
                child: Text(
                  'PROTECCIÓN ADICIONAL',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white38,
                      letterSpacing: 1.0),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _permissionItem(
                  icon: Icons.security_outlined,
                  title: 'Protección contra desinstalación',
                  description:
                      'Evita que la app sea desinstalada accidentalmente.',
                  granted: _deviceAdmin,
                  critical: false,
                  onRequest: _requestDeviceAdmin,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusCard() {
    if (_allOk) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0x1A27AE60),
          border: Border.all(color: const Color(0xFF27AE60), width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: Color(0xFF27AE60), size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '¡Todo configurado correctamente!',
                style: TextStyle(
                    color: Color(0xFF27AE60),
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x1AF39C12),
        border: Border.all(color: const Color(0xFFF39C12), width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_outlined,
              color: Color(0xFFF39C12), size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'La app no funcionará correctamente sin los permisos requeridos.',
              style: TextStyle(color: Color(0xFFF39C12), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _permissionItem({
    required IconData icon,
    required String title,
    required String description,
    required bool granted,
    required bool critical,
    required VoidCallback onRequest,
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
              color:
                  granted ? const Color(0x1A27AE60) : const Color(0x1AE74C3C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(icon,
                  size: 22,
                  color: granted
                      ? const Color(0xFF27AE60)
                      : const Color(0xFFE74C3C)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                    if (critical)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0x33E74C3C),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'CRÍTICO',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE74C3C),
                              letterSpacing: 0.5),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white38, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (granted)
            const Icon(Icons.check_circle, color: Color(0xFF27AE60), size: 24)
          else
            TextButton(
              onPressed: onRequest,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text('Habilitar',
                  style: TextStyle(
                      color: Color(0xFF6C5CE7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _adminCard() {
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
              color: _adminEnabled
                  ? const Color(0x1A27AE60)
                  : const Color(0x1A6C5CE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                _adminEnabled ? Icons.lock : Icons.lock_open_outlined,
                size: 22,
                color: _adminEnabled
                    ? const Color(0xFF27AE60)
                    : const Color(0xFF6C5CE7),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Protección con PIN',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  _adminEnabled
                      ? 'Activo — Se requiere PIN para modificar restricciones'
                      : 'Protege la configuración contra cambios accidentales',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white38, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _adminEnabled ? _disableAdminButton() : _enableAdminButton(),
        ],
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
      style: TextButton.styleFrom(padding: EdgeInsets.zero),
      child: const Text('Activar',
          style: TextStyle(
              color: Color(0xFF6C5CE7),
              fontSize: 13,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _disableAdminButton() {
    return TextButton(
      onPressed: () {
        Navigator.push<bool>(
          context,
          MaterialPageRoute(
              builder: (_) => const PinVerifyScreen(
                  reason:
                      'Ingresa tu PIN para desactivar el modo administrador')),
        ).then((result) async {
          if (result == true) {
            await _ch.invokeMethod('disableAdmin');
            _refresh();
          }
        });
      },
      style: TextButton.styleFrom(padding: EdgeInsets.zero),
      child: const Text('Desactivar',
          style: TextStyle(
              color: Color(0xFFE74C3C),
              fontSize: 13,
              fontWeight: FontWeight.w600)),
    );
  }
}
