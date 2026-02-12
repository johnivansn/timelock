import 'package:flutter/material.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/date_utils.dart';
import 'package:timelock/widgets/bottom_sheet_handle.dart';
import 'package:timelock/widgets/date_block_edit_dialog.dart';

class DateBlockEditorDialog extends StatefulWidget {
  const DateBlockEditorDialog({
    super.key,
    required this.appName,
    required this.packageName,
  });

  final String appName;
  final String packageName;

  @override
  State<DateBlockEditorDialog> createState() => _DateBlockEditorDialogState();
}

class _DateBlockEditorDialogState extends State<DateBlockEditorDialog> {
  bool _loading = true;
  List<Map<String, dynamic>> _blocks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await NativeService.getDateBlocks(widget.packageName);
      if (!mounted) return;
      setState(() {
        _blocks = raw;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addBlock() async {
    final draft = await _openEditor();
    if (draft == null) return;
    try {
      await NativeService.addDateBlock({
        'packageName': widget.packageName,
        'startDate': draft.startDate,
        'endDate': draft.endDate,
        'startHour': draft.startHour,
        'startMinute': draft.startMinute,
        'endHour': draft.endHour,
        'endMinute': draft.endMinute,
        'label': draft.label.isNotEmpty ? draft.label : null,
        'isEnabled': true,
      });
      await _load();
    } catch (_) {}
  }

  Future<void> _editBlock(Map<String, dynamic> block) async {
    final draft = await _openEditor(existing: block);
    if (draft == null) return;
    try {
      await NativeService.updateDateBlock({
        'id': block['id'],
        'startDate': draft.startDate,
        'endDate': draft.endDate,
        'startHour': draft.startHour,
        'startMinute': draft.startMinute,
        'endHour': draft.endHour,
        'endMinute': draft.endMinute,
        'label': draft.label.isNotEmpty ? draft.label : null,
        'isEnabled': block['isEnabled'] ?? true,
      });
      await _load();
    } catch (_) {}
  }

  Future<void> _toggleEnabled(Map<String, dynamic> block) async {
    final enabled = !(block['isEnabled'] as bool? ?? true);
    try {
      await NativeService.updateDateBlock({
        'id': block['id'],
        'isEnabled': enabled,
      });
      await _load();
    } catch (_) {}
  }

  Future<void> _deleteBlock(Map<String, dynamic> block) async {
    try {
      await NativeService.deleteDateBlock(block['id'] as String);
      await _load();
    } catch (_) {}
  }

  Future<DateBlockDraft?> _openEditor({Map<String, dynamic>? existing}) {
    return showDialog<DateBlockDraft>(
      context: context,
      builder: (_) => DateBlockEditDialog(
        existing: existing,
        existingBlocks: _blocks,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              const BottomSheetHandle(),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fechas de bloqueo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                          Text(
                            widget.appName,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ],
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
                child: SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: FilledButton.icon(
                    onPressed: _addBlock,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Agregar fecha'),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 3))
                    : _blocks.isEmpty
                        ? Center(
                            child: Text(
                              'Sin fechas configuradas',
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg),
                            itemCount: _blocks.length,
                            itemBuilder: (_, i) => _blockTile(_blocks[i]),
                          ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blockTile(Map<String, dynamic> b) {
    final enabled = b['isEnabled'] as bool? ?? true;
    final start = b['startDate']?.toString() ?? '';
    final end = b['endDate']?.toString() ?? '';
    final startHour = (b['startHour'] as num?)?.toInt() ?? 0;
    final startMinute = (b['startMinute'] as num?)?.toInt() ?? 0;
    final endHour = (b['endHour'] as num?)?.toInt() ?? 23;
    final endMinute = (b['endMinute'] as num?)?.toInt() ?? 59;
    final label = b['label']?.toString();
    final rangeText = formatDateTimeRangeLabel(
      start,
      end,
      startHour: startHour,
      startMinute: startMinute,
      endHour: endHour,
      endMinute: endMinute,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => _editBlock(b),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rangeText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (label?.isNotEmpty == true)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.info.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            label!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        'Bloqueo por fecha',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: (_) => _toggleEnabled(b),
              ),
              IconButton(
                onPressed: () => _deleteBlock(b),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.error,
                  backgroundColor: AppColors.surfaceVariant,
                  minimumSize: const Size(28, 28),
                  fixedSize: const Size(28, 28),
                  padding: const EdgeInsets.all(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
