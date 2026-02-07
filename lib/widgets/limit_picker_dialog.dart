import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/app_utils.dart';
import 'package:timelock/utils/schedule_utils.dart';
import 'package:timelock/widgets/bottom_sheet_handle.dart';

class LimitPickerDialog extends StatefulWidget {
  const LimitPickerDialog({
    super.key,
    required this.appName,
    this.initial,
    this.fullScreen = false,
    this.useEditLayoutForCreate = false,
    this.packageName,
  });

  final String appName;
  final Map<String, dynamic>? initial;
  final bool fullScreen;
  final bool useEditLayoutForCreate;
  final String? packageName;

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
  late int _weeklyResetHour;
  late int _weeklyResetMinute;
  late final TextEditingController _weeklyController;
  late final TextEditingController _dailyMinutesController;
  late final TextEditingController _weeklyHourController;
  late final TextEditingController _weeklyMinuteController;
  late int _weeklyDaysInput;
  late int _weeklyHoursInput;
  late int _weeklyMinutesInput;
  late int _dailyHoursInput;
  late int _dailyMinutesInput;
  late final TextEditingController _weeklyDaysController;
  late final TextEditingController _weeklyHoursController;
  late final TextEditingController _weeklyMinutesInputController;
  late final TextEditingController _dailyHoursController;
  late final TextEditingController _dailyMinutesInputController;
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
  final Map<int, TextEditingController> _dayHourControllers = {};
  final Map<int, TextEditingController> _dayMinuteControllers = {};
  final FocusNode _dailyMinutesFocus = FocusNode();
  final Map<int, FocusNode> _dayFocusNodes = {};
  Map<String, dynamic>? _usageData;
  bool _usageLoading = false;
  Uint8List? _appIconBytes;
  late String _initialLimitType;
  late String _initialDailyMode;
  late int _initialDailyMinutes;
  late Map<int, int> _initialDailyQuotas;
  late int _initialWeeklyMinutes;
  late int _initialWeeklyResetDay;
  late int _initialWeeklyResetHour;
  late int _initialWeeklyResetMinute;
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
    _weeklyResetHour = (init['weeklyResetHour'] as int?) ?? 0;
    _weeklyResetMinute = (init['weeklyResetMinute'] as int?) ?? 0;
    _weeklyController =
        TextEditingController(text: _weeklyMinutes.toString());
    _dailyMinutesController = TextEditingController(
        text: _dailyMinutes > 0 ? _dailyMinutes.toString() : '');
    _weeklyHourController =
        TextEditingController(text: _weeklyResetHour.toString().padLeft(2, '0'));
    _weeklyMinuteController = TextEditingController(
        text: _weeklyResetMinute.toString().padLeft(2, '0'));
    _weeklyDaysInput = (_weeklyMinutes ~/ 1440).clamp(0, 7);
    _weeklyHoursInput = ((_weeklyMinutes % 1440) ~/ 60).clamp(0, 23);
    _weeklyMinutesInput = (_weeklyMinutes % 60).clamp(0, 59);
    _weeklyDaysController =
        TextEditingController(text: _weeklyDaysInput.toString());
    _weeklyHoursController =
        TextEditingController(text: _weeklyHoursInput.toString());
    _weeklyMinutesInputController =
        TextEditingController(text: _weeklyMinutesInput.toString());
    _dailyHoursInput = (_dailyMinutes ~/ 60).clamp(0, 23);
    _dailyMinutesInput = (_dailyMinutes % 60).clamp(0, 59);
    _dailyHoursController =
        TextEditingController(text: _dailyHoursInput.toString());
    _dailyMinutesInputController =
        TextEditingController(text: _dailyMinutesInput.toString());
    _dailyQuotas = _parseDailyQuotas(init['dailyQuotas']) ??
        {2: _dailyMinutes, 3: _dailyMinutes, 4: _dailyMinutes, 5: _dailyMinutes, 6: _dailyMinutes};
    for (var day = 1; day <= 7; day++) {
      final value = _dailyQuotas[day] ?? 0;
      _dayControllers[day] =
          TextEditingController(text: value > 0 ? value.toString() : '');
      final hours = (value ~/ 60).clamp(0, 23);
      final minutes = (value % 60).clamp(0, 59);
      _dayHourControllers[day] =
          TextEditingController(text: value > 0 ? hours.toString() : '');
      _dayMinuteControllers[day] =
          TextEditingController(text: value > 0 ? minutes.toString() : '');
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
    _initialWeeklyResetHour = _weeklyResetHour;
    _initialWeeklyResetMinute = _weeklyResetMinute;
    _initialDailyQuotas = Map<int, int>.from(_dailyQuotas);
    if (_packageName != null) {
      _loadSchedules();
      if (widget.initial == null) {
        _loadUsage();
        _loadAppIcon();
      }
    }
    if (widget.initial != null) {
      _appIconBytes = _iconBytes;
    }
  }

  @override
  void dispose() {
    _weeklyController.dispose();
    _dailyMinutesController.dispose();
    _weeklyHourController.dispose();
    _weeklyMinuteController.dispose();
    _weeklyDaysController.dispose();
    _weeklyHoursController.dispose();
    _weeklyMinutesInputController.dispose();
    _dailyHoursController.dispose();
    _dailyMinutesInputController.dispose();
    for (final c in _dayControllers.values) {
      c.dispose();
    }
    for (final c in _dayHourControllers.values) {
      c.dispose();
    }
    for (final c in _dayMinuteControllers.values) {
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
    final value = widget.initial?['packageName'] ?? widget.packageName;
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
      final normalized = raw.map(normalizeScheduleDays).toList();
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

  Future<void> _loadUsage() async {
    final pkg = _packageName;
    if (pkg == null) return;
    setState(() => _usageLoading = true);
    try {
      final usage = await NativeService.getUsageToday(pkg);
      if (!mounted) return;
      setState(() {
        _usageData = usage;
        _usageLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _usageLoading = false);
    }
  }

  Future<void> _loadAppIcon() async {
    final pkg = _packageName;
    if (pkg == null) return;
    try {
      final bytes = await NativeService.getAppIcon(pkg);
      if (!mounted) return;
      if (bytes != null && bytes.isNotEmpty) {
        setState(() => _appIconBytes = bytes);
      }
    } catch (_) {}
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
                      const BottomSheetHandle(),
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
                  child: _limitTypeSection(),
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
                const BottomSheetHandle(),
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
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.surface.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _buildAppIcon(),
          ),
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
                  _usageLoading ? 'Cargando...' : used,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _limitType == 'weekly' ? 'SEM' : 'DÍA',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppIcon() {
    final bytes = _appIconBytes ?? _iconBytes;
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
          _weeklySection(
            onMinutesChanged: (v) => setState(() => _weeklyMinutes = v),
            onResetChanged: (v) => setState(() => _weeklyResetDay = v),
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

  Widget _limitTypeSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded,
                  size: 16, color: AppColors.primary),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Tipo de límite',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Elige cómo se reinicia el tiempo',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
          _pillRow(
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
        ],
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
        : AppColors.surfaceVariant.withValues(alpha: 0.7);
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
              : AppColors.surfaceVariant.withValues(alpha: 0.7),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
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
          _dailyModeSection(),
          const SizedBox(height: AppSpacing.md),
          if (_dailyMode == 'same') _dailyDurationCard(),
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
          _weeklySection(
            onMinutesChanged: (v) {
              setState(() {
                _weeklyMinutes = v;
                _recomputeDirty();
              });
            },
            onResetChanged: (v) {
              setState(() {
                _weeklyResetDay = v;
                _recomputeDirty();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _weeklySection({
    required ValueChanged<int> onMinutesChanged,
    required ValueChanged<int> onResetChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month_rounded,
                  size: 16, color: AppColors.primary),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Límite semanal',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Define el total para toda la semana',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
          _durationRowCard(
            badge: 'Sem',
            daysController: _weeklyDaysController,
            hoursController: _weeklyHoursController,
            minutesController: _weeklyMinutesInputController,
            unitsLabel: 'd / h / m',
            onChanged: () {
              final d = int.tryParse(_weeklyDaysController.text) ?? 0;
              final h = int.tryParse(_weeklyHoursController.text) ?? 0;
              final m = int.tryParse(_weeklyMinutesInputController.text) ?? 0;
              final minutes = (d.clamp(0, 7) * 1440) +
                  (h.clamp(0, 23) * 60) +
                  m.clamp(0, 59);
              _weeklyMinutes = minutes;
              onMinutesChanged(minutes);
              _recomputeDirty();
            },
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Reinicio semanal',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
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
                    if (v != null) onResetChanged(v);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 56,
                child: TextField(
                  controller: _weeklyHourController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  onChanged: (v) {
                    final n = int.tryParse(v) ?? 0;
                    final clamped = n.clamp(0, 23);
                    if (clamped.toString().padLeft(2, '0') !=
                        _weeklyHourController.text) {
                      _weeklyHourController.text =
                          clamped.toString().padLeft(2, '0');
                      _weeklyHourController.selection =
                          TextSelection.collapsed(
                              offset: _weeklyHourController.text.length);
                    }
                    onResetChanged(_weeklyResetDay);
                    setState(() {
                      _weeklyResetHour = clamped;
                      _recomputeDirty();
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'HH',
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                ':',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 56,
                child: TextField(
                  controller: _weeklyMinuteController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  onChanged: (v) {
                    final n = int.tryParse(v) ?? 0;
                    final clamped = n.clamp(0, 59);
                    if (clamped.toString().padLeft(2, '0') !=
                        _weeklyMinuteController.text) {
                      _weeklyMinuteController.text =
                          clamped.toString().padLeft(2, '0');
                      _weeklyMinuteController.selection =
                          TextSelection.collapsed(
                              offset: _weeklyMinuteController.text.length);
                    }
                    onResetChanged(_weeklyResetDay);
                    setState(() {
                      _weeklyResetMinute = clamped;
                      _recomputeDirty();
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'MM',
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dailyModeSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_view_day_rounded,
                  size: 16, color: AppColors.primary),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Tipo de límite diario',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Define si el límite cambia por día',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
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
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _durationRowCard(
            badge: dayLabels[day] ?? '?',
            daysController: null,
            hoursController: _dayHourControllers[day]!,
            minutesController: _dayMinuteControllers[day]!,
            unitsLabel: 'h / m',
            onChanged: () => _syncPerDayMinutes(day),
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
    final timeText = formatTimeRange(
      s['startHour'] as int? ?? 0,
      s['startMinute'] as int? ?? 0,
      s['endHour'] as int? ?? 0,
      s['endMinute'] as int? ?? 0,
    );
    final dayText = formatDays(days);

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

  String _usageSummary() {
    final init = _usageData ?? widget.initial ?? {};
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
        usedMinutes,
        usedMillis,
        quotaMinutes,
        limitType,
        _weeklyResetDay,
        _weeklyResetHour,
        _weeklyResetMinute);
    final remainingText = _formatRemainingText(
        remainingMinutes,
        remainingMillis,
        quotaMinutes,
        limitType,
        _weeklyResetDay,
        _weeklyResetHour,
        _weeklyResetMinute);
    return '$usedText · $remainingText';
  }

    String _formatUsageText(
        int usedMinutes,
        int usedMillis,
        int quotaMinutes,
        String limitType,
        int weeklyResetDay,
        int weeklyResetHour,
        int weeklyResetMinute) {
      if (limitType == 'weekly') {
        final weeklyMillis = usedMinutes * 60000;
        final resetLabel = AppUtils.formatWeeklyResetLabel(
            weeklyResetDay, weeklyResetHour, weeklyResetMinute);
        return '${AppUtils.formatDurationMillis(weeklyMillis)} usados $resetLabel';
      }
      return '${AppUtils.formatDurationMillis(usedMillis)} usados hoy';
    }

  String _formatRemainingText(
        int remainingMinutes,
        int remainingMillis,
        int quotaMinutes,
        String limitType,
        int weeklyResetDay,
        int weeklyResetHour,
        int weeklyResetMinute) {
      if (limitType == 'weekly') {
        final nextLabel = AppUtils.formatWeeklyNextResetLabel(
            weeklyResetDay, weeklyResetHour, weeklyResetMinute);
        return '${AppUtils.formatTime(remainingMinutes)} restantes esta semana ($nextLabel)';
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
    if (_weeklyResetHour != _initialWeeklyResetHour) return true;
    if (_weeklyResetMinute != _initialWeeklyResetMinute) return true;
    return false;
  }

  void _syncPerDayMinutes(int day) {
    final h = int.tryParse(_dayHourControllers[day]?.text ?? '') ?? 0;
    final m = int.tryParse(_dayMinuteControllers[day]?.text ?? '') ?? 0;
    final hours = h.clamp(0, 23);
    final mins = m.clamp(0, 59);
    if (hours.toString() != _dayHourControllers[day]?.text) {
      _dayHourControllers[day]?.text = hours.toString();
      _dayHourControllers[day]?.selection = TextSelection.collapsed(
          offset: _dayHourControllers[day]!.text.length);
    }
    if (mins.toString() != _dayMinuteControllers[day]?.text) {
      _dayMinuteControllers[day]?.text = mins.toString();
      _dayMinuteControllers[day]?.selection = TextSelection.collapsed(
          offset: _dayMinuteControllers[day]!.text.length);
    }
    final minutes = hours * 60 + mins;
    setState(() {
      _dailyQuotas[day] = minutes;
      _recomputeDirty();
    });
  }

  Widget _dailyDurationCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Minutos por día',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _durationRowCard(
          badge: 'Día',
          daysController: null,
          hoursController: _dailyHoursController,
          minutesController: _dailyMinutesInputController,
          unitsLabel: 'h / m',
          onChanged: () {
            final h = int.tryParse(_dailyHoursController.text) ?? 0;
            final m = int.tryParse(_dailyMinutesInputController.text) ?? 0;
            final minutes = (h.clamp(0, 23) * 60) + m.clamp(0, 59);
            setState(() {
              _dailyMinutes = minutes;
              _dailyMinutesController.text =
                  minutes > 0 ? minutes.toString() : '';
              _recomputeDirty();
            });
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Rango: 1 - 480 minutos',
          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  Widget _durationRowCard({
    required String badge,
    required TextEditingController? daysController,
    required TextEditingController hoursController,
    required TextEditingController minutesController,
    required String unitsLabel,
    required VoidCallback onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Center(
              child: _durationInputsRow(
                daysController: daysController,
                hoursController: hoursController,
                minutesController: minutesController,
                unitsLabel: unitsLabel,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _durationInputsRow({
    required TextEditingController? daysController,
    required TextEditingController hoursController,
    required TextEditingController minutesController,
    required String unitsLabel,
    required VoidCallback onChanged,
  }) {
    Widget buildBox(
        {required TextEditingController controller,
        required String hint,
        required int max}) {
      return SizedBox(
        width: 64,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
          child: Center(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              onChanged: (v) {
                final n = int.tryParse(v) ?? 0;
                final clamped = n.clamp(0, max);
                if (clamped.toString() != controller.text) {
                  controller.text = clamped.toString();
                  controller.selection =
                      TextSelection.collapsed(offset: controller.text.length);
                }
                onChanged();
              },
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        if (daysController != null)
          buildBox(controller: daysController, hint: 'D', max: 7),
        buildBox(controller: hoursController, hint: 'H', max: 23),
        const Text(':', style: TextStyle(color: AppColors.textSecondary)),
        buildBox(controller: minutesController, hint: 'M', max: 59),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            unitsLabel,
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }

  bool _isLimitValid() {
    if (_limitType == 'weekly') {
      return _weeklyMinutes >= 1 &&
          _weeklyResetHour >= 0 &&
          _weeklyResetHour <= 23 &&
          _weeklyResetMinute >= 0 &&
          _weeklyResetMinute <= 59;
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
      'weeklyResetHour': _weeklyResetHour,
      'weeklyResetMinute': _weeklyResetMinute,
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
            child: Text(formatTimeOfDay(value)),
          ),
        ),
      ],
    );
  }

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
