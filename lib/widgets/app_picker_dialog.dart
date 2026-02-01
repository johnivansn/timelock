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

  List<Map<String, String>> _apps = [];
  List<Map<String, String>> _filtered = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final raw =
          await _ch.invokeMethod<List<dynamic>>('getInstalledApps') ?? [];
      final apps = raw
          .map((e) => Map<String, String>.from(e))
          .where((a) => !widget.excludedPackages.contains(a['packageName']))
          .toList();
      apps.sortBy((a) => (a['appName'] ?? '').toLowerCase());
      if (mounted) {
        setState(() {
          _apps = apps;
          _filtered = apps;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter(String q) {
    setState(() {
      _query = q;
      _filtered = q.isEmpty
          ? _apps
          : _apps
              .where((a) =>
                  (a['appName'] ?? '').toLowerCase().contains(q.toLowerCase()))
              .toList();
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
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 3))
                  : _filtered.isEmpty
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
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _appTile(_filtered[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appTile(Map<String, String> app) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => Navigator.pop(context, app),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text(
                    (app['appName'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app['appName'] ?? '',
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
                      app['packageName'] ?? '',
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
}

extension _ListSort<T> on List<T> {
  void sortBy(Comparable Function(T) key) {
    sort((a, b) => key(a).compareTo(key(b)));
  }
}
