import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';

class AppPickerDialog extends StatefulWidget {
  const AppPickerDialog({super.key, required this.excludedPackages});

  final Set<String> excludedPackages;

  @override
  State<AppPickerDialog> createState() => _AppPickerDialogState();
}

class _AppPickerDialogState extends State<AppPickerDialog> {
  List<Map<String, dynamic>> _installedApps = [];
  List<Map<String, dynamic>> _systemApps = [];
  List<Map<String, dynamic>> _filteredInstalled = [];
  List<Map<String, dynamic>> _filteredSystem = [];
  bool _loading = true;
  String _query = '';
  bool _showSystem = false;
  final Map<String, Uint8List?> _iconCache = {};
  final Set<String> _iconLoading = {};

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      setState(() => _loading = true);

      final raw = await NativeService.getInstalledApps();

      if (!mounted) return;

      final allApps = raw
          .where((a) =>
              a.isNotEmpty &&
              !widget.excludedPackages.contains(a['packageName']))
          .toList();

      final installed = <Map<String, dynamic>>[];
      final system = <Map<String, dynamic>>[];

      for (final app in allApps) {
        if (app['isSystem'] == true) {
          system.add(app);
        } else {
          installed.add(app);
        }
      }

      installed.sort((a, b) => (a['appName'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['appName'] ?? '').toString().toLowerCase()));
      system.sort((a, b) => (a['appName'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['appName'] ?? '').toString().toLowerCase()));

      if (mounted) {
        setState(() {
          _installedApps = installed;
          _systemApps = system;
          _filteredInstalled = installed;
          _filteredSystem = [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter(String q) {
    setState(() {
      _query = q;
      if (q.isEmpty) {
        _filteredInstalled = _installedApps;
        _filteredSystem = _showSystem ? _systemApps : [];
      } else {
        final lowerQ = q.toLowerCase();
        _filteredInstalled = _installedApps
            .where((a) =>
                (a['appName'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(lowerQ) ||
                (a['packageName'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(lowerQ))
            .toList();
        _filteredSystem = _systemApps
            .where((a) =>
                (a['appName'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(lowerQ) ||
                (a['packageName'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(lowerQ))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Selecciona una app',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                onChanged: _filter,
                decoration: const InputDecoration(
                  hintText: 'Buscar apps...',
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                  contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!_loading && _systemApps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: CheckboxListTile(
                  value: _showSystem,
                  onChanged: (v) {
                    setState(() => _showSystem = v ?? false);
                    _filter(_query);
                  },
                  title: const Text(
                    'Mostrar apps del sistema',
                    style: TextStyle(fontSize: 12),
                  ),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xxl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(strokeWidth: 3),
                            SizedBox(height: AppSpacing.sm),
                            Text(
                              'Cargando apps...',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _filteredInstalled.isEmpty && _filteredSystem.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xxl),
                            child: Text(
                              _query.isEmpty
                                  ? 'No hay apps disponibles'
                                  : 'Sin resultados',
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg),
                          children: [
                            if (_filteredInstalled.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: AppSpacing.sm, bottom: AppSpacing.sm),
                                child: Text(
                                  'APPS INSTALADAS (${_filteredInstalled.length})',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textTertiary,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              ..._filteredInstalled.map((app) => _appTile(app)),
                            ],
                            if (_filteredSystem.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: AppSpacing.sm, bottom: AppSpacing.sm),
                                child: Text(
                                  'APPS DEL SISTEMA (${_filteredSystem.length})',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textTertiary,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              ..._filteredSystem.map((app) => _appTile(app)),
                            ],
                          ],
                        ),
            ),
            if (!_loading)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Total: ${_installedApps.length} instaladas + ${_systemApps.length} sistema',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _appTile(Map<String, dynamic> app) {
    final appName = (app['appName'] ?? app['packageName'] ?? '?').toString();
    final packageName = app['packageName'] as String?;
    final firstChar = appName.isNotEmpty ? appName[0].toUpperCase() : '?';
    final iconBytes = app['icon'] as Uint8List?;

    return InkWell(
      onTap: () => Navigator.pop(context, app),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.surfaceVariant, width: 1),
          ),
        ),
        child: Row(
          children: [
            _buildAppIcon(iconBytes, firstChar, packageName),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    appName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (app['packageName'] ?? '?').toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildAppIcon(
      Uint8List? iconBytes, String fallbackChar, String? packageName) {
    if (iconBytes != null && iconBytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.memory(
          iconBytes,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackIcon(fallbackChar),
        ),
      );
    }

    if (packageName != null && _iconCache.containsKey(packageName)) {
      final cachedIcon = _iconCache[packageName];
      if (cachedIcon != null && cachedIcon.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Image.memory(
            cachedIcon,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackIcon(fallbackChar),
          ),
        );
      }
    }

    if (packageName != null && !_iconLoading.contains(packageName)) {
      _iconLoading.add(packageName);
      NativeService.getAppIcon(packageName).then((bytes) {
        if (!mounted) return;
        setState(() {
          _iconCache[packageName] = bytes;
          _iconLoading.remove(packageName);
        });
      });
    }

    return _buildFallbackIcon(fallbackChar);
  }

  Widget _buildFallbackIcon(String char) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Center(
        child: Text(
          char,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
