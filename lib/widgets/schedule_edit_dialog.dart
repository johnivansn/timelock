import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/schedule_utils.dart';

class ScheduleEditDialog extends StatefulWidget {
  const ScheduleEditDialog({super.key, this.existing, this.existingSchedules});

  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>>? existingSchedules;

  @override
  State<ScheduleEditDialog> createState() => _ScheduleEditDialogState();
}

class _ScheduleEditDialogState extends State<ScheduleEditDialog> {
  late TimeOfDay _start;
  late TimeOfDay _end;
  late Set<int> _days;
  bool _loadingTemplates = false;
  List<Map<String, dynamic>> _templates = [];
  String? _selectedTemplateId;
  String _templateFilter = '';

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
    _loadTemplates();
  }

  bool get _valid => _days.isNotEmpty;

  Future<void> _loadTemplates() async {
    setState(() => _loadingTemplates = true);
    try {
      final raw = await NativeService.getBlockTemplates();
      final templates =
          raw.where((t) => (t['type'] ?? '').toString() == 'schedule').toList();
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
      final startHour = (map['startHour'] as num?)?.toInt();
      final startMinute = (map['startMinute'] as num?)?.toInt();
      final endHour = (map['endHour'] as num?)?.toInt();
      final endMinute = (map['endMinute'] as num?)?.toInt();
      final hasDays = map.containsKey('daysOfWeek');
      final days = (map['daysOfWeek'] as List<dynamic>? ?? [])
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((d) => d >= 1 && d <= 7)
          .toSet();
      final hasTime = startHour != null &&
          startMinute != null &&
          endHour != null &&
          endMinute != null;
      if (!hasTime && !hasDays) return;
      setState(() {
        if (hasTime) {
          _start = TimeOfDay(hour: startHour, minute: startMinute);
          _end = TimeOfDay(hour: endHour, minute: endMinute);
        }
        if (hasDays) {
          _days = days;
        }
      });
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filteredTemplates {
    final query = _templateFilter.trim().toLowerCase();
    if (query.isEmpty) return _templates;
    return _templates
        .where(
          (t) => (t['name']?.toString() ?? '').toLowerCase().contains(query),
        )
        .toList();
  }

  Future<void> _saveTemplate() async {
    final name = await _askTemplateName();
    if (name == null || name.trim().isEmpty) return;
    final payload = jsonEncode({
      'startHour': _start.hour,
      'startMinute': _start.minute,
      'endHour': _end.hour,
      'endMinute': _end.minute,
      'daysOfWeek': _days.toList(),
    });
    try {
      await NativeService.saveBlockTemplate({
        'name': name.trim(),
        'type': 'schedule',
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
                        'Etiquetas de horarios',
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: TextField(
                  onChanged: (value) => setState(() => _templateFilter = value),
                  decoration: InputDecoration(
                    hintText: 'Filtrar etiquetas',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceVariant.withValues(alpha: 0.4),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
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
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: _filteredTemplates.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: Text(
                            'Sin etiquetas para este filtro',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        itemCount: _filteredTemplates.length,
                        itemBuilder: (_, i) {
                          final t = _filteredTemplates[i];
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

  Future<void> _deleteTemplate(Map<String, dynamic> t) async {
    final id = t['id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      await NativeService.deleteBlockTemplate(id);
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

  int _templateUsageCount(Map<String, dynamic> t) {
    final schedules = widget.existingSchedules;
    if (schedules == null || schedules.isEmpty) return 0;
    final payload = t['payloadJson']?.toString();
    if (payload == null || payload.isEmpty) return 0;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final startHour = (map['startHour'] as num?)?.toInt();
      final startMinute = (map['startMinute'] as num?)?.toInt();
      final endHour = (map['endHour'] as num?)?.toInt();
      final endMinute = (map['endMinute'] as num?)?.toInt();
      final days = (map['daysOfWeek'] as List<dynamic>? ?? [])
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((d) => d >= 1 && d <= 7)
          .toList();
      if (startHour == null ||
          startMinute == null ||
          endHour == null ||
          endMinute == null) {
        return 0;
      }
      return schedules.where((s) {
        final sDays = (s['daysOfWeek'] as List<dynamic>? ?? [])
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .where((d) => d >= 1 && d <= 7)
            .toList();
        return s['startHour'] == startHour &&
            s['startMinute'] == startMinute &&
            s['endHour'] == endHour &&
            s['endMinute'] == endMinute &&
            _listEqualsInt(sDays, days);
      }).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing == null ? 'Nuevo horario' : 'Editar horario'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Define rangos y días para bloquear',
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
                title: 'Horario',
                child: Column(
                  children: [
                    _timeSegmentedBar(),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _sectionCard(
                title: 'Días',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _dayToggle('L', 2),
                        _dayToggle('M', 3),
                        _dayToggle('X', 4),
                        _dayToggle('J', 5),
                        _dayToggle('V', 6),
                        _dayToggle('S', 7),
                        _dayToggle('D', 1),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _inlineLabel('Etiquetas'),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      onChanged: (value) =>
                          setState(() => _templateFilter = value),
                      decoration: InputDecoration(
                        hintText: 'Filtrar etiquetas',
                        isDense: true,
                        filled: true,
                        fillColor:
                            AppColors.surfaceVariant.withValues(alpha: 0.4),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
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
                    const SizedBox(height: AppSpacing.xs),
                    if (_loadingTemplates)
                      const LinearProgressIndicator(minHeight: 2)
                    else if (_filteredTemplates.isNotEmpty)
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
                        items: _filteredTemplates
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
                    if (!_loadingTemplates && _filteredTemplates.isEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Text(
                          'No hay etiquetas para el filtro actual',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
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
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Si la hora final es menor, el bloqueo cruza medianoche.',
                style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
              ),
              if (!_valid)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Selecciona al menos un día',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.warning,
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
              ? () => Navigator.pop(
                    context,
                    ScheduleDraft(_start, _end, _days.toList()),
                  )
              : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _timeSegmentedBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 240;
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(999),
          ),
          child: isCompact
              ? Column(
                  children: [
                    _segment(
                      label: 'Inicio',
                      time: _start,
                      onTap: () => _pickTime(true),
                      selected: true,
                    ),
                    const SizedBox(height: 4),
                    _segment(
                      label: 'Fin',
                      time: _end,
                      onTap: () => _pickTime(false),
                      selected: true,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _segment(
                        label: 'Inicio',
                        time: _start,
                        onTap: () => _pickTime(true),
                        selected: true,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _segment(
                        label: 'Fin',
                        time: _end,
                        onTap: () => _pickTime(false),
                        selected: true,
                      ),
                    ),
                  ],
                ),
        );
      },
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

  Widget _inlineLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _segment({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
    required bool selected,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.surface.withValues(alpha: 0.9)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatTimeOfDay(time),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayToggle(String label, int value) {
    final selected = _days.contains(value);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        setState(() {
          if (selected) {
            _days.remove(value);
          } else {
            _days.add(value);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.surfaceVariant.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.surfaceVariant,
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  bool _listEqualsInt(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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

class ScheduleDraft {
  ScheduleDraft(this.start, this.end, this.days);

  final TimeOfDay start;
  final TimeOfDay end;
  final List<int> days;
}
