import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/app_utils.dart';
import 'package:timelock/utils/app_motion.dart';
import 'package:timelock/utils/date_utils.dart';
import 'package:timelock/utils/schedule_utils.dart';
import 'package:timelock/widgets/bottom_sheet_handle.dart';
import 'package:timelock/widgets/date_block_edit_dialog.dart';
import 'package:timelock/widgets/schedule_edit_dialog.dart';

class LimitPickerDialog extends StatefulWidget {
  LimitPickerDialog({
    super.key,
    required this.appName,
    this.initial,
    this.fullScreen = false,
    this.useEditLayoutForCreate = false,
    this.packageName,
    this.initialSection = 'limit',
    this.initialDirectTab = 'schedule',
  });

  final String appName;
  final Map<String, dynamic>? initial;
  final bool fullScreen;
  final bool useEditLayoutForCreate;
  final String? packageName;
  final String initialSection;
  final String initialDirectTab;

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
  DateTime? _expiresDate;
  TimeOfDay _expiresTime = TimeOfDay(hour: 23, minute: 59);
  bool _expiresEnabled = false;
  int? _initialExpiresAt;
  String _expiredAction = 'none';
  bool _expiredPrefsLoaded = false;
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
  bool _loadingDateBlocks = false;
  List<Map<String, dynamic>> _dateBlocks = [];
  bool _dateBlocksChanged = false;
  bool _dirty = false;
  static const double _stickyBarHeight = 68;
  final Set<String> _deletedScheduleIds = {};
  final Set<String> _updatedScheduleIds = {};
  int _localScheduleCounter = 0;
  final Set<String> _deletedDateBlockIds = {};
  final Set<String> _updatedDateBlockIds = {};
  int _localDateBlockCounter = 0;
  bool _inactiveFirst = false;
  bool _inactiveDateFirst = false;
  late String _editorSection;
  late String _directTab;
  final Map<int, TextEditingController> _dayHourControllers = {};
  final Map<int, TextEditingController> _dayMinuteControllers = {};
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
  final Map<String, Map<String, dynamic>> _originalDateBlocksById = {};
  Color get _limitTone =>
      Color.lerp(AppColors.primary, AppColors.textPrimary, 0.16) ??
      AppColors.primary;
  Color get _directTone =>
      Color.lerp(AppColors.primary, AppColors.background, 0.28) ??
      AppColors.primary;
  Color get _modeTone => _editorSection == 'limit' ? _limitTone : _directTone;
  Color get _mixedTone =>
      Color.lerp(_limitTone, _directTone, 0.5) ?? AppColors.primary;
  Color _switchActiveAccent(Color tone) =>
      Color.lerp(AppColors.success, tone, 0.08) ?? AppColors.success;
  Color _switchInactiveAccent(Color tone) =>
      Color.lerp(AppColors.primary, tone, 0.2) ?? AppColors.primary;
  Color _switchThumbColor(Color tone, {required bool active}) {
    if (active) {
      return _switchActiveAccent(tone);
    }
    return _switchInactiveAccent(tone).withValues(alpha: 0.95);
  }

  Color _switchTrackColor(Color tone, {required bool active}) {
    if (active) {
      return Color.alphaBlend(
        _switchActiveAccent(tone).withValues(alpha: 0.52),
        AppColors.surfaceVariant,
      );
    }
    return Color.alphaBlend(
      _switchInactiveAccent(tone).withValues(alpha: 0.38),
      AppColors.surfaceVariant,
    );
  }

  ButtonStyle _saveButtonStyle() {
    final bg = _mixedTone;
    final fg = AppColors.onColor(bg);
    return FilledButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      disabledBackgroundColor: bg.withValues(alpha: 0.35),
      disabledForegroundColor: fg.withValues(alpha: 0.65),
    );
  }

  Future<void> _pickNumberWheel({
    required String title,
    required int current,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) async {
    final safeCurrent = current.clamp(min, max);
    final itemExtent = 36.0;
    final rangeCount = (max - min + 1);
    var selected = safeCurrent;
    const virtualItems = 20000;
    final middleBase = (virtualItems ~/ 2) - ((virtualItems ~/ 2) % rangeCount);
    final controller = FixedExtentScrollController(
      initialItem: middleBase + (safeCurrent - min),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.8)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Rango: $min a $max',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 210,
                  child: CupertinoPicker.builder(
                    scrollController: controller,
                    itemExtent: itemExtent,
                    diameterRatio: 1.25,
                    magnification: 1.08,
                    useMagnifier: true,
                    selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                      background: _modeTone.withValues(alpha: 0.1),
                    ),
                    onSelectedItemChanged: (index) {
                      selected = min + (index % rangeCount);
                    },
                    childCount: virtualItems,
                    itemBuilder: (_, index) {
                      final value = min + (index % rangeCount);
                      return Center(
                        child: Text(
                          value.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: FilledButton(
                      onPressed: () {
                        onChanged(selected);
                        Navigator.pop(dialogContext);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _mixedTone,
                        foregroundColor: AppColors.onColor(_mixedTone),
                      ),
                      child: Text('Aplicar'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
  }

  Widget _wheelField({
    required String value,
    required VoidCallback onTap,
    String? hint,
    double width = 64,
    double height = 48,
    double fontSize = 16,
  }) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.surfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          child: Text(
            value.isEmpty ? (hint ?? '--') : value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: value.isEmpty
                  ? AppColors.textTertiary
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final init = widget.initial ?? {};
    _editorSection = widget.initialSection == 'direct' &&
            (widget.packageName != null || init['packageName'] != null)
        ? 'direct'
        : 'limit';
    _directTab = widget.initialDirectTab == 'date' ? 'date' : 'schedule';
    _limitType = (init['limitType'] as String?) ?? 'daily';
    _dailyMode = (init['dailyMode'] as String?) ?? 'same';
    _dailyMinutes = (init['dailyQuotaMinutes'] as int?) ?? 30;
    _weeklyMinutes = (init['weeklyQuotaMinutes'] as int?) ?? 300;
    _weeklyResetDay = (init['weeklyResetDay'] as int?) ?? 2;
    _weeklyResetHour = (init['weeklyResetHour'] as int?) ?? 0;
    _weeklyResetMinute = (init['weeklyResetMinute'] as int?) ?? 0;
    final rawExpires = init['expiresAt'];
    final expiresAt = rawExpires is num
        ? rawExpires.toInt()
        : int.tryParse(rawExpires?.toString() ?? '');
    if (expiresAt != null && expiresAt > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(expiresAt);
      _expiresEnabled = true;
      _expiresDate = DateTime(dt.year, dt.month, dt.day);
      _expiresTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      _initialExpiresAt = expiresAt;
    }
    _weeklyController = TextEditingController(text: _weeklyMinutes.toString());
    _dailyMinutesController = TextEditingController(
        text: _dailyMinutes > 0 ? _dailyMinutes.toString() : '');
    _weeklyHourController = TextEditingController(
        text: _weeklyResetHour.toString().padLeft(2, '0'));
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
        {
          2: _dailyMinutes,
          3: _dailyMinutes,
          4: _dailyMinutes,
          5: _dailyMinutes,
          6: _dailyMinutes
        };
    for (var day = 1; day <= 7; day++) {
      final value = _dailyQuotas[day] ?? 0;
      final hours = (value ~/ 60).clamp(0, 23);
      final minutes = (value % 60).clamp(0, 59);
      _dayHourControllers[day] =
          TextEditingController(text: value > 0 ? hours.toString() : '');
      _dayMinuteControllers[day] =
          TextEditingController(text: value > 0 ? minutes.toString() : '');
    }
    _initialLimitType = _limitType;
    _initialDailyMode = _dailyMode;
    _initialDailyMinutes = _dailyMinutes;
    _initialWeeklyMinutes = _weeklyMinutes;
    _initialWeeklyResetDay = _weeklyResetDay;
    _initialWeeklyResetHour = _weeklyResetHour;
    _initialWeeklyResetMinute = _weeklyResetMinute;
    _loadExpiredPrefs();
    _initialDailyQuotas = Map<int, int>.from(_dailyQuotas);
    if (_packageName != null) {
      _loadSchedules();
      _loadDateBlocks();
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
    for (final c in _dayHourControllers.values) {
      c.dispose();
    }
    for (final c in _dayMinuteControllers.values) {
      c.dispose();
    }
    super.dispose();
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

  Future<void> _loadExpiredPrefs() async {
    if (_expiredPrefsLoaded) return;
    try {
      final prefs =
          await NativeService.getSharedPreferences('restriction_prefs');
      final action = prefs?['expired_action']?.toString();
      if (action != null &&
          (action == 'none' || action == 'archive' || action == 'delete')) {
        _expiredAction = action;
      }
    } catch (_) {}
    _expiredPrefsLoaded = true;
  }

  Future<void> _saveExpiredActionPref(String action) async {
    try {
      await NativeService.saveSharedPreference({
        'prefsName': 'restriction_prefs',
        'key': 'expired_action',
        'value': action,
      });
    } catch (_) {}
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
            normalized.where((s) => s['id'] != null).map((s) =>
                MapEntry(s['id'] as String, Map<String, dynamic>.from(s))),
          );
        _recomputeDirty();
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSchedules = false);
    }
  }

  Future<void> _loadDateBlocks() async {
    final pkg = _packageName;
    if (pkg == null) return;
    setState(() => _loadingDateBlocks = true);
    try {
      final raw = await NativeService.getDateBlocks(pkg);
      if (!mounted) return;
      setState(() {
        _dateBlocks = raw;
        _loadingDateBlocks = false;
        _dateBlocksChanged = false;
        _deletedDateBlockIds.clear();
        _updatedDateBlockIds.clear();
        _sortDateBlocks();
        _originalDateBlocksById
          ..clear()
          ..addEntries(
            raw.where((b) => b['id'] != null).map((b) =>
                MapEntry(b['id'] as String, Map<String, dynamic>.from(b))),
          );
        _recomputeDirty();
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDateBlocks = false);
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

  Future<void> _addDateBlock() async {
    final draft = await _openDateBlockEditor();
    if (draft == null) return;
    setState(() {
      _dateBlocks.add({
        'id': null,
        'localId': 'local-date-${_localDateBlockCounter++}',
        'startDate': draft.startDate,
        'endDate': draft.endDate,
        'startHour': draft.startHour,
        'startMinute': draft.startMinute,
        'endHour': draft.endHour,
        'endMinute': draft.endMinute,
        'label': draft.label.isNotEmpty ? draft.label : null,
        'isEnabled': true,
      });
      _dateBlocksChanged = _isDateBlocksDirty();
      _dirty = _isLimitDirty();
    });
  }

  Future<void> _editDateBlock(Map<String, dynamic> block) async {
    final draft = await _openDateBlockEditor(existing: block);
    if (draft == null) return;
    setState(() {
      block['startDate'] = draft.startDate;
      block['endDate'] = draft.endDate;
      block['startHour'] = draft.startHour;
      block['startMinute'] = draft.startMinute;
      block['endHour'] = draft.endHour;
      block['endMinute'] = draft.endMinute;
      block['label'] = draft.label.isNotEmpty ? draft.label : null;
      final id = block['id'];
      if (id is String && id.isNotEmpty) {
        if (_dateBlockEquals(_originalDateBlocksById[id], block)) {
          _updatedDateBlockIds.remove(id);
        } else {
          _updatedDateBlockIds.add(id);
        }
      }
      _dateBlocksChanged = _isDateBlocksDirty();
      _dirty = _isLimitDirty();
    });
  }

  Future<void> _toggleDateBlockEnabled(Map<String, dynamic> block) async {
    final enabled = !(block['isEnabled'] as bool? ?? true);
    setState(() {
      block['isEnabled'] = enabled;
      final id = block['id'];
      if (id is String && id.isNotEmpty) {
        if (_dateBlockEquals(_originalDateBlocksById[id], block)) {
          _updatedDateBlockIds.remove(id);
        } else {
          _updatedDateBlockIds.add(id);
        }
      }
      _dateBlocksChanged = _isDateBlocksDirty();
      _dirty = _isLimitDirty();
    });
  }

  Future<void> _deleteDateBlock(Map<String, dynamic> block) async {
    setState(() {
      final id = block['id'];
      if (id is String && id.isNotEmpty) {
        _deletedDateBlockIds.add(id);
        _updatedDateBlockIds.remove(id);
      }
      _dateBlocks.remove(block);
      _dateBlocksChanged = _isDateBlocksDirty();
      _dirty = _isLimitDirty();
    });
  }

  Future<ScheduleDraft?> _openScheduleEditor({Map<String, dynamic>? existing}) {
    return showDialog<ScheduleDraft>(
      context: context,
      builder: (_) => ScheduleEditDialog(
        existing: existing,
        existingSchedules: _schedules,
      ),
    );
  }

  Future<DateBlockDraft?> _openDateBlockEditor(
      {Map<String, dynamic>? existing}) {
    return showDialog<DateBlockDraft>(
      context: context,
      builder: (_) => DateBlockEditDialog(
        existing: existing,
        existingBlocks: _dateBlocks,
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final pkg = _packageName;
    if (pkg == null) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Eliminar restricción'),
        content: Text('¿Deseas eliminar esta restricción?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar'),
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
    final showSave = isCreate ||
        _isLimitDirty() ||
        _isScheduleDirty() ||
        _isDateBlocksDirty();
    final canSave = _isLimitValid();
    final modeTone = _modeTone;
    final surfaceTone = Color.lerp(
          Color.alphaBlend(modeTone.withValues(alpha: 0.05), AppColors.surface),
          AppColors.background,
          0.16,
        ) ??
        AppColors.surface;
    final stickyTone = Color.lerp(
          Color.alphaBlend(modeTone.withValues(alpha: 0.07), AppColors.surface),
          AppColors.background,
          0.12,
        ) ??
        AppColors.surface;
    final borderRadius = widget.fullScreen
        ? BorderRadius.circular(0)
        : BorderRadius.vertical(top: Radius.circular(AppRadius.xl));
    return WillPopScope(
      onWillPop: _handleBack,
      child: Stack(
        children: [
          SafeArea(
            top: true,
            bottom: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: _stickyBarHeight),
              child: AnimatedContainer(
                duration: AppMotion.duration(Duration(milliseconds: 220)),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: surfaceTone,
                  borderRadius: borderRadius,
                ),
                child: Column(
                  children: [
                    if (!widget.fullScreen) ...[
                      SizedBox(height: AppSpacing.sm),
                      BottomSheetHandle(),
                    ],
                    SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () async {
                              final allow = await _handleBack();
                              if (allow && mounted) Navigator.pop(context);
                            },
                            icon: Icon(Icons.arrow_back_ios_new_rounded,
                                size: 18),
                          ),
                          Expanded(
                            child: Text(
                              widget.appName,
                              style: TextStyle(
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
                              icon: Icon(Icons.delete_outline_rounded),
                              color: AppColors.error,
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    AppColors.error.withValues(alpha: 0.16),
                                side: BorderSide(
                                  color:
                                      AppColors.error.withValues(alpha: 0.45),
                                ),
                                shape: CircleBorder(),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: _headerCard(),
                    ),
                    SizedBox(height: AppSpacing.lg),
                    if (_packageName != null) ...[
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: _editorSectionSwitcher(),
                      ),
                      SizedBox(height: AppSpacing.lg),
                    ],
                    if (_editorSection == 'limit') ...[
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: _limitTypeSection(),
                      ),
                      SizedBox(height: AppSpacing.lg),
                      if (_limitType == 'daily') _dailyConfig(),
                      if (_limitType == 'weekly') _weeklyConfig(),
                      SizedBox(height: AppSpacing.lg),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: _expirySection(),
                      ),
                    ] else ...[
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: _directBlocksSection(),
                      ),
                    ],
                    SizedBox(height: AppSpacing.xl),
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
                  duration: AppMotion.duration(Duration(milliseconds: 220)),
                  curve: Curves.easeOutCubic,
                  offset: showSave ? Offset.zero : Offset(0, 0.25),
                  child: AnimatedOpacity(
                    duration: AppMotion.duration(Duration(milliseconds: 180)),
                    curve: Curves.easeOutCubic,
                    opacity: showSave ? 1 : 0,
                    child: AnimatedContainer(
                      duration: AppMotion.duration(Duration(milliseconds: 220)),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm,
                          AppSpacing.lg, AppSpacing.md),
                      decoration: BoxDecoration(
                        color: stickyTone,
                        border: Border(
                          top: BorderSide(
                            color: modeTone.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: FilledButton(
                          onPressed: canSave ? _save : null,
                          style: _saveButtonStyle(),
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
    if (!(_isLimitDirty() || _isScheduleDirty() || _isDateBlocksDirty())) {
      return true;
    }
    return await _confirmDiscard();
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Descartar cambios'),
        content: Text('Tienes cambios sin guardar. ¿Deseas salir igual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Salir'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildCreateLayout() {
    final borderRadius = widget.fullScreen
        ? BorderRadius.circular(0)
        : BorderRadius.vertical(top: Radius.circular(AppRadius.xl));
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: borderRadius,
        ),
        child: Column(
          children: [
            if (!widget.fullScreen) ...[
              SizedBox(height: AppSpacing.sm),
              BottomSheetHandle(),
            ],
            SizedBox(height: AppSpacing.md),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Límite de tiempo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          widget.appName,
                          style: TextStyle(
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
                    icon: Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text('Diario'),
                      selected: _limitType == 'daily',
                      onSelected: (_) => setState(() => _limitType = 'daily'),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ChoiceChip(
                      label: Text('Semanal'),
                      selected: _limitType == 'weekly',
                      onSelected: (_) => setState(() => _limitType = 'weekly'),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.md),
            if (_limitType == 'daily') _dailyConfigCreate(),
            if (_limitType == 'weekly') _weeklyConfigCreate(),
            SizedBox(height: AppSpacing.md),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _expirySection(),
            ),
            SizedBox(height: AppSpacing.md),
            Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: _isLimitValid() ? _save : null,
                  style: _saveButtonStyle(),
                  child: Text('Crear'),
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
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceVariant.withValues(alpha: 0.78),
            AppColors.surface.withValues(alpha: 0.96),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.surfaceVariant.withValues(alpha: 0.95),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.background.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.surfaceVariant.withValues(alpha: 0.98),
              ),
            ),
            child: _buildAppIcon(),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.appName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  _usageLoading ? 'Cargando...' : used,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _limitType == 'weekly' ? 'SEM' : 'DÍA',
              style: TextStyle(
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
      child: Icon(Icons.apps_rounded, color: AppColors.textTertiary, size: 24),
    );
  }

  Widget _dailyConfigCreate() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tipo de límite diario',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Text('Mismo cada día'),
                  selected: _dailyMode == 'same',
                  onSelected: (_) => setState(() {
                    _dailyMode = 'same';
                    _dailyMinutesController.text = _dailyMinutes.toString();
                  }),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ChoiceChip(
                  label: Text('Diferente por día'),
                  selected: _dailyMode == 'per_day',
                  onSelected: (_) => setState(() => _dailyMode = 'per_day'),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
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
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
        color: AppColors.textTertiary,
      ),
    );
  }

  Widget _limitTypeSection() {
    final modeTone = _modeTone;
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: modeTone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: modeTone.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: modeTone),
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
          SizedBox(height: 6),
          Text(
            'Elige cómo se reinicia el tiempo',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
          SizedBox(height: AppSpacing.sm),
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
        SizedBox(width: AppSpacing.sm),
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
    final controlTone =
        Color.lerp(_modeTone, AppColors.background, 0.32) ?? _modeTone;
    final bg = selected
        ? controlTone
        : AppColors.surfaceVariant.withValues(alpha: 0.7);
    final fg =
        selected ? AppColors.onColor(controlTone) : AppColors.textSecondary;
    return AnimatedContainer(
      duration: AppMotion.duration(Duration(milliseconds: 180)),
      curve: Curves.easeOutCubic,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected
              ? controlTone.withValues(alpha: 0.9)
              : AppColors.surfaceVariant.withValues(alpha: 0.7),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: controlTone.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: Offset(0, 4),
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
            style:
                TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
          ),
        ),
      ),
    );
  }

  Widget _dailyConfig() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dailyModeSection(),
          SizedBox(height: AppSpacing.md),
          if (_dailyMode == 'same') _dailyDurationCard(),
          if (_dailyMode == 'per_day') _perDayRows(),
        ],
      ),
    );
  }

  Widget _weeklyConfig() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
    final modeTone = _modeTone;
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: modeTone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: modeTone.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 16, color: modeTone),
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
          SizedBox(height: 6),
          Text(
            'Define el total para toda la semana',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
          SizedBox(height: AppSpacing.sm),
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
          SizedBox(height: AppSpacing.md),
          Text(
            'Reinicio semanal',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          SizedBox(height: AppSpacing.xs),
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
              SizedBox(width: AppSpacing.sm),
              _wheelField(
                value: _weeklyHourController.text,
                hint: 'HH',
                onTap: () => _pickNumberWheel(
                  title: 'Hora de reinicio semanal',
                  current: _weeklyResetHour,
                  min: 0,
                  max: 23,
                  onChanged: (value) {
                    setState(() {
                      _weeklyResetHour = value;
                      _weeklyHourController.text =
                          value.toString().padLeft(2, '0');
                      _recomputeDirty();
                    });
                    onResetChanged(_weeklyResetDay);
                  },
                ),
              ),
              SizedBox(width: 6),
              Text(
                ':',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              SizedBox(width: 6),
              _wheelField(
                value: _weeklyMinuteController.text,
                hint: 'MM',
                onTap: () => _pickNumberWheel(
                  title: 'Minuto de reinicio semanal',
                  current: _weeklyResetMinute,
                  min: 0,
                  max: 59,
                  onChanged: (value) {
                    setState(() {
                      _weeklyResetMinute = value;
                      _weeklyMinuteController.text =
                          value.toString().padLeft(2, '0');
                      _recomputeDirty();
                    });
                    onResetChanged(_weeklyResetDay);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dailyModeSection() {
    final modeTone = _modeTone;
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: modeTone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: modeTone.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_view_day_rounded, size: 16, color: modeTone),
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
          SizedBox(height: 6),
          Text(
            'Define si el límite cambia por día',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
          SizedBox(height: AppSpacing.sm),
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
      {required String label,
      required int value,
      required VoidCallback onTap}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
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
      padding: EdgeInsets.all(AppSpacing.md),
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
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          _wheelField(
            value: controller.text,
            hint: '≥ 1',
            width: double.infinity,
            height: 52,
            fontSize: 18,
            onTap: () => _pickNumberWheel(
              title: 'Minutos diarios permitidos',
              current: int.tryParse(controller.text) ?? 1,
              min: 1,
              max: 480,
              onChanged: (value) {
                setState(() {
                  controller.text = value.toString();
                });
                onChanged(value);
              },
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
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
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
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
    final modeTone = _modeTone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionLabel('Horarios (opcional)')),
            TextButton.icon(
              onPressed: _addSchedule,
              icon: Icon(Icons.add_rounded, size: 16),
              label: Text('Agregar'),
              style: TextButton.styleFrom(
                foregroundColor: modeTone,
                backgroundColor: modeTone.withValues(alpha: 0.12),
                side: BorderSide(color: modeTone.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            Tooltip(
              message: _inactiveFirst ? 'Inactivos primero' : 'Activos primero',
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
                iconSize: 20,
                style: IconButton.styleFrom(
                  backgroundColor: _inactiveFirst
                      ? modeTone.withValues(alpha: 0.2)
                      : AppColors.surfaceVariant.withValues(alpha: 0.4),
                  foregroundColor: _inactiveFirst
                      ? modeTone
                      : AppColors.onColor(AppColors.surfaceVariant),
                  padding: EdgeInsets.all(6),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        if (_loadingSchedules)
          Center(child: CircularProgressIndicator(strokeWidth: 3))
        else if (_schedules.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: modeTone.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: modeTone.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 28, color: modeTone.withValues(alpha: 0.8)),
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
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
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

  Widget _dateBlockSection() {
    final modeTone = _modeTone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionLabel('Fechas (opcional)')),
            TextButton.icon(
              onPressed: _addDateBlock,
              icon: Icon(Icons.add_rounded, size: 16),
              label: Text('Agregar'),
              style: TextButton.styleFrom(
                foregroundColor: modeTone,
                backgroundColor: modeTone.withValues(alpha: 0.12),
                side: BorderSide(color: modeTone.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            Tooltip(
              message:
                  _inactiveDateFirst ? 'Inactivos primero' : 'Activos primero',
              child: IconButton(
                onPressed: () => setState(() {
                  _inactiveDateFirst = !_inactiveDateFirst;
                  _sortDateBlocks();
                }),
                icon: Icon(
                  _inactiveDateFirst
                      ? Icons.swap_vert_circle_rounded
                      : Icons.swap_vert_rounded,
                ),
                iconSize: 20,
                style: IconButton.styleFrom(
                  backgroundColor: _inactiveDateFirst
                      ? modeTone.withValues(alpha: 0.2)
                      : AppColors.surfaceVariant.withValues(alpha: 0.4),
                  foregroundColor: _inactiveDateFirst
                      ? modeTone
                      : AppColors.onColor(AppColors.surfaceVariant),
                  padding: EdgeInsets.all(6),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        if (_loadingDateBlocks)
          Center(child: CircularProgressIndicator(strokeWidth: 3))
        else if (_dateBlocks.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: modeTone.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: modeTone.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.event_busy_rounded,
                    size: 28, color: modeTone.withValues(alpha: 0.8)),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Sin fechas configuradas',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Bloquea la app por rangos de fechas',
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Column(
            children: _dateBlocks.map(_dateBlockTile).toList(),
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

  void _sortDateBlocks() {
    _dateBlocks.sort((a, b) {
      final aEnabled = (a['isEnabled'] as bool? ?? true);
      final bEnabled = (b['isEnabled'] as bool? ?? true);
      if (aEnabled == bEnabled) {
        final aEnd = a['endDate']?.toString() ?? '';
        final bEnd = b['endDate']?.toString() ?? '';
        return aEnd.compareTo(bEnd);
      }
      if (_inactiveDateFirst) {
        return aEnabled ? 1 : -1;
      }
      return aEnabled ? -1 : 1;
    });
  }

  Widget _scheduleTile(Map<String, dynamic> s) {
    final tone = _modeTone;
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
        ? tone.withValues(alpha: 0.12)
        : AppColors.surfaceVariant.withValues(alpha: 0.45);
    final borderColor = enabled
        ? tone.withValues(alpha: 0.35)
        : AppColors.surfaceVariant.withValues(alpha: 0.7);
    final textColor = enabled ? AppColors.textPrimary : AppColors.textTertiary;
    final subTextColor = enabled
        ? AppColors.textTertiary
        : AppColors.textTertiary.withValues(alpha: 0.7);
    final iconColor = enabled ? tone : AppColors.textTertiary;

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        onTap: () => _editSchedule(s),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 16, color: iconColor),
              SizedBox(width: AppSpacing.sm),
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
                    SizedBox(height: 2),
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
                activeThumbColor: _switchThumbColor(tone, active: true),
                activeTrackColor: _switchTrackColor(tone, active: true),
                inactiveThumbColor: _switchThumbColor(tone, active: false),
                inactiveTrackColor: _switchTrackColor(tone, active: false),
                onChanged: (_) => _toggleEnabled(s),
              ),
              IconButton(
                onPressed: () => _deleteSchedule(s),
                icon: Icon(Icons.delete_outline_rounded, size: 16),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.error,
                  backgroundColor: AppColors.surfaceVariant,
                  minimumSize: Size(28, 28),
                  fixedSize: Size(28, 28),
                  padding: EdgeInsets.all(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateBlockTile(Map<String, dynamic> b) {
    final tone = _modeTone;
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

    final cardColor = enabled
        ? tone.withValues(alpha: 0.12)
        : AppColors.surfaceVariant.withValues(alpha: 0.45);
    final borderColor = enabled
        ? tone.withValues(alpha: 0.35)
        : AppColors.surfaceVariant.withValues(alpha: 0.7);
    final textColor = enabled ? AppColors.textPrimary : AppColors.textTertiary;
    final subTextColor = enabled
        ? AppColors.textTertiary
        : AppColors.textTertiary.withValues(alpha: 0.7);
    final iconColor = enabled ? tone : AppColors.textTertiary;

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        onTap: () => _editDateBlock(b),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.event_busy_rounded, size: 16, color: iconColor),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rangeText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 2),
                    if (label?.isNotEmpty == true)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tone.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: tone.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            label!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: tone,
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        'Bloqueo por fecha',
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
                activeThumbColor: _switchThumbColor(tone, active: true),
                activeTrackColor: _switchTrackColor(tone, active: true),
                inactiveThumbColor: _switchThumbColor(tone, active: false),
                inactiveTrackColor: _switchTrackColor(tone, active: false),
                onChanged: (_) => _toggleDateBlockEnabled(b),
              ),
              IconButton(
                onPressed: () => _deleteDateBlock(b),
                icon: Icon(Icons.delete_outline_rounded, size: 16),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.error,
                  backgroundColor: AppColors.surfaceVariant,
                  minimumSize: Size(28, 28),
                  fixedSize: Size(28, 28),
                  padding: EdgeInsets.all(4),
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
    final remainingMillis =
        (quotaMinutes * 60000 - usedMillis).clamp(0, quotaMinutes * 60000);
    final remainingMinutes =
        (quotaMinutes - usedMinutes).clamp(0, quotaMinutes);

    final usedText = AppUtils.formatUsageText(
      usedMinutes: usedMinutes,
      usedMillis: usedMillis,
      limitType: limitType,
      weeklyResetDay: _weeklyResetDay,
      weeklyResetHour: _weeklyResetHour,
      weeklyResetMinute: _weeklyResetMinute,
      dailySuffix: 'hoy',
    );
    final remainingText = AppUtils.formatRemainingText(
      remainingMinutes: remainingMinutes,
      remainingMillis: remainingMillis,
      quotaMinutes: quotaMinutes,
      limitType: limitType,
      weeklyResetDay: _weeklyResetDay,
      weeklyResetHour: _weeklyResetHour,
      weeklyResetMinute: _weeklyResetMinute,
    );
    return '$usedText · $remainingText';
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
    _dateBlocksChanged = _isDateBlocksDirty();
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
    final currentExpires = _expiryMillis() ?? 0;
    final initialExpires = _initialExpiresAt ?? 0;
    if (currentExpires != initialExpires) return true;
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
        Text(
          'Minutos por día',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
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
        SizedBox(height: AppSpacing.sm),
        Text(
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
    final modeTone = _modeTone;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: modeTone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: modeTone.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: modeTone.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
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
      final fieldLabel = hint == 'D'
          ? 'Días'
          : hint == 'H'
              ? 'Horas'
              : 'Minutos';
      return _wheelField(
        value: controller.text,
        hint: hint,
        onTap: () => _pickNumberWheel(
          title: '$fieldLabel del límite',
          current: int.tryParse(controller.text) ?? 0,
          min: 0,
          max: max,
          onChanged: (value) {
            setState(() {
              controller.text = value.toString();
            });
            onChanged();
          },
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
        Text(':', style: TextStyle(color: AppColors.textSecondary)),
        buildBox(controller: minutesController, hint: 'M', max: 59),
        Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text(
            unitsLabel,
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }

  bool _isLimitValid() {
    if (_expiresEnabled && !_isExpiryValid()) return false;
    final hasDirectBlocks = _hasDirectBlocks();
    if (_limitType == 'weekly') {
      if (_weeklyMinutes >= 1) {
        return _weeklyResetHour >= 0 &&
            _weeklyResetHour <= 23 &&
            _weeklyResetMinute >= 0 &&
            _weeklyResetMinute <= 59;
      }
      return hasDirectBlocks;
    }
    if (_dailyMode == 'same') {
      return _dailyMinutes >= 1 || hasDirectBlocks;
    }
    var allDaysHaveQuota = true;
    for (var day = 1; day <= 7; day++) {
      final value = _dailyQuotas[day] ?? 0;
      if (value < 1) {
        allDaysHaveQuota = false;
        break;
      }
    }
    return allDaysHaveQuota || hasDirectBlocks;
  }

  Widget _expirySection() {
    final modeTone = _modeTone;
    final enabled = _expiresEnabled;
    final dateText = _expiresDate == null
        ? 'Sin fecha'
        : formatShortDateLabel(formatDate(_expiresDate!));
    final timeText = formatTimeLabel(_expiresTime.hour, _expiresTime.minute);
    final summary = enabled ? '$dateText $timeText' : 'Sin vencimiento';

    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: modeTone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: modeTone.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 16, color: modeTone),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Vencimiento',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: enabled,
                activeThumbColor: _switchThumbColor(modeTone, active: true),
                activeTrackColor: _switchTrackColor(modeTone, active: true),
                inactiveThumbColor: _switchThumbColor(modeTone, active: false),
                inactiveTrackColor: _switchTrackColor(modeTone, active: false),
                onChanged: (value) {
                  setState(() {
                    _expiresEnabled = value;
                    if (value && _expiresDate == null) {
                      final now = DateTime.now().add(Duration(days: 1));
                      _expiresDate = DateTime(now.year, now.month, now.day);
                      _expiresTime = TimeOfDay(hour: 23, minute: 59);
                    }
                    _recomputeDirty();
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            enabled ? 'Vence el $summary' : 'No tiene vencimiento',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _expiryButton(
                  label: 'Fecha',
                  value: dateText,
                  enabled: enabled,
                  onTap: _pickExpiryDate,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _expiryButton(
                  label: 'Hora',
                  value: timeText,
                  enabled: enabled,
                  onTap: _pickExpiryTime,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            value: _expiredAction,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceVariant.withValues(alpha: 0.4),
              contentPadding: EdgeInsets.symmetric(
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
            items: const [
              DropdownMenuItem(
                  value: 'none', child: Text('Sin acción automática')),
              DropdownMenuItem(
                  value: 'archive', child: Text('Archivar vencidas')),
              DropdownMenuItem(
                  value: 'delete', child: Text('Eliminar vencidas')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _expiredAction = value);
              _saveExpiredActionPref(value);
            },
          ),
          SizedBox(height: 6),
          Text(
            'La acción se aplica solo después del vencimiento.',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _editorSectionSwitcher() {
    final isLimit = _editorSection == 'limit';
    final sectionTone = isLimit ? _limitTone : _directTone;
    final sectionToneStrong = sectionTone.withValues(alpha: 0.75);
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: sectionTone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: sectionToneStrong,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.view_compact_alt_rounded,
                  size: 16, color: sectionToneStrong),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Modo de bloqueo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            _editorSection == 'limit'
                ? 'Límite: define cuánto tiempo puede usarse la app.'
                : 'Directo: bloquea la app sin esperar consumo de tiempo.',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
          SizedBox(height: AppSpacing.sm),
          _editorSectionTabs(),
        ],
      ),
    );
  }

  Widget _editorSectionTabs() {
    final isLimit = _editorSection == 'limit';
    final activeColor = isLimit ? _limitTone : _directTone;
    final activeForeground = AppColors.onColor(activeColor);
    final inactiveColor = AppColors.textSecondary.withValues(alpha: 0.72);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = (constraints.maxWidth - 8) / 2;
        return AnimatedContainer(
          duration: AppMotion.duration(Duration(milliseconds: 200)),
          curve: Curves.easeOutCubic,
          height: 46,
          decoration: BoxDecoration(
            color: activeColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: activeColor.withValues(alpha: 0.35),
            ),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: AppMotion.duration(Duration(milliseconds: 200)),
                curve: Curves.easeOutCubic,
                alignment:
                    isLimit ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: tabWidth,
                  margin: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: activeColor.withValues(alpha: 0.95),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.38),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _editorSection = 'limit'),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timer_rounded,
                              size: 15,
                              color: isLimit ? activeForeground : inactiveColor,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Límite',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1,
                                fontWeight: FontWeight.w700,
                                color:
                                    isLimit ? activeForeground : inactiveColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _editorSection = 'direct'),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_clock_rounded,
                              size: 15,
                              color:
                                  !isLimit ? activeForeground : inactiveColor,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Directo',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1,
                                fontWeight: FontWeight.w700,
                                color:
                                    !isLimit ? activeForeground : inactiveColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _directBlocksSection() {
    final scheduleTotal = _schedules.length;
    final dateTotal = _dateBlocks.length;
    final modeTone = _modeTone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: modeTone.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: modeTone.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_clock_rounded, size: 16, color: modeTone),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'Bloqueos directos',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Pestaña actual: ${_directTab == 'schedule' ? 'Horarios' : 'Fechas'}',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              SizedBox(height: AppSpacing.sm),
              _pillRow(
                leftLabel: 'Horarios ($scheduleTotal)',
                rightLabel: 'Fechas ($dateTotal)',
                leftSelected: _directTab == 'schedule',
                rightSelected: _directTab == 'date',
                onLeft: () => setState(() => _directTab = 'schedule'),
                onRight: () => setState(() => _directTab = 'date'),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.md),
        if (_directTab == 'schedule') _scheduleSection(),
        if (_directTab == 'date') _dateBlockSection(),
      ],
    );
  }

  Widget _expiryButton({
    required String label,
    required String value,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.surfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.edit_calendar_rounded,
                  size: 16, color: AppColors.textSecondary),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '$label: $value',
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
      ),
    );
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final initial = _expiresDate ?? now.add(Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      locale: Locale('es', 'ES'),
    );
    if (picked == null) return;
    setState(() {
      _expiresDate = DateTime(picked.year, picked.month, picked.day);
      _recomputeDirty();
    });
  }

  Future<void> _pickExpiryTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _expiresTime,
      helpText: 'Hora de vencimiento',
    );
    if (picked == null) return;
    setState(() {
      _expiresTime = picked;
      _recomputeDirty();
    });
  }

  bool _isExpiryValid() {
    if (!_expiresEnabled) return true;
    if (_expiresDate == null) return false;
    final d = _expiresDate!;
    final expiry = DateTime(
      d.year,
      d.month,
      d.day,
      _expiresTime.hour,
      _expiresTime.minute,
    );
    return expiry.isAfter(DateTime.now());
  }

  int? _expiryMillis() {
    if (!_expiresEnabled || _expiresDate == null) return null;
    final d = _expiresDate!;
    return DateTime(
      d.year,
      d.month,
      d.day,
      _expiresTime.hour,
      _expiresTime.minute,
    ).millisecondsSinceEpoch;
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

  bool _isDateBlocksDirty() {
    if (_deletedDateBlockIds.isNotEmpty) return true;
    if (_updatedDateBlockIds.isNotEmpty) return true;
    for (final b in _dateBlocks) {
      final id = b['id'];
      if (id == null || id.toString().isEmpty) return true;
    }
    return false;
  }

  bool _hasDirectBlocks() {
    return _schedules.isNotEmpty || _dateBlocks.isNotEmpty;
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

  bool _dateBlockEquals(
      Map<String, dynamic>? original, Map<String, dynamic> current) {
    if (original == null) return false;
    return original['startDate'] == current['startDate'] &&
        original['endDate'] == current['endDate'] &&
        (original['startHour'] ?? 0) == (current['startHour'] ?? 0) &&
        (original['startMinute'] ?? 0) == (current['startMinute'] ?? 0) &&
        (original['endHour'] ?? 23) == (current['endHour'] ?? 23) &&
        (original['endMinute'] ?? 59) == (current['endMinute'] ?? 59) &&
        (original['isEnabled'] ?? true) == (current['isEnabled'] ?? true) &&
        (original['label'] ?? '') == (current['label'] ?? '');
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
        SnackBar(
          content: Text(
            _expiresEnabled && !_isExpiryValid()
                ? 'La fecha/hora de vencimiento debe ser futura.'
                : _hasDirectBlocks()
                    ? 'Configura un límite >= 1 minuto o agrega un horario/bloqueo por fecha.'
                    : 'El límite debe ser mayor o igual a 1 minuto.',
          ),
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

    final dateBlocksDirty = _isDateBlocksDirty();
    if (dateBlocksDirty && _packageName != null) {
      try {
        for (final id in _deletedDateBlockIds) {
          await NativeService.deleteDateBlock(id);
        }
        for (final b in _dateBlocks) {
          final id = b['id'];
          if (id == null || id.toString().isEmpty) {
            await NativeService.addDateBlock({
              'packageName': _packageName,
              'startDate': b['startDate'],
              'endDate': b['endDate'],
              'startHour': b['startHour'] ?? 0,
              'startMinute': b['startMinute'] ?? 0,
              'endHour': b['endHour'] ?? 23,
              'endMinute': b['endMinute'] ?? 59,
              'label': b['label'],
              'isEnabled': b['isEnabled'] ?? true,
            });
          } else if (_updatedDateBlockIds.contains(id)) {
            await NativeService.updateDateBlock({
              'id': id,
              'startDate': b['startDate'],
              'endDate': b['endDate'],
              'startHour': b['startHour'] ?? 0,
              'startMinute': b['startMinute'] ?? 0,
              'endHour': b['endHour'] ?? 23,
              'endMinute': b['endMinute'] ?? 59,
              'label': b['label'],
              'isEnabled': b['isEnabled'] ?? true,
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
      'expiresAt': _expiryMillis(),
      'schedulesChanged': scheduleDirty,
      'dateBlocksChanged': dateBlocksDirty,
    };
    if (mounted) Navigator.pop(context, result);
  }
}
