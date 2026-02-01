import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timelock/screens/pin_setup_screen.dart';
import 'package:timelock/screens/pin_verify_screen.dart';
import 'package:timelock/theme/app_theme.dart';

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
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            pinned: true,
            title: Text('Permisos'),
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
                child: _statusCard(),
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
                  'PERMISOS CRÍTICOS',
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
                  _permissionCard(
                    icon: Icons.bar_chart_rounded,
                    title: 'Estadísticas de Uso',
                    description: 'Mide el tiempo de uso de cada aplicación',
                    granted: _usage,
                    critical: true,
                    onRequest: _requestUsage,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _permissionCard(
                    icon: Icons.accessibility_new_rounded,
                    title: 'Accesibilidad',
                    description: 'Muestra el overlay de bloqueo sobre apps',
                    granted: _accessibility,
                    critical: true,
                    onRequest: _requestAccessibility,
                  ),
                ]),
              ),
            ),
            if (!_allOk)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _configureAll,
                      icon: const Icon(Icons.settings_rounded),
                      label: const Text('Configurar Todo'),
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
                  'MODO ADMINISTRADOR',
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
                child: _adminCard(),
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
                  'PROTECCIÓN ADICIONAL',
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
                child: _permissionCard(
                  icon: Icons.security_rounded,
                  title: 'Protección contra desinstalación',
                  description: 'Evita desinstalación accidental de la app',
                  granted: _deviceAdmin,
                  critical: false,
                  onRequest: _requestDeviceAdmin,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ],
      ),
    );
  }

  Widget _statusCard() {
    if (_allOk) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          border: Border.all(color: AppColors.success, width: 1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 24),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                '¡Todo configurado correctamente!',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.warning, width: 1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'La app requiere estos permisos para funcionar',
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 14,
              ),
            ),
          ),
        ],
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: granted
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                icon,
                size: 24,
                color: granted ? AppColors.success : AppColors.error,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (critical)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
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
            if (granted)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 24)
            else
              TextButton(
                onPressed: onRequest,
                child: const Text('Habilitar'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _adminCard() {
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
                color: _adminEnabled
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                _adminEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 24,
                color: _adminEnabled ? AppColors.success : AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Protección con PIN',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _adminEnabled
                        ? 'Se requiere PIN para modificar restricciones'
                        : 'Protege contra cambios accidentales',
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
              reason: 'Ingresa tu PIN para desactivar el modo administrador',
            ),
          ),
        ).then((result) async {
          if (result == true) {
            await _ch.invokeMethod('disableAdmin');
            _refresh();
          }
        });
      },
      style: TextButton.styleFrom(foregroundColor: AppColors.error),
      child: const Text('Desactivar'),
    );
  }
}
