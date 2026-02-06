import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timelock/theme/app_theme.dart';

class AppPickerDialog extends StatefulWidget {
  const AppPickerDialog({super.key, required this.excludedPackages});

  final Set<String> excludedPackages;

  @override
  State<AppPickerDialog> createState() => _AppPickerDialogState();
}

class _AppPickerDialogState extends State<AppPickerDialog> {
  static const _ch = MethodChannel('app.restriction/config');
  static const String CHANNEL = 'app.restriction/config';

  List<Map<String, dynamic>> _allApps = [];
  List<Map<String, dynamic>> _installedApps = [];
  List<Map<String, dynamic>> _systemApps = [];
  List<Map<String, dynamic>> _filteredInstalled = [];
  List<Map<String, dynamic>> _filteredSystem = [];
  bool _loading = true;
  String _query = '';
  bool _showSystem = false;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final raw =
          await _ch.invokeMethod<List<dynamic>>('getInstalledApps') ?? [];

      final allApps = raw
          .map((e) {
            try {
              return Map<String, dynamic>.from(e as Map);
            } catch (ex) {
              return <String, dynamic>{};
            }
          })
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
          _allApps = allApps;
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
        _filteredInstalled = _installedApps
            .where((a) =>
                (a['appName'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(q.toLowerCase()) ||
                (a['packageName'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(q.toLowerCase()))
            .toList();
        _filteredSystem = _systemApps
            .where((a) =>
                (a['appName'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(q.toLowerCase()) ||
                (a['packageName'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(q.toLowerCase()))
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Selecciona una app',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
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
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                onChanged: _filter,
                decoration: const InputDecoration(
                  hintText: 'Buscar apps...',
                  prefixIcon: Icon(Icons.search_rounded, size: 22),
                  contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (!_loading && _systemApps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: CheckboxListTile(
                  value: _showSystem,
                  onChanged: (v) {
                    setState(() => _showSystem = v ?? false);
                    _filter(_query);
                  },
                  title: const Text('Mostrar apps del sistema'),
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
                      child: CircularProgressIndicator(strokeWidth: 3))
                  : _filteredInstalled.isEmpty && _filteredSystem.isEmpty
                      ? Center(
                          child: Text(
                            _query.isEmpty
                                ? 'No hay apps disponibles'
                                : 'Sin resultados',
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 15,
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
                                    top: AppSpacing.md, bottom: AppSpacing.sm),
                                child: Text(
                                  'APPS INSTALADAS (${_filteredInstalled.length})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textTertiary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              ..._filteredInstalled.map((app) => _appTile(app)),
                            ],
                            if (_filteredSystem.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: AppSpacing.lg, bottom: AppSpacing.sm),
                                child: Text(
                                  'APPS DEL SISTEMA (${_filteredSystem.length})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textTertiary,
                                    letterSpacing: 0.5,
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
                    fontSize: 12,
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
    final firstChar = appName.isNotEmpty ? appName[0].toUpperCase() : '?';
    final iconBytes = app['icon'] as Uint8List?;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => Navigator.pop(context, app),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              _buildAppIcon(iconBytes, firstChar),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (app['packageName'] ?? '?').toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppIcon(Uint8List? iconBytes, String fallbackChar) {
    if (iconBytes != null && iconBytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.memory(
          iconBytes,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackIcon(fallbackChar),
        ),
      );
    }
    return _buildFallbackIcon(fallbackChar);
  }

  Widget _buildFallbackIcon(String char) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Center(
        child: Text(
          char,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
