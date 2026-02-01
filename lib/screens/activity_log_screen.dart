import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  static const _ch = MethodChannel('app.restriction/config');

  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _filter = 'all';
  String _searchQuery = '';

  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final logs =
          await _ch.invokeMethod<List<dynamic>>('getActivityLogs') ?? [];
      if (mounted) {
        setState(() {
          _logs = logs.map((e) => Map<String, dynamic>.from(e)).toList();
          _applyFilters();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    var result = _logs;

    if (_filter != 'all') {
      final now = DateTime.now();
      final cutoff = _filter == 'today'
          ? DateTime(now.year, now.month, now.day)
          : _filter == 'week'
              ? now.subtract(const Duration(days: 7))
              : now.subtract(const Duration(days: 30));

      result = result.where((log) {
        final timestamp = log['timestamp'] as int;
        return DateTime.fromMillisecondsSinceEpoch(timestamp).isAfter(cutoff);
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((log) {
        final appName = (log['appName'] as String? ?? '').toLowerCase();
        final details = (log['details'] as String? ?? '').toLowerCase();
        return appName.contains(query) || details.contains(query);
      }).toList();
    }

    setState(() => _filtered = result);
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Limpiar historial'),
        content: const Text('¿Eliminar todos los registros de actividad?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _ch.invokeMethod('clearActivityLogs');
      if (mounted) {
        _showSnack('Historial limpiado');
        await _loadLogs();
      }
    } catch (e) {
      if (mounted) _showSnack('Error al limpiar historial', isError: true);
    }
  }

  Future<void> _exportLogs() async {
    try {
      final csv = await _ch.invokeMethod<String>('exportActivityLogs');
      if (csv != null && mounted) {
        await Clipboard.setData(ClipboardData(text: csv));
        _showSnack('CSV copiado al portapapeles');
      }
    } catch (e) {
      if (mounted) _showSnack('Error al exportar logs', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            pinned: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Historial',
                style: TextStyle(fontWeight: FontWeight.w600)),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  if (value == 'export') _exportLogs();
                  if (value == 'clear') _clearLogs();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.download_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Exportar CSV'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Limpiar historial'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  _applyFilters();
                },
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _filterChips(colorScheme),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filtered.isEmpty)
            SliverFillRemaining(child: _emptyState(colorScheme))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList.separated(
                itemCount: _filtered.length,
                itemBuilder: (_, i) => _logCard(_filtered[i], colorScheme),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChips(ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('Todos', 'all', colorScheme),
          const SizedBox(width: 8),
          _filterChip('Hoy', 'today', colorScheme),
          const SizedBox(width: 8),
          _filterChip('Última semana', 'week', colorScheme),
          const SizedBox(width: 8),
          _filterChip('Último mes', 'month', colorScheme),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, ColorScheme colorScheme) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _filter = value);
        _applyFilters();
      },
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.primary.withValues(alpha: 0.2),
      checkmarkColor: colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _emptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded,
                size: 64, color: colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Sin actividad',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No se encontraron resultados'
                  : 'Aún no hay registros de actividad',
              style:
                  TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _logCard(Map<String, dynamic> log, ColorScheme colorScheme) {
    final eventType = log['eventType'] as String;
    final timestamp = log['timestamp'] as int;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final appName = log['appName'] as String?;
    final details = log['details'] as String;

    final icon = _getIconForEvent(eventType);
    final color = _getColorForEvent(eventType, colorScheme);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(icon, color: color, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (appName != null) ...[
                  Text(
                    appName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  details,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatTimestamp(date),
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForEvent(String eventType) {
    switch (eventType) {
      case 'app_blocked':
        return Icons.lock_rounded;
      case 'app_unblocked':
        return Icons.lock_open_rounded;
      case 'quota_changed':
        return Icons.edit_rounded;
      case 'restriction_added':
        return Icons.add_circle_rounded;
      case 'restriction_removed':
        return Icons.remove_circle_rounded;
      case 'wifi_updated':
        return Icons.wifi_rounded;
      case 'pin_changed':
        return Icons.key_rounded;
      case 'admin_enabled':
      case 'admin_disabled':
        return Icons.shield_rounded;
      case 'backup_created':
      case 'backup_restored':
        return Icons.backup_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _getColorForEvent(String eventType, ColorScheme colorScheme) {
    switch (eventType) {
      case 'app_blocked':
        return colorScheme.error;
      case 'app_unblocked':
        return colorScheme.secondary;
      case 'quota_changed':
      case 'wifi_updated':
        return const Color(0xFFF39C12);
      case 'restriction_added':
        return colorScheme.primary;
      case 'restriction_removed':
        return colorScheme.error;
      case 'pin_changed':
      case 'admin_enabled':
      case 'admin_disabled':
        return colorScheme.primary;
      case 'backup_created':
      case 'backup_restored':
        return colorScheme.secondary;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    final timeStr = DateFormat('HH:mm').format(date);

    if (dateOnly == today) {
      return 'Hoy $timeStr';
    } else if (dateOnly == yesterday) {
      return 'Ayer $timeStr';
    } else {
      return _dateFormat.format(date);
    }
  }
}
