import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/date_utils.dart';

class DateBlockEditDialog extends StatefulWidget {
  const DateBlockEditDialog({
    super.key,
    this.existing,
    this.existingBlocks,
  });

  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>>? existingBlocks;

  @override
  State<DateBlockEditDialog> createState() => _DateBlockEditDialogState();
}

class _DateBlockEditDialogState extends State<DateBlockEditDialog> {
  DateTime? _start;
  DateTime? _end;
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 59);
  late final TextEditingController _labelController;
  bool _loadingTemplates = false;
  List<Map<String, dynamic>> _templates = [];
  String? _selectedTemplateId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _start = parseDate(e['startDate']?.toString() ?? '');
      _end = parseDate(e['endDate']?.toString() ?? '');
      final startHour = (e['startHour'] as num?)?.toInt() ?? 0;
      final startMinute = (e['startMinute'] as num?)?.toInt() ?? 0;
      final endHour = (e['endHour'] as num?)?.toInt() ?? 23;
      final endMinute = (e['endMinute'] as num?)?.toInt() ?? 59;
      _startTime = TimeOfDay(hour: startHour, minute: startMinute);
      _endTime = TimeOfDay(hour: endHour, minute: endMinute);
    }
    _labelController =
        TextEditingController(text: e?['label']?.toString() ?? '');
    _loadTemplates();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  bool get _valid {
    if (_start == null || _end == null) return false;
    final startDate = _start!;
    final endDate = _end!;
    if (endDate.isBefore(startDate)) return false;
    if (_isSameDate(startDate, endDate)) {
      final startMinutes = _startTime.hour * 60 + _startTime.minute;
      final endMinutes = _endTime.hour * 60 + _endTime.minute;
      if (endMinutes <= startMinutes) return false;
    }
    return true;
  }

  String _summary() {
    if (_start == null || _end == null) return 'Selecciona un rango';
    return formatDateTimeRangeLabel(
      formatDate(_start!),
      formatDate(_end!),
      startHour: _startTime.hour,
      startMinute: _startTime.minute,
      endHour: _endTime.hour,
      endMinute: _endTime.minute,
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initialStart = _start ?? now;
    final initialEnd = _end ?? now.add(const Duration(days: 1));

    final start = await showDatePicker(
      context: context,
      initialDate: initialStart,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('es', 'ES'),
    );
    if (start == null) return;
    if (!mounted) return;

    final end = await showDatePicker(
      context: context,
      initialDate: initialEnd.isBefore(start) ? start : initialEnd,
      firstDate: start,
      lastDate: DateTime(now.year + 5),
      locale: const Locale('es', 'ES'),
    );
    if (end == null) return;
    if (!mounted) return;

    setState(() {
      _start = start;
      _end = end;
    });
  }

  Future<void> _loadTemplates() async {
    setState(() => _loadingTemplates = true);
    try {
      final raw = await NativeService.getBlockTemplates();
      final templates =
          raw.where((t) => (t['type'] ?? '').toString() == 'date').toList();
      if (!mounted) return;
      setState(() {
        _templates = templates;
        _loadingTemplates = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTemplates = false);
    }
  }

  Future<void> _applyTemplate(String id) async {
    final template = _templates.firstWhere(
      (t) => t['id'] == id,
      orElse: () => {},
    );
    if (template.isEmpty) return;
    final payload = template['payloadJson']?.toString();
    if (payload == null || payload.isEmpty) return;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final start = parseDate(map['startDate']?.toString() ?? '');
      final end = parseDate(map['endDate']?.toString() ?? '');
      final startHour = (map['startHour'] as num?)?.toInt() ?? 0;
      final startMinute = (map['startMinute'] as num?)?.toInt() ?? 0;
      final endHour = (map['endHour'] as num?)?.toInt() ?? 23;
      final endMinute = (map['endMinute'] as num?)?.toInt() ?? 59;
      if (start == null || end == null) return;
      setState(() {
        _start = start;
        _end = end;
        _startTime = TimeOfDay(hour: startHour, minute: startMinute);
        _endTime = TimeOfDay(hour: endHour, minute: endMinute);
        if (_labelController.text.trim().isEmpty) {
          _labelController.text = template['name']?.toString() ?? '';
        }
      });
    } catch (_) {}
  }

  Future<void> _saveTemplate() async {
    if (!_valid) return;
    final name = await _askTemplateName();
    if (name == null || name.trim().isEmpty) return;
    final payload = jsonEncode({
      'startDate': formatDate(_start!),
      'endDate': formatDate(_end!),
      'startHour': _startTime.hour,
      'startMinute': _startTime.minute,
      'endHour': _endTime.hour,
      'endMinute': _endTime.minute,
    });
    try {
      await NativeService.saveBlockTemplate({
        'name': name.trim(),
        'type': 'date',
        'payloadJson': payload,
      });
      await _loadTemplates();
    } catch (_) {}
  }

  Future<String?> _askTemplateName() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Guardar etiqueta'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Nombre de la etiqueta',
            isDense: true,
            filled: true,
            fillColor: AppColors.surfaceVariant.withValues(alpha: 0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing == null
              ? 'Nuevo bloqueo por fecha'
              : 'Editar bloqueo por fecha'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Selecciona un rango de fechas',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sectionCard(
                title: 'Rango',
                child: Column(
                  children: [
                    _rangeButton(),
                    const SizedBox(height: AppSpacing.sm),
                    _timeRow(),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _labelController,
                      decoration: InputDecoration(
                        hintText: 'Etiqueta (opcional)',
                        isDense: true,
                        filled: true,
                        fillColor:
                            AppColors.surfaceVariant.withValues(alpha: 0.4),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(
                            color: AppColors.surfaceVariant,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(
                            color: AppColors.surfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_loadingTemplates)
                      const LinearProgressIndicator(minHeight: 2)
                    else if (_templates.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: _selectedTemplateId,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor:
                              AppColors.surfaceVariant.withValues(alpha: 0.4),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(
                              color: AppColors.surfaceVariant,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(
                              color: AppColors.surfaceVariant,
                            ),
                          ),
                        ),
                        hint: const Text('Usar etiqueta'),
                        items: _templates
                            .map(
                              (t) => DropdownMenuItem<String>(
                                value: t['id']?.toString(),
                                child:
                                    Text(t['name']?.toString() ?? 'Etiqueta'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedTemplateId = value);
                          _applyTemplate(value);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saveTemplate,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                  label: const Text('Guardar como etiqueta'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed:
                      _templates.isEmpty ? null : () => _manageTemplates(),
                  icon: const Icon(Icons.bookmarks_outlined, size: 16),
                  label: const Text('Gestionar etiquetas'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onColor(AppColors.primary),
          ),
          onPressed: _valid
              ? () {
                  Navigator.pop(
                    context,
                    DateBlockDraft(
                      formatDate(_start!),
                      formatDate(_end!),
                      _startTime.hour,
                      _startTime.minute,
                      _endTime.hour,
                      _endTime.minute,
                      _labelController.text.trim(),
                    ),
                  );
                }
              : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }

  Widget _rangeButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _pickRange,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.surfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _summary(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.edit_calendar_outlined,
                size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _timeRow() {
    return Row(
      children: [
        Expanded(
          child: _timeButton(
            label: 'Inicio',
            time: _startTime,
            onTap: _pickStartTime,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _timeButton(
            label: 'Fin',
            time: _endTime,
            onTap: _pickEndTime,
          ),
        ),
      ],
    );
  }

  Widget _timeButton({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.surfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '$label ${formatTimeLabel(time.hour, time.minute)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'Hora de inicio',
    );
    if (picked == null) return;
    setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      helpText: 'Hora de fin',
    );
    if (picked == null) return;
    setState(() => _endTime = picked);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _manageTemplates() {
    _showBottomSheet(
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Etiquetas de fechas',
                        style: TextStyle(
                          fontSize: 14,
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
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  itemCount: _templates.length,
                  itemBuilder: (_, i) {
                    final t = _templates[i];
                    return _templateTile(t);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showBottomSheet({required Widget child}) {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (!reduce) {
      return showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => child,
      );
    }
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'sheet',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (context, _, __) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
    );
  }

  Widget _templateTile(Map<String, dynamic> t) {
    final name = t['name']?.toString() ?? 'Etiqueta';
    final count = _templateUsageCount(t);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.bookmark_rounded,
                  size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (count > 0)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            IconButton(
              onPressed: () => _renameTemplate(t),
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.textSecondary,
            ),
            IconButton(
              onPressed: () => _confirmDeleteTemplate(t),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: AppColors.error,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameTemplate(Map<String, dynamic> t) async {
    final current = t['name']?.toString() ?? '';
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar etiqueta'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Nombre de la etiqueta',
            isDense: true,
            filled: true,
            fillColor: AppColors.surfaceVariant.withValues(alpha: 0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
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
    if (name == null || name.trim().isEmpty) return;
    try {
      await NativeService.saveBlockTemplate({
        'id': t['id'],
        'name': name.trim(),
        'type': t['type'],
        'payloadJson': t['payloadJson'],
      });
      await _loadTemplates();
    } catch (_) {}
  }

  Future<void> _confirmDeleteTemplate(Map<String, dynamic> t) async {
    final name = t['name']?.toString() ?? 'Etiqueta';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar etiqueta'),
        content: Text('¿Eliminar "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _deleteTemplate(t);
  }

  Future<void> _deleteTemplate(Map<String, dynamic> t) async {
    final id = t['id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      await NativeService.deleteBlockTemplate(id);
      await _loadTemplates();
    } catch (_) {}
  }

  int _templateUsageCount(Map<String, dynamic> t) {
    final blocks = widget.existingBlocks;
    if (blocks == null || blocks.isEmpty) return 0;
    final payload = t['payloadJson']?.toString();
    if (payload == null || payload.isEmpty) return 0;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final start = map['startDate']?.toString();
      final end = map['endDate']?.toString();
      final startHour = (map['startHour'] as num?)?.toInt() ?? 0;
      final startMinute = (map['startMinute'] as num?)?.toInt() ?? 0;
      final endHour = (map['endHour'] as num?)?.toInt() ?? 23;
      final endMinute = (map['endMinute'] as num?)?.toInt() ?? 59;
      if (start == null || end == null) return 0;
      return blocks.where((b) {
        final bStart = b['startDate']?.toString();
        final bEnd = b['endDate']?.toString();
        final bStartHour = (b['startHour'] as num?)?.toInt() ?? 0;
        final bStartMinute = (b['startMinute'] as num?)?.toInt() ?? 0;
        final bEndHour = (b['endHour'] as num?)?.toInt() ?? 23;
        final bEndMinute = (b['endMinute'] as num?)?.toInt() ?? 59;
        return bStart == start &&
            bEnd == end &&
            bStartHour == startHour &&
            bStartMinute == startMinute &&
            bEndHour == endHour &&
            bEndMinute == endMinute;
      }).length;
    } catch (_) {
      return 0;
    }
  }
}

class DateBlockDraft {
  DateBlockDraft(
    this.startDate,
    this.endDate,
    this.startHour,
    this.startMinute,
    this.endHour,
    this.endMinute,
    this.label,
  );

  final String startDate;
  final String endDate;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final String label;
}
