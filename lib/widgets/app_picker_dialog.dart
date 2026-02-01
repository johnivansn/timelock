import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          color: const Color(0xFF1A1A2E),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            builder: (ctx, scroll) {
              return Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A3E),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Selecciona una app',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      onChanged: _filter,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Buscar...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search,
                            color: Colors.white38, size: 20),
                        filled: true,
                        fillColor: const Color(0xFF2A2A3E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : _filtered.isEmpty
                            ? Center(
                                child: Text(
                                  _query.isEmpty
                                      ? 'No hay apps disponibles'
                                      : 'Sin resultados',
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 14),
                                ),
                              )
                            : ListView.builder(
                                controller: scroll,
                                itemCount: _filtered.length,
                                itemBuilder: (_, i) => _appTile(_filtered[i]),
                              ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _appTile(Map<String, String> app) {
    return InkWell(
      onTap: () => Navigator.pop(context, app),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    (app['appName'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6C5CE7)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app['appName'] ?? '',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      app['packageName'] ?? '',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white38),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
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
