import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FirstLaunchDialog {
  static const _ch = MethodChannel('app.restriction/config');

  static Future<void> checkAndShow(BuildContext context) async {
    try {
      final backupInfo = await _ch
          .invokeMethod<Map<dynamic, dynamic>>('checkBackupOnFirstLaunch');
      if (backupInfo == null || !(backupInfo['exists'] as bool? ?? false)) {
        return;
      }

      if (!context.mounted) return;

      final restore = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _BackupFoundDialog(backupInfo: backupInfo),
      );

      if (restore == true && context.mounted) {
        await _restoreBackup(context, backupInfo['path'] as String);
      }
    } catch (_) {}
  }

  static Future<void> _restoreBackup(BuildContext context, String path) async {
    try {
      final result =
          await _ch.invokeMethod<Map<dynamic, dynamic>>('restoreBackup', path);
      if (result == null || !context.mounted) return;

      final imported = result['imported'] as int? ?? 0;
      final skipped = result['skipped'] as int? ?? 0;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Restaurado: $imported restricciones${skipped > 0 ? ' ($skipped ya existían)' : ''}',
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (_) {}
  }
}

class _BackupFoundDialog extends StatelessWidget {
  const _BackupFoundDialog({required this.backupInfo});

  final Map<dynamic, dynamic> backupInfo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.backup_rounded, color: colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          const Text('Backup encontrado'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Se encontró una configuración previa del ${backupInfo['formattedDate']}.',
            style: TextStyle(color: colorScheme.onSurface, fontSize: 15),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.apps_rounded, color: colorScheme.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  '${backupInfo['restrictionCount']} restricciones',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '¿Deseas restaurar tu configuración?',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Empezar de cero'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Restaurar'),
        ),
      ],
    );
  }
}
