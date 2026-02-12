import 'package:flutter/material.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/schedule_utils.dart';
import 'package:timelock/widgets/schedule_edit_dialog.dart';
import 'package:timelock/widgets/bottom_sheet_handle.dart';

class ScheduleEditorDialog extends StatefulWidget {
  const ScheduleEditorDialog({
    super.key,
    required this.appName,
    required this.packageName,
  });

  final String appName;
  final String packageName;

  @override
  State<ScheduleEditorDialog> createState() => _ScheduleEditorDialogState();
}

class _ScheduleEditorDialogState extends State<ScheduleEditorDialog> {
  bool _loading = true;
  List<Map<String, dynamic>> _schedules = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await NativeService.getSchedules(widget.packageName);
      final normalized = raw.map(normalizeScheduleDays).toList();
      if (!mounted) return;
      setState(() {
        _schedules = normalized;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addSchedule() async {
    final draft = await _openEditor();
    if (draft == null) return;
    try {
      await NativeService.addSchedule({
        'packageName': widget.packageName,
        'startHour': draft.start.hour,
        'startMinute': draft.start.minute,
        'endHour': draft.end.hour,
        'endMinute': draft.end.minute,
        'daysOfWeek': draft.days,
        'isEnabled': true,
      });
      await _load();
    } catch (_) {}
  }

  Future<void> _editSchedule(Map<String, dynamic> schedule) async {
    final draft = await _openEditor(existing: schedule);
    if (draft == null) return;
    try {
      await NativeService.updateSchedule({
        'id': schedule['id'],
        'startHour': draft.start.hour,
        'startMinute': draft.start.minute,
        'endHour': draft.end.hour,
        'endMinute': draft.end.minute,
        'daysOfWeek': draft.days,
        'isEnabled': schedule['isEnabled'] ?? true,
      });
      await _load();
    } catch (_) {}
  }

  Future<void> _toggleEnabled(Map<String, dynamic> schedule) async {
    final enabled = !(schedule['isEnabled'] as bool? ?? true);
    try {
      await NativeService.updateSchedule({
        'id': schedule['id'],
        'isEnabled': enabled,
      });
      await _load();
    } catch (_) {}
  }

  Future<void> _deleteSchedule(Map<String, dynamic> schedule) async {
    try {
      await NativeService.deleteSchedule(schedule['id'] as String);
      await _load();
    } catch (_) {}
  }

  Future<ScheduleDraft?> _openEditor({Map<String, dynamic>? existing}) {
    return showDialog<ScheduleDraft>(
      context: context,
      builder: (_) => ScheduleEditDialog(
        existing: existing,
        existingSchedules: _schedules,
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 260;
                    final title = Text(
                      'Horarios de bloqueo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    );
                    final subtitle = Text(
                      widget.appName,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    );
                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: title),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          subtitle,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [title, subtitle],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: FilledButton.icon(
                    onPressed: _addSchedule,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Agregar horario'),
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
                    : _schedules.isEmpty
                        ? Center(
                            child: Text(
                              'Sin horarios configurados',
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
                            itemCount: _schedules.length,
                            itemBuilder: (_, i) => _scheduleTile(_schedules[i]),
                          ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scheduleTile(Map<String, dynamic> s) {
    final enabled = s['isEnabled'] as bool? ?? true;
    final days = (s['daysOfWeek'] as List<dynamic>? ?? [])
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .where((d) => d >= 1 && d <= 7)
        .toList();
    final timeText = formatTimeRange(
      s['startHour'] as int? ?? 0,
      s['startMinute'] as int? ?? 0,
      s['endHour'] as int? ?? 0,
      s['endMinute'] as int? ?? 0,
    );
    final dayText = formatDays(days);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => _editSchedule(s),
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
                      timeText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dayText,
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
                onChanged: (_) => _toggleEnabled(s),
              ),
              IconButton(
                onPressed: () => _deleteSchedule(s),
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
