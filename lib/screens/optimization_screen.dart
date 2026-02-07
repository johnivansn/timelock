import 'package:flutter/material.dart';
import 'package:timelock/extensions/context_extensions.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';

class OptimizationScreen extends StatefulWidget {
  const OptimizationScreen({super.key});

  @override
  State<OptimizationScreen> createState() => _OptimizationScreenState();
}

class _OptimizationScreenState extends State<OptimizationScreen> {
  bool _batterySaverEnabled = false;
  bool _loading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final enabled = await NativeService.isBatterySaverEnabled();
      final stats = await NativeService.getOptimizationStats();

      if (mounted) {
        setState(() {
          _batterySaverEnabled = enabled;
          _stats = stats;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleBatterySaver(bool value) async {
    try {
      await NativeService.setBatterySaverMode(value);
      setState(() => _batterySaverEnabled = value);
      if (mounted) {
        context.showSnack(
          value
              ? 'Modo ahorro activado (actualización cada 2 min)'
              : 'Modo normal (actualización cada 30s)',
        );
      }
      await _loadSettings();
    } catch (_) {}
  }

  Future<void> _invalidateCache() async {
    try {
      await NativeService.invalidateCache();
      if (mounted) context.showSnack('Cache limpiado correctamente');
      await _loadSettings();
    } catch (_) {
      if (mounted) context.showSnack('Error al limpiar cache', isError: true);
    }
  }

  Future<void> _forceCleanup() async {
    try {
      await NativeService.forceCleanup();
      if (mounted) context.showSnack('Limpieza completada');
      await _loadSettings();
    } catch (_) {
      if (mounted) context.showSnack('Error en limpieza', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            pinned: true,
            title: Text('Optimización'),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.speed_rounded,
                          color: AppColors.info, size: 24),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Optimiza el rendimiento y reduce el consumo de batería',
                          style: TextStyle(
                            color: AppColors.info,
                            fontSize: 14,
                            height: 1.4,
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
                  'MODO AHORRO DE BATERÍA',
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
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _batterySaverEnabled
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(
                            _batterySaverEnabled
                                ? Icons.battery_saver_rounded
                                : Icons.battery_std_rounded,
                            size: 24,
                            color: _batterySaverEnabled
                                ? AppColors.success
                                : AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reducir frecuencia de tracking',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _batterySaverEnabled
                                    ? 'Actualización cada 2 minutos'
                                    : 'Actualización cada 30 segundos',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _batterySaverEnabled,
                          onChanged: _toggleBatterySaver,
                        ),
                      ],
                    ),
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
                  'ESTADÍSTICAS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            if (_stats != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: [
                          _statRow(
                            icon: Icons.storage_rounded,
                            label: 'Base de datos',
                            value: '${_stats!['databaseSizeMB']} MB',
                          ),
                          const Divider(height: AppSpacing.lg),
                          _statRow(
                            icon: Icons.cached_rounded,
                            label: 'Cache',
                            value: '${_stats!['cacheSizeKB']} KB',
                          ),
                          const Divider(height: AppSpacing.lg),
                          _statRow(
                            icon: Icons.bar_chart_rounded,
                            label: 'Registros de uso',
                            value: '${_stats!['usageRecordCount']}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Text(
                  'MANTENIMIENTO',
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
                child: Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Icon(Icons.delete_sweep_rounded,
                              color: AppColors.warning, size: 20),
                        ),
                        title: const Text('Limpiar cache'),
                        subtitle: const Text('Elimina datos temporales'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _invalidateCache,
                      ),
                      const Divider(height: 1, indent: 72),
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Icon(Icons.cleaning_services_rounded,
                              color: AppColors.error, size: 20),
                        ),
                        title: const Text('Limpieza profunda'),
                        subtitle: const Text('Elimina datos antiguos'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _forceCleanup,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ],
      ),
    );
  }

  Widget _statRow(
      {required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
