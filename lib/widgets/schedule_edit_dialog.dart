import 'package:flutter/material.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/schedule_utils.dart';

class ScheduleEditDialog extends StatefulWidget {
  const ScheduleEditDialog({super.key, this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<ScheduleEditDialog> createState() => _ScheduleEditDialogState();
}

class _ScheduleEditDialogState extends State<ScheduleEditDialog> {
  late TimeOfDay _start;
  late TimeOfDay _end;
  late Set<int> _days;
  String? _preset;

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

  String _summary() {
    final days = _days.toList()..sort();
    final daysText = formatDays(days);
    final range = formatTimeRange(
      _start.hour,
      _start.minute,
      _end.hour,
      _end.minute,
    );
    return '$daysText · $range';
  }

  void _setDays(Set<int> value) {
    setState(() {
      _days = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing == null ? 'Nuevo horario' : 'Editar horario'),
          SizedBox(height: AppSpacing.xs),
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
              SizedBox(height: AppSpacing.sm),
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
                    SizedBox(height: AppSpacing.sm),
                    _inlineLabel('Preconfiguración'),
                    SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<String>(
                      value: _preset,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor:
                            AppColors.surfaceVariant.withValues(alpha: 0.4),
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
                      hint: Text('Selecciona una opción'),
                      items: [
                        DropdownMenuItem(
                          value: 'Laborables',
                          child: Text('Laborables (L–V)'),
                        ),
                        DropdownMenuItem(
                          value: 'Fin de semana',
                          child: Text('Fin de semana (S–D)'),
                        ),
                        DropdownMenuItem(
                          value: 'Todos',
                          child: Text('Todos los días'),
                        ),
                        DropdownMenuItem(
                          value: 'Limpiar',
                          child: Text('Limpiar selección'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _preset = value;
                        });
                        switch (value) {
                          case 'Laborables':
                            _setDays({2, 3, 4, 5, 6});
                            break;
                          case 'Fin de semana':
                            _setDays({1, 7});
                            break;
                          case 'Todos':
                            _setDays({1, 2, 3, 4, 5, 6, 7});
                            break;
                          case 'Limpiar':
                            _setDays({});
                            break;
                        }
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'Si la hora final es menor, el bloqueo cruza medianoche.',
                style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
              ),
              if (!_valid)
                Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xs),
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
          child: Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.pop(
                  context,
                  ScheduleDraft(_start, _end, _days.toList()),
                  )
              : null,
          child: Text('Guardar'),
        ),
      ],
    );
  }

  Widget _timeSegmentedBar() {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segment(
              label: 'Inicio',
              time: _start,
              onTap: () => _pickTime(true),
              selected: true,
            ),
          ),
          SizedBox(width: 4),
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
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.sm),
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
          SizedBox(height: AppSpacing.xs),
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
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            SizedBox(height: 2),
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
        duration: Duration(milliseconds: 150),
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
                    offset: Offset(0, 2),
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
