import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  static const _ch = MethodChannel('app.restriction/config');

  List<Map<String, dynamic>> _backups = [];
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _loading = true);
    try {
      final backups =
          await _ch.invokeMethod<List<dynamic>>('listBackups') ?? [];
      if (mounted) {
        setState(() {
          _backups = backups.map((e) => Map<String, dynamic>.from(e)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createBackup() async {
    setState(() => _creating = true);
    try {
      final success =
          await _ch.invokeMethod<bool>('createManualBackup') ?? false;
      if (success && mounted) {
        _showSnack('Backup creado correctamente');
        await _loadBackups();
      }
    } catch (e) {
      if (mounted) _showSnack('Error al crear backup', isError: true);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _restoreBackup(Map<String, dynamic> backup) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Restaurar backup'),
        content: Text(
          '¿Restaurar configuración del ${backup['formattedDate']}?\n\n'
          'Esto agregará ${backup['restrictionCount']} restricciones.\n'
          'Las existentes no se eliminarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final result = await _ch.invokeMethod<Map<dynamic, dynamic>>(
          'restoreBackup', backup['path']);
      if (result == null || !mounted) return;

      final imported = result['imported'] as int? ?? 0;
      final skipped = result['skipped'] as int? ?? 0;

      if (imported > 0) {
        _showSnack(
            'Restaurado: $imported restricciones${skipped > 0 ? ' ($skipped ya existían)' : ''}');
      } else {
        _showSnack('Todas las restricciones ya existen', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Error al restaurar backup', isError: true);
    }
  }

  Future<void> _deleteBackup(Map<String, dynamic> backup) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar backup'),
        content: Text('¿Eliminar backup del ${backup['formattedDate']}?'),
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
      final success =
          await _ch.invokeMethod<bool>('deleteBackup', backup['path']) ?? false;
      if (success && mounted) {
        _showSnack('Backup eliminado');
        await _loadBackups();
      }
    } catch (e) {
      if (mounted) _showSnack('Error al eliminar backup', isError: true);
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
            title: const Text('Backups',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _infoCard(colorScheme),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: FilledButton.icon(
                onPressed: _creating ? null : _createBackup,
                icon: _creating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.backup_rounded),
                label: Text(_creating ? 'Creando...' : 'Crear backup manual'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'BACKUPS DISPONIBLES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white38,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_backups.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.backup_rounded,
                          size: 64,
                          color: colorScheme.primary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'Sin backups',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Los backups automáticos se crean\ncada día a las 3:00 AM',
                        style: TextStyle(
                            fontSize: 14, color: colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemCount: _backups.length,
                itemBuilder: (_, i) => _backupCard(_backups[i], colorScheme),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        border: Border.all(color: colorScheme.primary),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: colorScheme.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backups automáticos',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Se crean automáticamente cada día y se mantienen los últimos 7 backups',
                  style: TextStyle(
                      color: colorScheme.primary, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _backupCard(Map<String, dynamic> backup, ColorScheme colorScheme) {
    final isAuto = backup['isAutomatic'] as bool? ?? false;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _restoreBackup(backup),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        isAuto
                            ? Icons.schedule_rounded
                            : Icons.touch_app_rounded,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              backup['formattedDate'] ?? '',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            if (isAuto) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'AUTO',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${backup['restrictionCount']} restricciones • ${backup['formattedSize']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        color: colorScheme.error),
                    onPressed: () => _deleteBackup(backup),
                    tooltip: 'Eliminar',
                  ),
                ],
              ),
              if (backup['hasAdminMode'] == true) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded,
                          size: 14, color: colorScheme.secondary),
                      const SizedBox(width: 6),
                      Text(
                        'Incluye modo administrador',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
