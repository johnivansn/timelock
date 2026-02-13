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
  String _widgetThemeChoice = 'auto';
  String _overlayThemeChoice = 'auto';
  bool _reduceAnimations = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uiPrefs = await NativeService.getSharedPreferences('ui_prefs');
      if (mounted) {
        setState(() {
          final raw = uiPrefs?['theme_choice']?.toString();
          final widgetRaw = uiPrefs?['widget_theme_choice']?.toString();
          final overlayRaw = uiPrefs?['overlay_theme_choice']?.toString();
          _themeChoice = (raw == 'light' || raw == 'dark' || raw == 'auto')
              ? raw!
              : 'dark';
          _widgetThemeChoice = (widgetRaw == 'light' ||
                  widgetRaw == 'dark' ||
                  widgetRaw == 'auto')
              ? widgetRaw!
              : _themeChoice;
          _overlayThemeChoice = (overlayRaw == 'light' ||
                  overlayRaw == 'dark' ||
                  overlayRaw == 'auto')
              ? overlayRaw!
              : _themeChoice;
          _reduceAnimations = uiPrefs?['reduce_animations'] == true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _autoHint() {
    return 'Automático (según sistema)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: [
                          _themeSelectorRow(
                            icon: Icons.phone_android_rounded,
                            title: 'Tema de la app',
                            subtitle: _themeChoice == 'auto'
                                ? _autoHint()
                                : 'Selección manual',
                            value: _themeChoice,
                            onChanged: (value) async {
                              setState(() => _themeChoice = value);
                              await AppSettings.update(themeChoice: value);
                              if (_widgetThemeChoice == 'auto') {
                                await NativeService.refreshWidgetsNow();
                              }
                              if (_overlayThemeChoice == 'auto') {
                                await NativeService.notifyOverlayThemeChanged();
                              }
                              if (!mounted) return;
                              this.context.showSnack('Tema de app actualizado');
                            },
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _themeSelectorRow(
                            icon: Icons.widgets_rounded,
                            title: 'Tema de widgets',
                            subtitle: _widgetThemeChoice == 'auto'
                                ? _autoHint()
                                : 'Selección manual',
                            value: _widgetThemeChoice,
                            onChanged: (value) async {
                              setState(() => _widgetThemeChoice = value);
                              await AppSettings.update(
                                  widgetThemeChoice: value);
                              await NativeService.refreshWidgetsNow();
                              if (!mounted) return;
                              this
                                  .context
                                  .showSnack('Tema de widgets actualizado');
                            },
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _themeSelectorRow(
                            icon: Icons.shield_rounded,
                            title: 'Tema de bloqueo',
                            subtitle: _overlayThemeChoice == 'auto'
                                ? _autoHint()
                                : 'Selección manual',
                            value: _overlayThemeChoice,
                            onChanged: (value) async {
                              setState(() => _overlayThemeChoice = value);
                              await AppSettings.update(
                                  overlayThemeChoice: value);
                              await NativeService.notifyOverlayThemeChanged();
                              if (!mounted) return;
                              this
                                  .context
                                  .showSnack('Tema de bloqueo actualizado');
                            },
                          ),
                        ],
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
                          if (!mounted) return;
                          this.context.showSnack(
                                value
                                    ? 'Animaciones reducidas'
                                    : 'Animaciones normales',
                              );
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

  Widget _themeSelectorRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required Future<void> Function(String value) onChanged,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 320;
        final dropdown = DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.surfaceVariant.withValues(alpha: 0.4),
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
            DropdownMenuItem(value: 'auto', child: Text('Automático')),
            DropdownMenuItem(value: 'light', child: Text('Claro')),
            DropdownMenuItem(value: 'dark', child: Text('Oscuro')),
          ],
          onChanged: (next) async {
            if (next == null) return;
            await onChanged(next);
          },
        );
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              subtitle,
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
                      color: AppColors.info.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(icon, color: AppColors.info, size: 18),
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
              child: Icon(icon, color: AppColors.info, size: 18),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: info),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(width: 180, child: dropdown),
          ],
        );
      },
    );
  }
}
