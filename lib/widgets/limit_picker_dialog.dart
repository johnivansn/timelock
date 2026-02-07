import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/app_utils.dart';

class LimitPickerDialog extends StatefulWidget {
  const LimitPickerDialog({
    super.key,
    required this.appName,
    this.initial,
    this.fullScreen = false,
    this.useEditLayoutForCreate = false,
  });

  final String appName;
  final Map<String, dynamic>? initial;
  final bool fullScreen;
  final bool useEditLayoutForCreate;

  @override
  State<LimitPickerDialog> createState() => _LimitPickerDialogState();
}

class _LimitPickerDialogState extends State<LimitPickerDialog> {
  late String _limitType;
  late String _dailyMode;
  late int _dailyMinutes;
  late Map<int, int> _dailyQuotas;
  late int _weeklyMinutes;
  late int _weeklyResetDay;
  late final TextEditingController _weeklyController;
  late final TextEditingController _dailyMinutesController;
  bool _loadingSchedules = false;
  List<Map<String, dynamic>> _schedules = [];
  bool _schedulesChanged = false;
  bool _dirty = false;
  static const double _stickyBarHeight = 68;
  final Set<String> _deletedScheduleIds = {};
  final Set<String> _updatedScheduleIds = {};
  int _localScheduleCounter = 0;
  bool _inactiveFirst = false;
  final Map<int, TextEditingController> _dayControllers = {};
  final FocusNode _dailyMinutesFocus = FocusNode();
  final Map<int, FocusNode> _dayFocusNodes = {};
  late String _initialLimitType;
  late String _initialDailyMode;
  late int _initialDailyMinutes;
  late Map<int, int> _initialDailyQuotas;
  late int _initialWeeklyMinutes;
  late int _initialWeeklyResetDay;
  final Map<String, Map<String, dynamic>> _originalSchedulesById = {};

  @override
  void initState() {
    super.initState();
    final init = widget.initial ?? {};
    _limitType = (init['limitType'] as String?) ?? 'daily';
    _dailyMode = (init['dailyMode'] as String?) ?? 'same';
    _dailyMinutes = (init['dailyQuotaMinutes'] as int?) ?? 30;
    _weeklyMinutes = (init['weeklyQuotaMinutes'] as int?) ?? 300;
    _weeklyResetDay = (init['weeklyResetDay'] as int?) ?? 2;
    _weeklyController =
        TextEditingController(text: _weeklyMinutes.toString());
    _dailyMinutesController = TextEditingController(
        text: _dailyMinutes > 0 ? _dailyMinutes.toString() : '');
    _dailyQuotas = _parseDailyQuotas(init['dailyQuotas']) ??
        {2: _dailyMinutes, 3: _dailyMinutes, 4: _dailyMinutes, 5: _dailyMinutes, 6: _dailyMinutes};
    for (var day = 1; day <= 7; day++) {
      final value = _dailyQuotas[day] ?? 0;
      _dayControllers[day] =
          TextEditingController(text: value > 0 ? value.toString() : '');
      _dayFocusNodes[day] = FocusNode();
    }
    _dailyMinutesFocus.addListener(_handleDailyFocusChange);
    for (final entry in _dayFocusNodes.entries) {
      entry.value.addListener(() => _handleDayFocusChange(entry.key));
    }
    _initialLimitType = _limitType;
    _initialDailyMode = _dailyMode;
    _initialDailyMinutes = _dailyMinutes;
    _initialWeeklyMinutes = _weeklyMinutes;
    _initialWeeklyResetDay = _weeklyResetDay;
    _initialDailyQuotas = Map<int, int>.from(_dailyQuotas);
    if (_packageName != null) {
      _loadSchedules();
    }
  }

  @override
  void dispose() {
    _weeklyController.dispose();
    _dailyMinutesController.dispose();
    for (final c in _dayControllers.values) {
      c.dispose();
    }
    _dailyMinutesFocus.dispose();
    for (final f in _dayFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _handleDailyFocusChange() {
    if (_dailyMinutesFocus.hasFocus) return;
    final text = _dailyMinutesController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _dailyMinutes = 0;
        _recomputeDirty();
      });
    }
  }

  void _handleDayFocusChange(int day) {
    final node = _dayFocusNodes[day];
    if (node == null || node.hasFocus) return;
    final controller = _dayControllers[day];
    if (controller == null) return;
    final text = controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _dailyQuotas[day] = 0;
        _recomputeDirty();
      });
      return;
    }
    final n = int.tryParse(text) ?? 0;
    final clamped = n.clamp(1, 480);
    if (clamped.toString() != controller.text) {
      controller.text = clamped.toString();
      controller.selection =
          TextSelection.collapsed(offset: controller.text.length);
      setState(() {
        _dailyQuotas[day] = clamped;
        _recomputeDirty();
      });
    }
  }

  Map<int, int>? _parseDailyQuotas(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final map = <int, int>{};
      for (final pair in value.split(',')) {
        final parts = pair.split(':');
        if (parts.length != 2) continue;
        final day = int.tryParse(parts[0]);
        final minutes = int.tryParse(parts[1]);
        if (day == null || minutes == null) continue;
        map[day] = minutes;
      }
      return map;
    }
    if (value is Map) {
      final map = <int, int>{};
      value.forEach((k, v) {
        final day = int.tryParse(k.toString());
        final minutes = int.tryParse(v.toString());
        if (day == null || minutes == null) return;
        map[day] = minutes;
      });
      return map;
    }
    return null;
  }

  String? get _packageName {
    final value = widget.initial?['packageName'];
    if (value == null) return null;
    return value.toString();
  }

  Uint8List? get _iconBytes {
    final bytes = widget.initial?['iconBytes'];
    if (bytes is Uint8List && bytes.isNotEmpty) return bytes;
    return null;
  }

  Future<void> _loadSchedules() async {
    final pkg = _packageName;
    if (pkg == null) return;
    setState(() => _loadingSchedules = true);
    try {
      final raw = await NativeService.getSchedules(pkg);
      final normalized = raw.map(_normalizeSchedule).toList();
      if (!mounted) return;
      setState(() {
        _schedules = normalized;
        _loadingSchedules = false;
        _schedulesChanged = false;
        _deletedScheduleIds.clear();
        _updatedScheduleIds.clear();
        _sortSchedules();
        _originalSchedulesById
          ..clear()
          ..addEntries(
            normalized
                .where((s) => s['id'] != null)
                .map((s) => MapEntry(s['id'] as String,
                    Map<String, dynamic>.from(s))),
          );
        _recomputeDirty();
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSchedules = false);
    }
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
    final pkg = _packageName;
    if (pkg == null) return;
    final draft = await _openScheduleEditor();
    if (draft == null) return;
    setState(() {
      _schedules.add({
        'id': null,
        'localId': 'local-${_localScheduleCounter++}',
        'startHour': draft.start.hour,
        'startMinute': draft.start.minute,
        'endHour': draft.end.hour,
        'endMinute': draft.end.minute,
        'daysOfWeek': draft.days,
        'isEnabled': true,
      });
      _schedulesChanged = _isScheduleDirty();
      _dirty = _isLimitDirty();
    });
  }

  Future<void> _editSchedule(Map<String, dynamic> schedule) async {
    final draft = await _openScheduleEditor(existing: schedule);
    if (draft == null) return;
    setState(() {
      schedule['startHour'] = draft.start.hour;
      schedule['startMinute'] = draft.start.minute;
      schedule['endHour'] = draft.end.hour;
      schedule['endMinute'] = draft.end.minute;
      schedule['daysOfWeek'] = draft.days;
      final id = schedule['id'];
      if (id is String && id.isNotEmpty) {
        if (_scheduleEquals(_originalSchedulesById[id], schedule)) {
          _updatedScheduleIds.remove(id);
        } else {
          _updatedScheduleIds.add(id);
        }
      }
      _schedulesChanged = _isScheduleDirty();
      _dirty = _isLimitDirty();
    });
  }

  Future<void> _toggleEnabled(Map<String, dynamic> schedule) async {
    final enabled = !(schedule['isEnabled'] as bool? ?? true);
    setState(() {
      schedule['isEnabled'] = enabled;
      final id = schedule['id'];
      if (id is String && id.isNotEmpty) {
        if (_scheduleEquals(_originalSchedulesById[id], schedule)) {
          _updatedScheduleIds.remove(id);
        } else {
          _updatedScheduleIds.add(id);
        }
      }
      _schedulesChanged = _isScheduleDirty();
      _dirty = _isLimitDirty();
    });
  }

  Future<void> _deleteSchedule(Map<String, dynamic> schedule) async {
    setState(() {
      final id = schedule['id'];
      if (id is String && id.isNotEmpty) {
        _deletedScheduleIds.add(id);
        _updatedScheduleIds.remove(id);
      }
      _schedules.remove(schedule);
      _schedulesChanged = _isScheduleDirty();
      _dirty = _isLimitDirty();
    });
  }

  Future<_ScheduleDraft?> _openScheduleEditor(
      {Map<String, dynamic>? existing}) {
    return showDialog<_ScheduleDraft>(
      context: context,
      builder: (_) => _ScheduleEditDialog(existing: existing),
    );
  }

  Future<void> _confirmDelete() async {
    final pkg = _packageName;
    if (pkg == null) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar restricción'),
        content: const Text('¿Deseas eliminar esta restricción?'),
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
    if (result == true) {
      try {
        await NativeService.deleteRestriction(pkg);
        if (mounted) Navigator.pop(context, {'deleted': true});
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initial == null) {
      if (widget.useEditLayoutForCreate) {
        return _buildEditLayout(isCreate: true);
      }
      return _buildCreateLayout();
    }
    return _buildEditLayout(isCreate: false);
  }

  Widget _buildEditLayout({required bool isCreate}) {
    final showSave = isCreate || _isLimitDirty() || _isScheduleDirty();
    final canSave = _isLimitValid();
    final borderRadius = widget.fullScreen
        ? BorderRadius.circular(0)
        : const BorderRadius.vertical(top: Radius.circular(AppRadius.xl));
    return WillPopScope(
      onWillPop: _handleBack,
      child: Stack(
        children: [
          SafeArea(
            top: true,
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: _stickyBarHeight),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: borderRadius,
                ),
                child: Column(
                  children: [
                  if (!widget.fullScreen) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: 32,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          final allow = await _handleBack();
                          if (allow && mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      ),
                      Expanded(
                        child: Text(
                          widget.appName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isCreate && _packageName != null)
                        IconButton(
                          onPressed: _confirmDelete,
                          icon: const Icon(Icons.delete_outline_rounded),
                          color: AppColors.error,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _headerCard(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _sectionLabel('Tipo de límite'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _pillRow(
                    leftLabel: 'Diario',
                    rightLabel: 'Semanal',
                    leftSelected: _limitType == 'daily',
                    rightSelected: _limitType == 'weekly',
                    onLeft: () => setState(() {
                      _limitType = 'daily';
                      _recomputeDirty();
                    }),
                    onRight: () => setState(() {
                      _limitType = 'weekly';
                      _recomputeDirty();
                    }),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_limitType == 'daily') _dailyConfig(),
                if (_limitType == 'weekly') _weeklyConfig(),
                if (_packageName != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: _scheduleSection(),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: IgnorePointer(
              ignoring: !showSave,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                offset: showSave ? Offset.zero : const Offset(0, 0.25),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  opacity: showSave ? 1 : 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                        top: BorderSide(
                          color: AppColors.surfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: FilledButton(
                          onPressed: canSave ? _save : null,
                          child: Text(isCreate ? 'Crear' : 'Guardar cambios'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ),
        ),
      ],
      ),
    );
  }

  Future<bool> _handleBack() async {
    if (!(_isLimitDirty() || _isScheduleDirty())) return true;
    return await _confirmDiscard();
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Descartar cambios'),
        content: const Text('Tienes cambios sin guardar. ¿Deseas salir igual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildCreateLayout() {
    final borderRadius = widget.fullScreen
        ? BorderRadius.circular(0)
        : const BorderRadius.vertical(top: Radius.circular(AppRadius.xl));
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: borderRadius,
        ),
        child: Column(
          children: [
            if (!widget.fullScreen) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
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
                          'Límite de tiempo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          widget.appName,
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
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Diario'),
                      selected: _limitType == 'daily',
                      onSelected: (_) =>
                          setState(() => _limitType = 'daily'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Semanal'),
                      selected: _limitType == 'weekly',
                      onSelected: (_) =>
                          setState(() => _limitType = 'weekly'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_limitType == 'daily') _dailyConfigCreate(),
            if (_limitType == 'weekly') _weeklyConfigCreate(),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: _isLimitValid() ? _save : null,
                  child: const Text('Crear'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCard() {
    final used = _usageSummary();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B1B2D), Color(0xFF1A1A2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceVariant.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          _buildAppIcon(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.appName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  used,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppIcon() {
    final bytes = _iconBytes;
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(
          bytes,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.apps_rounded,
          color: AppColors.textTertiary, size: 24),
    );
  }

  Widget _dailyConfigCreate() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tipo de límite diario',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Mismo cada día'),
                  selected: _dailyMode == 'same',
                  onSelected: (_) => setState(() {
                    _dailyMode = 'same';
                    _dailyMinutesController.text = _dailyMinutes.toString();
                  }),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Diferente por día'),
                  selected: _dailyMode == 'per_day',
                  onSelected: (_) => setState(() => _dailyMode = 'per_day'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_dailyMode == 'same')
            _minutesInput(
              label: 'Minutos por día',
              controller: _dailyMinutesController,
              onChanged: (m) => setState(() => _dailyMinutes = m),
            ),
          if (_dailyMode == 'per_day') _perDayRows(),
        ],
      ),
    );
  }

  Widget _weeklyConfigCreate() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Minutos por semana',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _weeklyController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null) {
                final clamped = n.clamp(1, 10080);
                setState(() => _weeklyMinutes = clamped);
                if (clamped.toString() != _weeklyController.text) {
                  _weeklyController.text = clamped.toString();
                  _weeklyController.selection = TextSelection.collapsed(
                      offset: _weeklyController.text.length);
                }
              }
            },
            decoration: const InputDecoration(
              suffixText: 'min',
              contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Reinicio semanal',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<int>(
            initialValue: _weeklyResetDay,
            items: const [
              DropdownMenuItem(value: 1, child: Text('Domingo')),
              DropdownMenuItem(value: 2, child: Text('Lunes')),
              DropdownMenuItem(value: 3, child: Text('Martes')),
              DropdownMenuItem(value: 4, child: Text('Miércoles')),
              DropdownMenuItem(value: 5, child: Text('Jueves')),
              DropdownMenuItem(value: 6, child: Text('Viernes')),
              DropdownMenuItem(value: 7, child: Text('Sábado')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _weeklyResetDay = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
        color: AppColors.textTertiary,
      ),
    );
  }

  Widget _pillRow({
    required String leftLabel,
    required String rightLabel,
    required bool leftSelected,
    required bool rightSelected,
    required VoidCallback onLeft,
    required VoidCallback onRight,
  }) {
    return Row(
      children: [
        Expanded(
          child: _pillButton(
            label: leftLabel,
            selected: leftSelected,
            onTap: onLeft,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _pillButton(
            label: rightLabel,
            selected: rightSelected,
            onTap: onRight,
          ),
        ),
      ],
    );
  }

  Widget _pillButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final bg = selected
        ? AppColors.primary
        : AppColors.surfaceVariant.withValues(alpha: 0.6);
    final fg = selected ? Colors.white : AppColors.textSecondary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.8)
              : AppColors.surfaceVariant.withValues(alpha: 0.8),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Center(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
          ),
        ),
      ),
    );
  }

  Widget _dailyConfig() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Tipo de límite diario'),
          const SizedBox(height: AppSpacing.sm),
          _pillRow(
            leftLabel: 'Mismo',
            rightLabel: 'Por día',
            leftSelected: _dailyMode == 'same',
            rightSelected: _dailyMode == 'per_day',
            onLeft: () => setState(() {
              _dailyMode = 'same';
              _dailyMinutesController.text = _dailyMinutes.toString();
              _recomputeDirty();
            }),
            onRight: () => setState(() {
              _dailyMode = 'per_day';
              _recomputeDirty();
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_dailyMode == 'same') _minutesCard(),
          if (_dailyMode == 'per_day') _perDayRows(),
        ],
      ),
    );
  }

  Widget _weeklyConfig() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Minutos por semana'),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _weeklyController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null) {
                final clamped = n.clamp(1, 10080);
                setState(() {
                  _weeklyMinutes = clamped;
                  _recomputeDirty();
                });
                if (clamped.toString() != _weeklyController.text) {
                  _weeklyController.text = clamped.toString();
                  _weeklyController.selection = TextSelection.collapsed(
                      offset: _weeklyController.text.length);
                }
              }
            },
            decoration: const InputDecoration(
              suffixText: 'min',
              contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _sectionLabel('Reinicio semanal'),
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<int>(
            initialValue: _weeklyResetDay,
            items: const [
              DropdownMenuItem(value: 1, child: Text('Domingo')),
              DropdownMenuItem(value: 2, child: Text('Lunes')),
              DropdownMenuItem(value: 3, child: Text('Martes')),
              DropdownMenuItem(value: 4, child: Text('Miércoles')),
              DropdownMenuItem(value: 5, child: Text('Jueves')),
              DropdownMenuItem(value: 6, child: Text('Viernes')),
              DropdownMenuItem(value: 7, child: Text('Sábado')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _weeklyResetDay = v;
                  _recomputeDirty();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _minutesRow(
      {required String label, required int value, required VoidCallback onTap}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: Text('${value}m'),
        ),
      ],
    );
  }

  Widget _minutesCard({
    String label = 'Minutos por día',
    int? value,
    VoidCallback? onTap,
  }) {
    final _ = value;
    return _minutesInput(
      label: label,
      controller: _dailyMinutesController,
      onChanged: (m) {
        setState(() {
          _dailyMinutes = m;
          _recomputeDirty();
        });
      },
    );
  }

  Widget _minutesInput({
    required String label,
    required TextEditingController controller,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.surfaceVariant.withValues(alpha: 0.9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            focusNode: _dailyMinutesFocus,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            onChanged: (v) {
              if (v.isEmpty) {
                onChanged(0);
                return;
              }
              final n = int.tryParse(v) ?? 0;
              final clamped = n.clamp(1, 480);
              if (clamped.toString() != controller.text) {
                controller.text = clamped.toString();
                controller.selection = TextSelection.collapsed(
                    offset: controller.text.length);
              }
              onChanged(clamped);
            },
            onEditingComplete: () {
              if (controller.text.trim().isEmpty) {
                controller.text = '1';
                controller.selection =
                    TextSelection.collapsed(offset: controller.text.length);
                onChanged(1);
              }
              FocusScope.of(context).unfocus();
            },
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              hintText: '≥ 1',
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Rango: 1 - 480 minutos(8 hr)',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _perDayRows() {
    const dayLabels = {
      1: 'Dom',
      2: 'Lun',
      3: 'Mar',
      4: 'Mié',
      5: 'Jue',
      6: 'Vie',
      7: 'Sáb',
    };

    return Column(
      children: List.generate(7, (i) {
        final day = i + 1;
        final value = _dailyQuotas[day] ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  dayLabels[day] ?? '?',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _dayControllers[day],
                  focusNode: _dayFocusNodes[day],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  onChanged: (v) {
                    if (v.isEmpty) {
                      setState(() {
                        _dailyQuotas[day] = 0;
                        _recomputeDirty();
                      });
                      return;
                    }
                    final n = int.tryParse(v) ?? 0;
                    final clamped = n.clamp(1, 480);
                    if (clamped.toString() != _dayControllers[day]?.text) {
                      _dayControllers[day]?.text = clamped.toString();
                      _dayControllers[day]?.selection = TextSelection.collapsed(
                          offset: _dayControllers[day]!.text.length);
                    }
                    setState(() {
                      _dailyQuotas[day] = clamped;
                      _recomputeDirty();
                    });
                  },
                  onEditingComplete: () {
                    final controller = _dayControllers[day];
                    if (controller != null && controller.text.trim().isEmpty) {
                      controller.text = '1';
                      controller.selection = TextSelection.collapsed(
                          offset: controller.text.length);
                      setState(() {
                        _dailyQuotas[day] = 1;
                        _recomputeDirty();
                      });
                    }
                    FocusScope.of(context).unfocus();
                  },
                  decoration: InputDecoration(
                    hintText: '≥ 1',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary.withValues(alpha: 0.8),
                    ),
                    suffixText: 'min',
                    suffixStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surfaceVariant.withValues(alpha: 0.6),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 84,
                child: Text(
                  value <= 0 ? '≥ 1' : 'Límite',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 10,
                    color: value <= 0
                        ? AppColors.warning
                        : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _scheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionLabel('Horarios (opcional)')),
            TextButton.icon(
              onPressed: _addSchedule,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Agregar'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Tooltip(
              message:
                  _inactiveFirst ? 'Inactivos primero' : 'Activos primero',
              child: IconButton(
                onPressed: () => setState(() {
                  _inactiveFirst = !_inactiveFirst;
                  _sortSchedules();
                }),
                icon: Icon(
                  _inactiveFirst
                      ? Icons.swap_vert_circle_rounded
                      : Icons.swap_vert_rounded,
                ),
                color: AppColors.textSecondary,
                iconSize: 20,
                style: IconButton.styleFrom(
                  backgroundColor:
                      AppColors.surfaceVariant.withValues(alpha: 0.4),
                  padding: const EdgeInsets.all(6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_loadingSchedules)
          const Center(child: CircularProgressIndicator(strokeWidth: 3))
          else if (_schedules.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.8),
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 28, color: AppColors.textTertiary),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Sin horarios configurados',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Bloquea la app en rangos horarios específicos',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
        else
          Column(
            children: _schedules.map(_scheduleTile).toList(),
          ),
      ],
    );
  }

  void _sortSchedules() {
    _schedules.sort((a, b) {
      final aEnabled = (a['isEnabled'] as bool? ?? true);
      final bEnabled = (b['isEnabled'] as bool? ?? true);
      if (aEnabled == bEnabled) return 0;
      if (_inactiveFirst) {
        return aEnabled ? 1 : -1;
      }
      return aEnabled ? -1 : 1;
    });
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

    final cardColor = enabled
        ? AppColors.primary.withValues(alpha: 0.12)
        : AppColors.surfaceVariant.withValues(alpha: 0.45);
    final borderColor = enabled
        ? AppColors.primary.withValues(alpha: 0.35)
        : AppColors.surfaceVariant.withValues(alpha: 0.7);
    final textColor = enabled ? AppColors.textPrimary : AppColors.textTertiary;
    final subTextColor =
        enabled ? AppColors.textTertiary : AppColors.textTertiary.withValues(alpha: 0.7);
    final iconColor = enabled ? AppColors.primary : AppColors.textTertiary;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        onTap: () => _editSchedule(s),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 16, color: iconColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dayText,
                      style: TextStyle(
                        fontSize: 11,
                        color: subTextColor,
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

  String _usageSummary() {
    final init = widget.initial ?? {};
    final limitType = _limitType;
    final usedMinutes = limitType == 'weekly'
        ? (init['usedMinutesWeek'] as int? ?? 0)
        : (init['usedMinutes'] as int? ?? 0);
    final usedMillis = limitType == 'weekly'
        ? usedMinutes * 60000
        : (init['usedMillis'] as num?)?.toInt() ?? usedMinutes * 60000;
    final quotaMinutes = limitType == 'weekly'
        ? _weeklyMinutes
        : _dailyMode == 'same'
            ? _dailyMinutes
            : _dailyQuotas[_todayDayOfWeek()] ?? 0;
    final remainingMillis = (quotaMinutes * 60000 - usedMillis)
        .clamp(0, quotaMinutes * 60000);
    final remainingMinutes = (quotaMinutes - usedMinutes).clamp(0, quotaMinutes);

    final usedText = _formatUsageText(
        usedMinutes, usedMillis, quotaMinutes, limitType);
    final remainingText = _formatRemainingText(
        remainingMinutes, remainingMillis, quotaMinutes, limitType);
    return '$usedText · $remainingText';
  }

  String _formatUsageText(
      int usedMinutes, int usedMillis, int quotaMinutes, String limitType) {
    if (limitType == 'weekly') {
      return '${AppUtils.formatTime(usedMinutes)} usados hoy';
    }
    if (quotaMinutes <= 1) {
      final seconds = (usedMillis / 1000).floor();
      return '${seconds}s usados hoy';
    }
    return '${AppUtils.formatTime(usedMinutes)} usados hoy';
  }

  String _formatRemainingText(
      int remainingMinutes, int remainingMillis, int quotaMinutes, String limitType) {
    if (limitType == 'weekly') {
      return '${AppUtils.formatTime(remainingMinutes)} restantes';
    }
    if (quotaMinutes <= 1) {
      final seconds = (remainingMillis / 1000).ceil();
      return '${seconds}s restantes';
    }
    return '${AppUtils.formatTime(remainingMinutes)} restantes';
  }

  int _todayDayOfWeek() {
    final weekday = DateTime.now().weekday; // 1=Mon..7=Sun
    return weekday == 7 ? 1 : weekday + 1; // 1=Sun..7=Sat
  }

  void _save() {
    _saveAsync();
  }

  void _recomputeDirty() {
    _dirty = _isLimitDirty();
    _schedulesChanged = _isScheduleDirty();
  }

  bool _isLimitDirty() {
    if (_limitType != _initialLimitType) return true;
    if (_dailyMode != _initialDailyMode) return true;
    if (_dailyMode == 'same' && _dailyMinutes != _initialDailyMinutes) {
      return true;
    }
    if (_dailyMode == 'per_day' &&
        !_mapEquals(_dailyQuotas, _initialDailyQuotas)) {
      return true;
    }
    if (_weeklyMinutes != _initialWeeklyMinutes) return true;
    if (_weeklyResetDay != _initialWeeklyResetDay) return true;
    return false;
  }

  bool _isLimitValid() {
    if (_limitType == 'weekly') {
      return _weeklyMinutes >= 1;
    }
    if (_dailyMode == 'same') {
      return _dailyMinutes >= 1;
    }
    for (var day = 1; day <= 7; day++) {
      final value = _dailyQuotas[day] ?? 0;
      if (value < 1) return false;
    }
    return true;
  }

  bool _isScheduleDirty() {
    if (_deletedScheduleIds.isNotEmpty) return true;
    if (_updatedScheduleIds.isNotEmpty) return true;
    for (final s in _schedules) {
      final id = s['id'];
      if (id == null || id.toString().isEmpty) return true;
    }
    return false;
  }

  bool _mapEquals(Map<int, int> a, Map<int, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  bool _scheduleEquals(
      Map<String, dynamic>? original, Map<String, dynamic> current) {
    if (original == null) return false;
    return original['startHour'] == current['startHour'] &&
        original['startMinute'] == current['startMinute'] &&
        original['endHour'] == current['endHour'] &&
        original['endMinute'] == current['endMinute'] &&
        _listEqualsInt(original['daysOfWeek'], current['daysOfWeek']) &&
        (original['isEnabled'] ?? true) == (current['isEnabled'] ?? true);
  }

  bool _listEqualsInt(dynamic a, dynamic b) {
    final la = (a as List<dynamic>? ?? [])
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .toList();
    final lb = (b as List<dynamic>? ?? [])
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .toList();
    if (la.length != lb.length) return false;
    for (var i = 0; i < la.length; i++) {
      if (la[i] != lb[i]) return false;
    }
    return true;
  }

  Future<void> _saveAsync() async {
    if (!_isLimitValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El límite debe ser mayor o igual a 1 minuto.'),
        ),
      );
      return;
    }
    final scheduleDirty = _isScheduleDirty();
    if (scheduleDirty && _packageName != null) {
      try {
        for (final id in _deletedScheduleIds) {
          await NativeService.deleteSchedule(id);
        }
        for (final s in _schedules) {
          final id = s['id'];
          if (id == null || id.toString().isEmpty) {
            await NativeService.addSchedule({
              'packageName': _packageName,
              'startHour': s['startHour'],
              'startMinute': s['startMinute'],
              'endHour': s['endHour'],
              'endMinute': s['endMinute'],
              'daysOfWeek': s['daysOfWeek'],
              'isEnabled': s['isEnabled'] ?? true,
            });
          } else if (_updatedScheduleIds.contains(id)) {
            await NativeService.updateSchedule({
              'id': id,
              'startHour': s['startHour'],
              'startMinute': s['startMinute'],
              'endHour': s['endHour'],
              'endMinute': s['endMinute'],
              'daysOfWeek': s['daysOfWeek'],
              'isEnabled': s['isEnabled'] ?? true,
            });
          }
        }
      } catch (_) {}
    }

    final isDaily = _limitType == 'daily';
    final result = <String, dynamic>{
      'limitType': _limitType,
      'dailyMode': _dailyMode,
      'dailyQuotaMinutes': isDaily && _dailyMode == 'same' ? _dailyMinutes : 0,
      'dailyQuotas': isDaily && _dailyMode == 'per_day' ? _dailyQuotas : {},
      'weeklyQuotaMinutes': _weeklyMinutes,
      'weeklyResetDay': _weeklyResetDay,
      'schedulesChanged': scheduleDirty,
    };
    if (mounted) Navigator.pop(context, result);
  }
}

class _ScheduleEditDialog extends StatefulWidget {
  const _ScheduleEditDialog({this.existing});

  final Map<String, dynamic>? existing;

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
