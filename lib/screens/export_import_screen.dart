import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timelock/extensions/context_extensions.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'dart:convert';

class ExportImportScreen extends StatefulWidget {
  ExportImportScreen({super.key});

  @override
  State<ExportImportScreen> createState() => _ExportImportScreenState();
}

class _ExportImportScreenState extends State<ExportImportScreen> {
  bool _exporting = false;
  bool _importing = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final json = await NativeService.exportConfig();
      if (json != null && mounted) {
        setState(() => _exporting = false);
        await Clipboard.setData(ClipboardData(text: json));
        if (mounted) context.showSnack('Configuración copiada al portapapeles');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _exporting = false);
        context.showSnack('Error al exportar', isError: true);
      }
    }
  }

  Future<void> _pasteAndImport() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (mounted) context.showSnack('Portapapeles vacío', isError: true);
      return;
    }

    try {
      jsonDecode(text);
    } catch (_) {
      if (mounted) context.showSnack('JSON inválido', isError: true);
      return;
    }

    setState(() => _importing = true);
    try {
      final res = await NativeService.importConfig(text);
      if (!mounted) return;
      setState(() => _importing = false);

      final success = res['success'] as bool? ?? false;
      if (success) {
        final imported = res['imported'] as int? ?? 0;
        final skipped = res['skipped'] as int? ?? 0;
        if (skipped > 0) {
          context.showSnack('Importadas: $imported | Ya existían: $skipped');
        } else {
          context.showSnack(
              'Importadas $imported restricción${imported == 1 ? '' : 'es'}');
        }
      } else {
        context.showSnack(res['error'] as String? ?? 'Error desconocido',
            isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _importing = false);
        context.showSnack('Error al importar', isError: true);
      }
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
              title: Text('Export / Import'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 320;
                    final text = Text(
                      'Exporta y comparte tu configuración entre dispositivos o como respaldo',
                      style: TextStyle(
                        color: AppColors.info,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    );
                    return Container(
                      padding: EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        border: Border.all(color: AppColors.info, width: 1),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: isCompact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.sync_rounded,
                                        color: AppColors.info, size: 18),
                                    SizedBox(width: AppSpacing.sm),
                                    Expanded(child: text),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.sync_rounded,
                                    color: AppColors.info, size: 18),
                                SizedBox(width: AppSpacing.sm),
                                Expanded(child: text),
                              ],
                            ),
                    );
                  },
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
                  'EXPORTAR',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isCompact = constraints.maxWidth < 320;
                            final text = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Exportar configuración',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Genera JSON con tus restricciones',
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
                                          color: AppColors.primary
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.md),
                                        ),
                                        child: Icon(
                                          Icons.upload_rounded,
                                          size: 20,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      SizedBox(width: AppSpacing.sm),
                                      Expanded(child: text),
                                    ],
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
                                    color: AppColors.primary
                                        .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: Icon(
                                    Icons.upload_rounded,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(width: AppSpacing.sm),
                                Expanded(child: text),
                              ],
                            );
                          },
                        ),
                        SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: FilledButton.icon(
                            onPressed: _exporting ? null : _export,
                            icon: _exporting
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(Icons.share_rounded, size: 18),
                            label: Text(
                                _exporting ? 'Exportando...' : 'Compartir'),
                          ),
                        ),
                      ],
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
                  'IMPORTAR',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isCompact = constraints.maxWidth < 320;
                            final text = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Importar configuración',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Restaura desde JSON exportado',
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
                                          color: AppColors.success
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.md),
                                        ),
                                        child: Icon(
                                          Icons.download_rounded,
                                          size: 20,
                                          color: AppColors.success,
                                        ),
                                      ),
                                      SizedBox(width: AppSpacing.sm),
                                      Expanded(child: text),
                                    ],
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
                                    color: AppColors.success
                                        .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: Icon(
                                    Icons.download_rounded,
                                    size: 20,
                                    color: AppColors.success,
                                  ),
                                ),
                                SizedBox(width: AppSpacing.sm),
                                Expanded(child: text),
                              ],
                            );
                          },
                        ),
                        SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: FilledButton.icon(
                            onPressed: _importing ? null : _pasteAndImport,
                            icon: _importing
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(Icons.paste_rounded, size: 18),
                            label: Text(_importing
                                ? 'Importando...'
                                : 'Pegar del portapapeles'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor:
                                  AppColors.onColor(AppColors.success),
                            ),
                          ),
                        ),
                      ],
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
                  'NOTAS',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _noteItem(
                            'Las restricciones importadas no sobreescriben las existentes'),
                        SizedBox(height: AppSpacing.sm),
                        _noteItem(
                            'El modo administrador (PIN) no se exporta por seguridad'),
                        SizedBox(height: AppSpacing.sm),
                        _noteItem(
                            'Los contadores de uso diario no se exportan'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }

  Widget _noteItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded,
            color: AppColors.textTertiary, size: 16),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
