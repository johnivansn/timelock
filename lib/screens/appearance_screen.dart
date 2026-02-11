import 'package:flutter/material.dart';
import 'package:timelock/extensions/context_extensions.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/app_settings.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  bool _loading = true;
  String _themeChoice = 'auto';
  bool _reduceAnimations = false;
  bool _batterySaverEnabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uiPrefs = await NativeService.getSharedPreferences('ui_prefs');
      final batterySaver = await NativeService.isBatterySaverEnabled();
      if (mounted) {
        setState(() {
          _themeChoice = uiPrefs?['theme_choice']?.toString() ?? 'auto';
          _reduceAnimations = uiPrefs?['reduce_animations'] == true;
          _batterySaverEnabled = batterySaver;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _autoHint() {
    return _batterySaverEnabled
        ? 'Automático (Calmo por ahorro)'
        : 'Automático (Clásico)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              pinned: true,
              title: Text('Apariencia'),
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
                    AppSpacing.xs,
                  ),
                  child: Text(
                    'TEMA DE COLOR',
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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 320;
                          final dropdown = DropdownButtonFormField<String>(
                            value: _themeChoice,
                            isExpanded: true,
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor:
                                  AppColors.surfaceVariant.withValues(alpha: 0.4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'auto', child: Text('Automático')),
                              DropdownMenuItem(
                                  value: 'classic',
                                  child: Text('Clásico oscuro')),
                              DropdownMenuItem(
                                  value: 'high_contrast',
                                  child: Text('Alto contraste')),
                              DropdownMenuItem(
                                  value: 'calm', child: Text('Calmo')),
                              DropdownMenuItem(
                                  value: 'forest', child: Text('Bosque')),
                              DropdownMenuItem(
                                  value: 'sunset', child: Text('Atardecer')),
                              DropdownMenuItem(
                                  value: 'mono', child: Text('Monocromo')),
                            ],
                            onChanged: (value) async {
                              if (value == null) return;
                              setState(() => _themeChoice = value);
                              await AppSettings.update(themeChoice: value);
                              if (mounted) {
                                context.showSnack('Tema actualizado');
                              }
                            },
                          );
                          final info = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tema',
                                style: TextStyle(fontSize: 13),
                              ),
                              Text(
                                _themeChoice == 'auto'
                                    ? _autoHint()
                                    : 'Selección manual',
                                style: const TextStyle(fontSize: 11),
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
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.info.withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(AppRadius.sm),
                                      ),
                                      child: Icon(
                                        Icons.palette_rounded,
                                        color: AppColors.info,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(child: info),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                dropdown,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Icon(Icons.palette_rounded,
                                    color: AppColors.info, size: 18),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(child: info),
                              const SizedBox(width: AppSpacing.sm),
                              SizedBox(width: 180, child: dropdown),
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
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xs,
                  ),
                  child: Text(
                    'MOVIMIENTO',
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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Card(
                    child: ListTile(
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(Icons.motion_photos_off_rounded,
                            color: AppColors.warning, size: 18),
                      ),
                      title: const Text(
                        'Reducir animaciones',
                        style: TextStyle(fontSize: 13),
                      ),
                      subtitle: const Text(
                        'Mejora fluidez en equipos modestos',
                        style: TextStyle(fontSize: 11),
                      ),
                      trailing: Switch(
                        value: _reduceAnimations,
                        onChanged: (value) async {
                          setState(() => _reduceAnimations = value);
                          await AppSettings.update(reduceAnimations: value);
                          if (mounted) {
                            context.showSnack(
                              value
                                  ? 'Animaciones reducidas'
                                  : 'Animaciones normales',
                            );
                          }
                        },
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxl),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
