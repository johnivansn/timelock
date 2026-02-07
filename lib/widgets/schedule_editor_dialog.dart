import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';

class ScheduleEditorDialog extends StatefulWidget {
  const ScheduleEditorDialog({
    super.key,
    required this.appName,
    required this.packageName,
    this.openTemplatePicker = false,
  });

  final String appName;
  final String packageName;
  final bool openTemplatePicker;

  @override
  State<ScheduleEditorDialog> createState() => _ScheduleEditorDialogState();
}

class _ScheduleEditorDialogState extends State<ScheduleEditorDialog> {
  bool _loading = true;
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _templates = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadTemplates();
  }

  Future<void> _load() async {
    try {
      final raw = await NativeService.getSchedules(widget.packageName);
      final normalized = raw.map(_normalizeSchedule).toList();
      if (!mounted) return;
      setState(() {
        _schedules = normalized;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTemplates() async {
    try {
      final prefs = await NativeService.getSharedPreferences('schedule_templates');
      final raw = prefs?['templates']?.toString();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _templates = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (_) {}

    if (mounted && widget.openTemplatePicker) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openTemplatePicker());
    }
  }

  Future<void> _saveTemplates() async {
    try {
      final json = jsonEncode(_templates);
      await NativeService.saveSharedPreference({
        'prefsName': 'schedule_templates',
        'key': 'templates',
        'value': json,
      });
    } catch (_) {}
  }

  Map<String, dynamic> _normalizeSchedule(Map<String, dynamic> s) {
    final days = (s['daysOfWeek'] as List<dynamic>? ?? [])
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .toList();
    final converted =
        days.contains(0) ? days.map((d) => d + 1).toList() : days;
    return {
      ...s,
      'daysOfWeek': converted.where((d) => d >= 1 && d <= 7).toList(),
    };
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

  Future<_ScheduleDraft?> _openEditor({Map<String, dynamic>? existing}) {
    return showDialog<_ScheduleDraft>(
      context: context,
      builder: (_) => _ScheduleEditDialog(
        existing: existing,
        onSaveTemplate: _saveTemplateFromDraft,
      ),
    );
  }

  Future<void> _saveTemplateFromDraft(_ScheduleDraft draft) async {
    final name = await _promptTemplateName();
    if (name == null || name.trim().isEmpty) return;

    final item = {
      'name': name.trim(),
      'startHour': draft.start.hour,
      'startMinute': draft.start.minute,
      'endHour': draft.end.hour,
      'endMinute': draft.end.minute,
      'daysOfWeek': draft.days,
    };
    setState(() {
      _templates.add(item);
    });
    await _saveTemplates();
  }

  Future<String?> _promptTemplateName() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Guardar etiqueta'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nombre de la etiqueta'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openTemplatePicker() async {
    if (_templates.isEmpty) return;
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplatePickerSheet(templates: _templates),
    );
    if (selected == null) return;
    final draft = _ScheduleDraft(
      TimeOfDay(
        hour: selected['startHour'] as int? ?? 8,
        minute: selected['startMinute'] as int? ?? 0,
      ),
      TimeOfDay(
        hour: selected['endHour'] as int? ?? 18,
        minute: selected['endMinute'] as int? ?? 0,
      ),
      (selected['daysOfWeek'] as List<dynamic>? ?? [])
          .map((d) => int.tryParse(d.toString()) ?? 0)
          .where((d) => d >= 1 && d <= 7)
          .toList(),
    );
    final created = await _openEditor(existing: {
      'startHour': draft.start.hour,
      'startMinute': draft.start.minute,
      'endHour': draft.end.hour,
      'endMinute': draft.end.minute,
      'daysOfWeek': draft.days,
    });
    if (created != null) {
      await NativeService.addSchedule({
        'packageName': widget.packageName,
        'startHour': created.start.hour,
        'startMinute': created.start.minute,
        'endHour': created.end.hour,
        'endMinute': created.end.minute,
        'daysOfWeek': created.days,
        'isEnabled': true,
      });
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Horarios de bloqueo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          widget.appName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                  onPressed: _addSchedule,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Agregar horario'),
                ),
              ),
            ),
            if (_templates.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                child: SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: _openTemplatePicker,
                    icon: const Icon(Icons.bookmark_outline_rounded, size: 16),
                    label: const Text('Usar etiqueta guardada'),
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
                      ? const Center(
                          child: Text(
                            'Sin horarios configurados',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 13,
                            ),
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
    final timeText = _formatTimeRange(
      s['startHour'] as int? ?? 0,
      s['startMinute'] as int? ?? 0,
      s['endHour'] as int? ?? 0,
      s['endMinute'] as int? ?? 0,
    );
    final dayText = _formatDays(days);

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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dayText,
                      style: const TextStyle(
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

  String _formatTimeRange(int sh, int sm, int eh, int em) {
    final start = _fmt(sh, sm);
    final end = _fmt(eh, em);
    if (eh * 60 + em <= sh * 60 + sm) {
      return '$start – $end (día sig.)';
    }
    return '$start – $end';
  }

  String _fmt(int h, int m) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _formatDays(List<int> days) {
    if (days.isEmpty) return 'Sin días';
    const labels = {
      1: 'D',
      2: 'L',
      3: 'M',
      4: 'X',
      5: 'J',
      6: 'V',
      7: 'S',
    };
    return days.map((d) => labels[d] ?? '?').join(' · ');
  }
}

class _ScheduleEditDialog extends StatefulWidget {
  const _ScheduleEditDialog({this.existing, this.onSaveTemplate});

  final Map<String, dynamic>? existing;
  final Future<void> Function(_ScheduleDraft draft)? onSaveTemplate;

  @override
  State<_ScheduleEditDialog> createState() => _ScheduleEditDialogState();
}

class _ScheduleEditDialogState extends State<_ScheduleEditDialog> {
  late TimeOfDay _start;
  late TimeOfDay _end;
  late Set<int> _days;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _start = TimeOfDay(
      hour: e?['startHour'] as int? ?? 8,
      minute: e?['startMinute'] as int? ?? 0,
    );
    _end = TimeOfDay(
      hour: e?['endHour'] as int? ?? 18,
      minute: e?['endMinute'] as int? ?? 0,
    );
    final days = (e?['daysOfWeek'] as List<dynamic>? ?? [2, 3, 4, 5, 6])
        .map((d) => int.tryParse(d.toString()) ?? 0)
        .where((d) => d >= 1 && d <= 7)
        .toSet();
    _days = days.isEmpty ? {2, 3, 4, 5, 6} : days;
  }

  bool get _valid => _days.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nuevo horario' : 'Editar horario'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _timeRow(
                label: 'Inicio',
                value: _start,
                onTap: () => _pickTime(true),
              ),
              const SizedBox(height: AppSpacing.sm),
              _timeRow(
                label: 'Fin',
                value: _end,
                onTap: () => _pickTime(false),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Días',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  _dayChip('L', 2),
                  _dayChip('M', 3),
                  _dayChip('X', 4),
                  _dayChip('J', 5),
                  _dayChip('V', 6),
                  _dayChip('S', 7),
                  _dayChip('D', 1),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Si la hora final es menor, el bloqueo cruza medianoche.',
                style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _valid
              ? () async {
                  if (widget.onSaveTemplate != null) {
                    await widget.onSaveTemplate!(
                      _ScheduleDraft(_start, _end, _days.toList()),
                    );
                  }
                }
              : null,
          child: const Text('Guardar etiqueta'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.pop(
                    context,
                    _ScheduleDraft(_start, _end, _days.toList()),
                  )
              : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _timeRow(
      {required String label,
      required TimeOfDay value,
      required VoidCallback onTap}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
        SizedBox(
          height: 40,
          child: TextButton(
            onPressed: onTap,
            child: Text(_fmt(value)),
          ),
        ),
      ],
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _dayChip(String label, int value) {
    final selected = _days.contains(value);
    return FilterChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      selected: selected,
      onSelected: (_) {
        setState(() {
          if (selected) {
            _days.remove(value);
          } else {
            _days.add(value);
          }
        });
      },
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }
}

class _ScheduleDraft {
  _ScheduleDraft(this.start, this.end, this.days);

  final TimeOfDay start;
  final TimeOfDay end;
  final List<int> days;
}

class _TemplatePickerSheet extends StatelessWidget {
  const _TemplatePickerSheet({required this.templates});

  final List<Map<String, dynamic>> templates;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const Text(
            'Etiquetas guardadas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: templates.length,
              itemBuilder: (_, i) {
                final t = templates[i];
                final name = (t['name'] ?? 'Etiqueta').toString();
                return ListTile(
                  leading: const Icon(Icons.bookmark_rounded, size: 18),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _templateSummary(t),
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () => Navigator.pop(context, t),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  String _templateSummary(Map<String, dynamic> t) {
    final sh = t['startHour'] as int? ?? 0;
    final sm = t['startMinute'] as int? ?? 0;
    final eh = t['endHour'] as int? ?? 0;
    final em = t['endMinute'] as int? ?? 0;
    final days = (t['daysOfWeek'] as List<dynamic>? ?? [])
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .where((d) => d >= 1 && d <= 7)
        .toList();
    return '${_fmt(sh, sm)} – ${_fmt(eh, em)} · ${_formatDays(days)}';
  }

  String _fmt(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  String _formatDays(List<int> days) {
    if (days.isEmpty) return 'Sin días';
    const labels = {
      1: 'D',
      2: 'L',
      3: 'M',
      4: 'X',
      5: 'J',
      6: 'V',
      7: 'S',
    };
    return days.map((d) => labels[d] ?? '?').join(' ');
  }
}
