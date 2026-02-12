import 'package:flutter/material.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _usage = false;
  bool _accessibility = false;
  bool _overlay = false;
  bool _overlayBlocked = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final prefs =
          await NativeService.getSharedPreferences('permission_prefs');
      final u = await NativeService.checkUsagePermission();
      final a = await NativeService.checkAccessibilityPermission();
      final o = await NativeService.checkOverlayPermission();
      final prefOverlayBlocked = prefs?['overlay_blocked'] == true;
      final effectiveOverlayBlocked = !o && prefOverlayBlocked;
      if (o && prefOverlayBlocked) {
        await _setOverlayBlocked(false);
      }
      if (mounted) {
        setState(() {
          _usage = u;
          _accessibility = a;
          _overlay = o;
          _overlayBlocked = effectiveOverlayBlocked;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestUsage() async {
    try {
      await NativeService.requestUsagePermission();
      await Future.delayed(const Duration(seconds: 2));
      await _refresh();
    } catch (_) {}
  }

  Future<void> _requestAccessibility() async {
    try {
      await NativeService.requestAccessibilityPermission();
      await Future.delayed(const Duration(seconds: 2));
      await _refresh();
    } catch (_) {}
  }

  Future<void> _requestOverlay() async {
    try {
      await NativeService.requestOverlayPermission();
      await Future.delayed(const Duration(seconds: 2));
      await _refresh();
      if (mounted && !_overlay) {
        await _setOverlayBlocked(true);
        _showOverlayBlockedMessage();
      }
    } catch (_) {}
  }

  Future<void> _configureAll() async {
    if (!_usage) {
      await _requestUsage();
      if (!_usage) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se activó Estadísticas de Uso. Actívalo para continuar.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }
    if (!_accessibility) {
      await _requestAccessibility();
      if (!_accessibility) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se activó Accesibilidad. Actívalo para continuar.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Permisos críticos activados correctamente.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
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
      const SnackBar(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
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
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                  child: _statusCard(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
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
                    const SizedBox(height: AppSpacing.sm),
                    _permissionCard(
                      icon: Icons.accessibility_new_rounded,
                      title: 'Accesibilidad',
                      description: 'Muestra el overlay de bloqueo sobre apps',
                      granted: _accessibility,
                      critical: true,
                      onRequest: _requestAccessibility,
                    ),
                    const SizedBox(height: AppSpacing.sm),
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
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: SizedBox(
                      height: 44,
                      child: FilledButton.icon(
                        onPressed: _configureAll,
                        icon: const Icon(Icons.settings_rounded, size: 18),
                        label: const Text('Configurar permisos críticos'),
                      ),
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

  Widget _statusCard() {
    if (_allOk) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          border: Border.all(color: AppColors.success, width: 1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Permisos críticos activos',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.warning, width: 1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
          child: Text(
              'Sin estos permisos críticos, el bloqueo y el monitoreo no funcionarán correctamente.',
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
        padding: const EdgeInsets.all(AppSpacing.md),
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
            const SizedBox(width: AppSpacing.sm),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
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
                  const SizedBox(height: AppSpacing.xs),
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
            const SizedBox(width: AppSpacing.sm),
            if (granted)
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
            else
              TextButton(onPressed: onRequest, child: const Text('Habilitar')),
          ],
        ),
      ),
    );
  }
}
