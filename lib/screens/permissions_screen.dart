import 'package:flutter/material.dart';
import 'package:timelock/screens/pin_setup_screen.dart';
import 'package:timelock/screens/pin_verify_screen.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';

class PermissionsScreen extends StatefulWidget {
  PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _usage = false;
  bool _accessibility = false;
  bool _overlay = false;
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
      final u = await NativeService.checkUsagePermission();
      final a = await NativeService.checkAccessibilityPermission();
      final o = await NativeService.checkOverlayPermission();
      final admin = await NativeService.isAdminEnabled();
      final deviceAdmin = await NativeService.isDeviceAdminEnabled();
      if (mounted) {
        setState(() {
          _usage = u;
          _accessibility = a;
          _overlay = o;
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
    } catch (_) {}
  }

  Future<void> _configureAll() async {
    if (!_usage) await _requestUsage();
    if (!_accessibility) await _requestAccessibility();
    if (!_overlay) await _requestOverlay();
  }

  bool get _allOk => _usage && _accessibility && _overlay;

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
                      description:
                          'Permite dibujar la pantalla de bloqueo encima de cualquier app',
                      granted: _overlay,
                      critical: true,
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
                  child: _adminCard(),
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
        child: Row(
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
      );
    }
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.warning, width: 1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
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
        child: Row(
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
        ),
      ),
    );
  }

  Widget _adminCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
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
}

