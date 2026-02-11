import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timelock/extensions/context_extensions.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  bool _loading = true;
  bool _installing = false;
  String? _error;
  String _currentVersion = '';
  int _currentVersionCode = 0;
  List<ReleaseInfo> _releases = [];
  bool _showPrerelease = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final version = await NativeService.getAppVersion();
      final releasesRaw = await NativeService.getReleases();
      final releases = releasesRaw
          .map((r) => ReleaseInfo.fromMap(r))
          .where((r) => r.apkAsset != null)
          .toList()
        ..sort((a, b) => b.publishedAtDate.compareTo(a.publishedAtDate));
      if (mounted) {
        setState(() {
          _currentVersion = version['versionName']?.toString() ?? '';
          _currentVersionCode =
              (version['versionCode'] as num?)?.toInt() ?? 0;
          _releases = releases;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final message = e is PlatformException && e.message != null
            ? e.message!
            : 'Error al consultar actualizaciones';
        setState(() {
          _error = message;
          _loading = false;
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
        context.showSnack(ok
            ? 'Descargando actualización...'
            : 'No se pudo iniciar la instalación');
      }
    } catch (_) {
      if (mounted) context.showSnack('Error al instalar', isError: true);
    } finally {
      if (mounted) setState(() => _installing = false);
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
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: _currentVersionCard(),
                ),
              ),
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
                  child: Text(
                    'VERSIONES ANTERIORES',
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

  Widget _currentVersionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.info_outline_rounded,
                  color: AppColors.info, size: 18),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Versión instalada',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currentVersion.isNotEmpty
                        ? '$_currentVersion (code $_currentVersionCode)'
                        : 'Desconocida',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _load,
              child: const Text('Actualizar'),
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
                ? 'No se encontraron releases con APK.'
                : 'No se encontraron releases estables con APK.',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ),
      );
    }
    final hasSha = latest.shaAsset != null;
    final isNewer = _isNewer(latest);
    final isCurrent = _isCurrent(latest);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isNewer
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.system_update_alt_rounded,
                    size: 18,
                    color: isNewer ? AppColors.success : AppColors.textTertiary,
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
                        latest.publishedAt.isNotEmpty
                            ? 'Publicado: ${latest.publishedAt}'
                            : 'Release sin fecha',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (latest.prerelease)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Beta',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                if (latest.prerelease) const SizedBox(width: AppSpacing.xs),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Actual',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                if (isCurrent) const SizedBox(width: AppSpacing.xs),
                if (isNewer)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Nuevo',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hasSha
                  ? 'Verificación SHA256 disponible'
                  : 'Sin verificación SHA256 publicada',
              style: TextStyle(
                fontSize: 11,
                color: hasSha ? AppColors.textSecondary : AppColors.warning,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton.icon(
                onPressed:
                    _installing ? null : () => _installRelease(latest),
                icon: _installing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(isNewer ? 'Instalar actualización' : 'Reinstalar'),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Nota: Android puede bloquear el downgrade. '
              'Para volver a una versión anterior podrías necesitar desinstalar.',
              style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
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
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ),
      );
    }
    return Column(
      children: visible.skip(1).map((release) {
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ListTile(
            title: Text(
              release.displayName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              release.publishedAt.isNotEmpty
                  ? 'Publicado: ${release.publishedAt}'
                  : 'Release sin fecha',
              style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
            ),
            trailing: TextButton(
              onPressed: _installing ? null : () => _installRelease(release),
              child: const Text('Instalar'),
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
    return tagName.isNotEmpty ? tagName : 'Release';
  }

  String get versionTag => tagName.isNotEmpty ? tagName : name;

  DateTime get publishedAtDate {
    return DateTime.tryParse(publishedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  int get versionCode {
    final match = RegExp(r'(\\d{2})\\.(\\d{2})\\.(\\d+)').firstMatch(versionTag);
    if (match != null) {
      final major = int.tryParse(match.group(1)!) ?? 0;
      final minor = int.tryParse(match.group(2)!) ?? 0;
      final patch = int.tryParse(match.group(3)!) ?? 0;
      return (major * 10000) + (minor * 100) + patch;
    }
    return 0;
  }

  ReleaseAsset? get apkAsset {
    return assets.firstWhere(
      (a) => a.name.toLowerCase().endsWith('.apk'),
      orElse: () => ReleaseAsset.empty(),
    ).isEmpty
        ? null
        : assets.firstWhere((a) => a.name.toLowerCase().endsWith('.apk'));
  }

  ReleaseAsset? get shaAsset {
    final lower = assets
        .where((a) => a.name.toLowerCase().contains('sha256'))
        .toList();
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
