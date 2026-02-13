import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:timelock/extensions/context_extensions.dart';
import 'package:timelock/screens/export_import_screen.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  bool _loadingUpdates = true;
  bool _installing = false;
  String? _updatesError;
  String _currentVersion = '';
  int _currentVersionCode = 0;
  List<ReleaseInfo> _releases = [];
  bool _showPrerelease = false;
  bool _showBackupReminder = true;

  _StatusViewData get _statusData {
    if (_installing) {
      return _StatusViewData(
        icon: Icons.downloading_rounded,
        title: 'Instalación en curso',
        description:
            'Se está preparando la instalación. Android abrirá el instalador al terminar.',
        color: AppColors.info,
      );
    }
    if (_updatesError != null) {
      return _StatusViewData(
        icon: Icons.cloud_off_rounded,
        title: 'No se pudo actualizar',
        description: _updatesError!,
        color: AppColors.warning,
      );
    }
    if (_loadingUpdates) {
      return _StatusViewData(
        icon: Icons.sync_rounded,
        title: 'Verificando actualizaciones',
        description: 'Buscando versiones disponibles...',
        color: AppColors.info,
      );
    }
    final latest = _latestRelease;
    if (latest == null) {
      return _StatusViewData(
        icon: Icons.info_outline_rounded,
        title: 'Sin versiones disponibles',
        description: _showPrerelease
            ? 'No hay versiones disponibles para instalar.'
            : 'No hay versiones estables disponibles. Activa Beta para ver versiones de prueba.',
        color: AppColors.textTertiary,
      );
    }
    if (_isNewer(latest)) {
      return _StatusViewData(
        icon: Icons.system_update_alt_rounded,
        title: 'Actualización disponible',
        description:
            'Hay una versión más reciente que la instalada. Puedes instalarla desde esta pantalla.',
        color: AppColors.success,
      );
    }
    return _StatusViewData(
      icon: Icons.verified_rounded,
      title: 'App actualizada',
      description: 'Ya tienes la versión más reciente de este listado.',
      color: AppColors.success,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUpdatePrefs();
    _loadInstalledVersion();
    _loadUpdates();
  }

  Future<void> _loadUpdatePrefs() async {
    try {
      final prefs = await NativeService.getSharedPreferences('update_prefs');
      final saved = prefs?['showBackupReminder'];
      if (saved is bool && mounted) {
        setState(() => _showBackupReminder = saved);
      }
    } catch (_) {
      // Keep default if prefs cannot be read.
    }
  }

  Future<void> _loadInstalledVersion() async {
    try {
      final version = await NativeService.getAppVersion();
      if (mounted) {
        setState(() {
          _currentVersion = version['versionName']?.toString() ?? '';
          _currentVersionCode = (version['versionCode'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUpdates() async {
    setState(() {
      _loadingUpdates = true;
      _updatesError = null;
    });
    try {
      final releasesRaw = await NativeService.getReleases();
      final releases = releasesRaw
          .map((r) => ReleaseInfo.fromMap(r))
          .where((r) => r.apkAsset != null)
          .toList()
        ..sort((a, b) => b.publishedAtDate.compareTo(a.publishedAtDate));
      if (mounted) {
        setState(() {
          _releases = releases;
          _loadingUpdates = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final message = _buildErrorMessage(
          e,
          fallback: 'Error al consultar actualizaciones',
        );
        setState(() {
          _updatesError = message;
          _loadingUpdates = false;
        });
      }
    }
  }

  ReleaseInfo? get _latestRelease {
    final visible = _visibleReleases;
    if (visible.isEmpty) return null;
    return visible.first;
  }

  List<ReleaseInfo> get _visibleReleases {
    if (_showPrerelease) return _releases;
    return _releases.where((r) => !r.prerelease).toList();
  }

  bool _isNewer(ReleaseInfo release) {
    final releaseCode = release.versionCode;
    if (releaseCode > 0) {
      return releaseCode > _currentVersionCode;
    }
    final current = _currentVersion.isEmpty ? '0.0.0' : _currentVersion;
    return compareVersions(release.versionTag, current) > 0;
  }

  bool _isCurrent(ReleaseInfo release) {
    final releaseCode = release.versionCode;
    if (releaseCode > 0) {
      return releaseCode == _currentVersionCode;
    }
    final current = _currentVersion.isEmpty ? '0.0.0' : _currentVersion;
    return compareVersions(release.versionTag, current) == 0;
  }

  bool _isOlder(ReleaseInfo release) {
    return !_isCurrent(release) && !_isNewer(release);
  }

  String _installLabelFor(ReleaseInfo release) {
    if (_isOlder(release)) return 'Descargar instalador';
    if (_isCurrent(release)) return 'Volver a instalar';
    if (_isNewer(release)) return 'Instalar actualización';
    return 'Instalar esta versión';
  }

  String _latestContextLabel(ReleaseInfo latest) {
    if (_showPrerelease) {
      return 'Más reciente (incluye Beta): ${latest.displayName}';
    }
    return 'Más reciente estable: ${latest.displayName}';
  }

  Future<void> _handleReleaseAction(ReleaseInfo release) async {
    if (_isCurrent(release)) {
      final choice = await _chooseCurrentVersionAction();
      if (choice == null) return;
      if (choice == 'download') {
        await _downloadRelease(release);
        return;
      }
    }
    final accepted = await _showBackupReminderDialog();
    if (!accepted) return;
    if (_isOlder(release)) {
      await _downloadRelease(release);
      return;
    }
    await _installRelease(release);
  }

  Future<String?> _chooseCurrentVersionAction() async {
    return await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Misma versión detectada'),
          content: const Text(
            'Puedes volver a instalar o descargar el archivo de instalación de esta misma versión.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('download'),
              child: const Text('Descargar instalador'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('reinstall'),
              child: const Text('Volver a instalar'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showBackupReminderDialog() async {
    if (!_showBackupReminder || !mounted) return true;
    bool dontShowAgain = false;

    final action = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Resguarda tus datos'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Antes de instalar, reinstalar o descargar una versión, '
                    'te recomendamos hacer un respaldo desde Exportar/Importar.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  CheckboxListTile(
                    value: dontShowAgain,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'No volver a mostrar',
                      style: TextStyle(fontSize: 12),
                    ),
                    onChanged: (value) {
                      setModalState(() => dontShowAgain = value ?? false);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop('cancel'),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop('open_backup'),
                  child: const Text('Exportar/Importar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop('continue'),
                  child: const Text('Continuar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (dontShowAgain) {
      await NativeService.saveSharedPreference({
        'prefsName': 'update_prefs',
        'key': 'showBackupReminder',
        'value': false,
      });
      if (mounted) setState(() => _showBackupReminder = false);
    }

    if (action == 'open_backup') {
      if (!mounted) return false;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ExportImportScreen()),
      );
      return false;
    }

    return action == 'continue';
  }

  Future<void> _installRelease(ReleaseInfo release) async {
    if (_installing) return;
    final apk = release.apkAsset;
    if (apk == null) return;
    final canInstall = await NativeService.canInstallPackages();
    if (!canInstall) {
      if (mounted) {
        context.showSnack(
          'Permite instalar apps desconocidas para continuar',
          isError: true,
        );
      }
      await NativeService.requestInstallPermission();
      return;
    }
    setState(() => _installing = true);
    try {
      final ok = await NativeService.downloadAndInstallApk(
        url: apk.url,
        shaUrl: release.shaAsset?.url,
      );
      if (mounted) {
        context.showSnack(
          ok
              ? 'Preparando instalación...'
              : 'No se pudo iniciar la instalación',
        );
      }
    } catch (e) {
      if (mounted) {
        context.showSnack(
          _buildErrorMessage(
            e,
            fallback: 'Error al instalar',
          ),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  Future<void> _downloadRelease(ReleaseInfo release) async {
    final apk = release.apkAsset;
    if (apk == null) return;
    try {
      final suggestedName = release.versionTag.isNotEmpty
          ? 'timelock-${release.versionTag}.apk'
          : apk.name;
      final ok = await NativeService.downloadApkOnly(
        url: apk.url,
        fileName: suggestedName,
      );
      if (!mounted) return;
      context.showSnack(
        ok
            ? 'Descarga iniciada. Revisa la notificación de descargas.'
            : 'No se pudo iniciar la descarga',
        isError: !ok,
      );
    } catch (e) {
      if (!mounted) return;
      context.showSnack(
        _buildErrorMessage(
          e,
          fallback: 'No se pudo descargar el archivo de instalación',
        ),
        isError: true,
      );
    }
  }

  void _showReleaseNotes(ReleaseInfo release) {
    final notes = release.body.trim();
    final child = SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notas de ${release.displayName}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: MarkdownBody(
                      data: notes.isNotEmpty
                          ? notes
                          : 'Esta versión no incluye notas publicadas.',
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(
                        Theme.of(context),
                      ).copyWith(
                        p: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                        listBullet: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    final reduce = MediaQuery.of(context).disableAnimations;
    if (!reduce) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => child,
      );
      return;
    }
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'release_notes',
      barrierColor: AppColors.background.withValues(alpha: 0.62),
      transitionDuration: Duration.zero,
      pageBuilder: (context, _, __) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
    );
  }

  String _buildErrorMessage(
    Object error, {
    required String fallback,
  }) {
    if (error is PlatformException) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: const Text('Actualizaciones'),
              actions: [
                Row(
                  children: [
                    Text(
                      'Beta',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    Switch(
                      value: _showPrerelease,
                      onChanged: (value) {
                        setState(() => _showPrerelease = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: _overviewBanner(),
              ),
            ),
            if (_loadingUpdates)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _updatesLoadingCard(),
                ),
              )
            else if (_updatesError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _updatesErrorCard(),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _latestReleaseCard(),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VERSIONES ANTERIORES',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Las versiones anteriores se descargan como archivo de instalación.',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _olderReleases(),
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

  Widget _overviewBanner() {
    final latest = _latestRelease;
    final data = _statusData;
    final versionLabel =
        _currentVersion.isNotEmpty ? _currentVersion : 'Desconocida';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    size: 18,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Versión actual',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    versionLabel,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  if (latest != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _latestContextLabel(latest),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (latest != null) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: FilledButton.tonalIcon(
                  onPressed:
                      _installing ? null : () => _handleReleaseAction(latest),
                  icon: _installing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_alt_rounded, size: 18),
                  label: Text(_installLabelFor(latest)),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: data.color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(data.icon, size: 14, color: data.color),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          data.title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: data.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      data.description,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _updatesLoadingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Verificando actualizaciones...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _updatesErrorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  color: AppColors.warning,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'No se pudieron cargar las actualizaciones',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _updatesError ?? 'Error al consultar actualizaciones',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.tonalIcon(
              onPressed: _loadUpdates,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _latestReleaseCard() {
    final latest = _latestRelease;
    if (latest == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            _showPrerelease
                ? 'No se encontraron versiones para instalar.'
                : 'No se encontraron versiones estables para instalar.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      );
    }
    final hasNotes = latest.body.trim().isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.system_update_alt_rounded,
                    size: 17,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest.displayName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        latest.hasPublishedDate
                            ? 'Publicado: ${latest.publishedDateLabel}'
                            : 'Versión sin fecha',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasNotes)
                  IconButton(
                    tooltip: 'Ver notas',
                    onPressed: () => _showReleaseNotes(latest),
                    icon: const Icon(Icons.description_outlined, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              latest.prerelease
                  ? 'Versión en pruebas.'
                  : 'Versión estable publicada.',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _olderReleases() {
    final visible = _visibleReleases;
    if (visible.length <= 1) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            _showPrerelease
                ? 'No hay versiones anteriores disponibles.'
                : 'No hay versiones estables anteriores disponibles.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return Column(
      children: visible.skip(1).map((release) {
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            release.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            release.hasPublishedDate
                                ? 'Publicado: ${release.publishedDateLabel}'
                                : 'Versión sin fecha',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ver notas',
                      onPressed: () => _showReleaseNotes(release),
                      icon: const Icon(Icons.description_outlined, size: 18),
                    ),
                    IconButton(
                      tooltip: _installLabelFor(release),
                      onPressed: _installing
                          ? null
                          : () => _handleReleaseAction(release),
                      icon: Icon(
                        _isOlder(release)
                            ? Icons.download_rounded
                            : Icons.system_update_alt_rounded,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ReleaseInfo {
  ReleaseInfo({
    required this.tagName,
    required this.name,
    required this.body,
    required this.publishedAt,
    required this.prerelease,
    required this.assets,
  });

  final String tagName;
  final String name;
  final String body;
  final String publishedAt;
  final bool prerelease;
  final List<ReleaseAsset> assets;

  String get displayName {
    if (name.isNotEmpty) return name;
    return tagName.isNotEmpty ? tagName : 'Versión';
  }

  String get versionTag => tagName.isNotEmpty ? tagName : name;

  DateTime get publishedAtDate {
    return DateTime.tryParse(publishedAt) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool get hasPublishedDate => publishedAtDate.millisecondsSinceEpoch > 0;

  String get publishedDateLabel {
    if (!hasPublishedDate) return '';
    final date = publishedAtDate.toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  int get versionCode {
    final match = RegExp(r'(\d{2})\.(\d{2})\.(\d+)').firstMatch(versionTag);
    if (match != null) {
      final major = int.tryParse(match.group(1)!) ?? 0;
      final minor = int.tryParse(match.group(2)!) ?? 0;
      final patch = int.tryParse(match.group(3)!) ?? 0;
      return (major * 10000) + (minor * 100) + patch;
    }
    return 0;
  }

  ReleaseAsset? get apkAsset {
    return assets
            .firstWhere(
              (a) => a.name.toLowerCase().endsWith('.apk'),
              orElse: () => ReleaseAsset.empty(),
            )
            .isEmpty
        ? null
        : assets.firstWhere((a) => a.name.toLowerCase().endsWith('.apk'));
  }

  ReleaseAsset? get shaAsset {
    final lower =
        assets.where((a) => a.name.toLowerCase().contains('sha256')).toList();
    if (lower.isEmpty) return null;
    return lower.first;
  }

  factory ReleaseInfo.fromMap(Map<String, dynamic> map) {
    final assetsRaw = (map['assets'] as List<dynamic>? ?? []);
    final assets = assetsRaw
        .map((e) => ReleaseAsset.fromMap(
            (e as Map).map((k, v) => MapEntry(k.toString(), v))))
        .toList();
    return ReleaseInfo(
      tagName: map['tagName']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      publishedAt: map['publishedAt']?.toString() ?? '',
      prerelease: map['prerelease'] == true,
      assets: assets,
    );
  }
}

class ReleaseAsset {
  ReleaseAsset({
    required this.name,
    required this.url,
    required this.size,
  });

  final String name;
  final String url;
  final int size;

  bool get isEmpty => name.isEmpty || url.isEmpty;

  factory ReleaseAsset.empty() => ReleaseAsset(name: '', url: '', size: 0);

  factory ReleaseAsset.fromMap(Map<String, dynamic> map) {
    return ReleaseAsset(
      name: map['name']?.toString() ?? '',
      url: map['url']?.toString() ?? '',
      size: (map['size'] as num?)?.toInt() ?? 0,
    );
  }
}

class _StatusViewData {
  const _StatusViewData({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
}

int compareVersions(String a, String b) {
  final aParts =
      RegExp(r'\d+').allMatches(a).map((m) => int.parse(m.group(0)!)).toList();
  final bParts =
      RegExp(r'\d+').allMatches(b).map((m) => int.parse(m.group(0)!)).toList();
  final maxLen = aParts.length > bParts.length ? aParts.length : bParts.length;
  for (int i = 0; i < maxLen; i++) {
    final av = i < aParts.length ? aParts[i] : 0;
    final bv = i < bParts.length ? bParts[i] : 0;
    if (av != bv) return av > bv ? 1 : -1;
  }
  return 0;
}
