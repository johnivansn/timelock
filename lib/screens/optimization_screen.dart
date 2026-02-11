import 'package:flutter/material.dart';
import 'package:timelock/extensions/context_extensions.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/app_utils.dart';
import 'package:timelock/utils/app_settings.dart';

class OptimizationScreen extends StatefulWidget {
  OptimizationScreen({super.key});

  @override
  State<OptimizationScreen> createState() => _OptimizationScreenState();
}

class _OptimizationScreenState extends State<OptimizationScreen> {
  bool _batterySaverEnabled = false;
  bool _batteryAutoEnabled = false;
  int _batteryAutoThreshold = 25;
  int? _batteryLevel;
  bool _loading = true;
  Map<String, dynamic>? _stats;
  int _memoryClassMb = 0;
  double _iconCacheLimitMb = 0;
  int _iconPrefetchCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final enabled = await NativeService.isBatterySaverEnabled();
      final prefs =
          await NativeService.getSharedPreferences('battery_prefs');
      final memoryClass = await NativeService.getMemoryClass();
      final batteryLevel = await NativeService.getBatteryLevel();
      final stats = await NativeService.getOptimizationStats();
      final autoEnabled = prefs?['battery_auto_enabled'] == true;
      final threshold =
          (prefs?['battery_auto_threshold'] as num?)?.toInt() ?? 25;

      if (mounted) {
        setState(() {
          _batterySaverEnabled = enabled;
          _batteryAutoEnabled = autoEnabled;
          _batteryAutoThreshold = threshold.clamp(5, 80);
          _batteryLevel = batteryLevel;
          final autoActive = autoEnabled &&
              batteryLevel != null &&
              batteryLevel <= _batteryAutoThreshold;
          final effectivePowerSave = enabled || autoActive;
          _memoryClassMb = memoryClass;
          _iconCacheLimitMb = AppUtils.computeIconCacheLimitMb(
            memoryClassMb: memoryClass,
            powerSave: effectivePowerSave,
          );
          _iconPrefetchCount = AppUtils.computeIconPrefetchCount(
            screenWidth: MediaQuery.of(context).size.width,
            memoryClassMb: memoryClass,
            powerSave: effectivePowerSave,
          );
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
      await AppSettings.load();
      await _loadSettings();
    } catch (_) {}
  }

  Future<void> _toggleAutoBattery(bool value) async {
    try {
      await NativeService.saveSharedPreference({
        'prefsName': 'battery_prefs',
        'key': 'battery_auto_enabled',
        'value': value,
      });
      if (mounted) {
        setState(() => _batteryAutoEnabled = value);
        context.showSnack(
          value
              ? 'Ahorro automático activado'
              : 'Ahorro automático desactivado',
        );
      }
      await _loadSettings();
    } catch (_) {}
  }

  Future<void> _setAutoThreshold(int value) async {
    try {
      await NativeService.saveSharedPreference({
        'prefsName': 'battery_prefs',
        'key': 'battery_auto_threshold',
        'value': value,
      });
      if (mounted) {
        setState(() => _batteryAutoThreshold = value);
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
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
          SliverAppBar(
            pinned: true,
            title: Text('Optimización'),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.speed_rounded,
                          color: AppColors.info, size: 18),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Optimiza el rendimiento y reduce el consumo de batería',
                          style: TextStyle(
                            color: AppColors.info,
                            fontSize: 12,
                            height: 1.4,
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
                  'MODO AHORRO DE BATERÍA',
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
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 320;
                        final content = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reducir frecuencia de tracking',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: AppSpacing.xs),
                            Text(
                              _batterySaverEnabled
                                  ? 'Actualización cada 2 minutos'
                                  : 'Actualización cada 30 segundos',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        );
                        if (isCompact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
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
                                      size: 20,
                                      color: _batterySaverEnabled
                                          ? AppColors.success
                                          : AppColors.textTertiary,
                                    ),
                                  ),
                                  SizedBox(width: AppSpacing.sm),
                                  Expanded(child: content),
                                ],
                              ),
                              SizedBox(height: AppSpacing.sm),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Switch(
                                  value: _batterySaverEnabled,
                                  onChanged: _toggleBatterySaver,
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
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
                                size: 20,
                                color: _batterySaverEnabled
                                    ? AppColors.success
                                    : AppColors.textTertiary,
                              ),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(child: content),
                            Switch(
                              value: _batterySaverEnabled,
                              onChanged: _toggleBatterySaver,
                            ),
                          ],
                        );
                      },
                    ),
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
                  'AHORRO AUTOMÁTICO',
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
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final statusText = _batteryLevel != null
                            ? 'Batería actual: ${_batteryLevel}%'
                            : 'Batería actual: desconocida';
                        final header = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activar automáticamente',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: AppSpacing.xs),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        );
                        final toggle = Switch(
                          value: _batteryAutoEnabled,
                          onChanged: _toggleAutoBattery,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: header),
                                toggle,
                              ],
                            ),
                            SizedBox(height: AppSpacing.sm),
                            _autoThresholdRow(),
                          ],
                        );
                      },
                    ),
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
                  'ESTADÍSTICAS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            if (_stats != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: [
                          _statRow(
                            icon: Icons.storage_rounded,
                            label: 'Base de datos',
                            value: '${_stats!['databaseSizeMB']} MB',
                          ),
                          Divider(height: AppSpacing.md),
                          _statRow(
                            icon: Icons.cached_rounded,
                            label: 'Cache',
                            value: '${_stats!['cacheSizeKB']} KB',
                          ),
                          Divider(height: AppSpacing.md),
                          _statRow(
                            icon: Icons.memory_rounded,
                            label: 'RAM clase',
                            value: '$_memoryClassMb MB',
                          ),
                          Divider(height: AppSpacing.md),
                          _statRow(
                            icon: Icons.folder_special_rounded,
                            label: 'Límite cache íconos',
                            value: '${_iconCacheLimitMb.toStringAsFixed(1)} MB',
                          ),
                          Divider(height: AppSpacing.md),
                          _statRow(
                            icon: Icons.download_for_offline_rounded,
                            label: 'Prefetch íconos',
                            value: '$_iconPrefetchCount',
                          ),
                          Divider(height: AppSpacing.md),
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
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Text(
                  'MANTENIMIENTO',
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
                child: Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(Icons.delete_sweep_rounded,
                              color: AppColors.warning, size: 18),
                        ),
                        title: Text(
                          'Limpiar cache',
                          style: TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          'Elimina datos temporales',
                          style: TextStyle(fontSize: 11),
                        ),
                        trailing:
                            Icon(Icons.chevron_right_rounded, size: 18),
                        onTap: _invalidateCache,
                        visualDensity: VisualDensity.compact,
                      ),
                      Divider(height: 1, indent: 56),
                      ListTile(
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(Icons.cleaning_services_rounded,
                              color: AppColors.error, size: 18),
                        ),
                        title: Text(
                          'Limpieza profunda',
                          style: TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          'Elimina datos antiguos',
                          style: TextStyle(fontSize: 11),
                        ),
                        trailing:
                            Icon(Icons.chevron_right_rounded, size: 18),
                        onTap: _forceCleanup,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
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

  Widget _statRow(
      {required IconData icon, required String label, required String value}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 280;
        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.textSecondary, size: 18),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          );
        }
        return Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 18),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _autoThresholdRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Umbral de batería',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Text(
              '$_batteryAutoThreshold%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Slider(
                value: _batteryAutoThreshold.toDouble(),
                min: 5,
                max: 80,
                divisions: 15,
                onChanged: _batteryAutoEnabled
                    ? (value) => _setAutoThreshold(value.round())
                    : null,
              ),
            ),
          ],
        ),
        Text(
          _batteryAutoEnabled
              ? 'Se activará cuando la batería esté ≤ $_batteryAutoThreshold%'
              : 'Activa el ahorro automático para usar este umbral',
          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

