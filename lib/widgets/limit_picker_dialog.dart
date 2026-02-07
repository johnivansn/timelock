import 'package:flutter/material.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/widgets/time_picker_dialog.dart';

class LimitPickerDialog extends StatefulWidget {
  const LimitPickerDialog({
    super.key,
    required this.appName,
    this.initial,
  });

  final String appName;
  final Map<String, dynamic>? initial;

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
    _dailyQuotas = _parseDailyQuotas(init['dailyQuotas']) ??
        {2: _dailyMinutes, 3: _dailyMinutes, 4: _dailyMinutes, 5: _dailyMinutes, 6: _dailyMinutes};
  }

  @override
  void dispose() {
    _weeklyController.dispose();
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

  Future<void> _pickMinutes(ValueChanged<int> onPicked) async {
    final minutes = await showDialog<int>(
      context: context,
      builder: (_) => const QuotaTimePicker(),
    );
    if (minutes != null) onPicked(minutes);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
            if (_limitType == 'daily') _dailyConfig(),
            if (_limitType == 'weekly') _weeklyConfig(),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Guardar'),
                ),
              ),
            ),
          ],
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
                  onSelected: (_) => setState(() => _dailyMode = 'same'),
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
            _minutesRow(
              label: 'Minutos por día',
              value: _dailyMinutes,
              onTap: () => _pickMinutes((m) => setState(() => _dailyMinutes = m)),
            ),
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
        return Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                dayLabels[day] ?? '?',
                style: const TextStyle(fontSize: 11),
              ),
            ),
            Expanded(
              child: Slider(
                min: 0,
                max: 480,
                divisions: 480,
                value: value.toDouble(),
                label: '${value}m',
                onChanged: (v) =>
                    setState(() => _dailyQuotas[day] = v.round()),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text('${value}m',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  )),
            ),
          ],
        );
      }),
    );
  }

  void _save() {
    final isDaily = _limitType == 'daily';
    final result = <String, dynamic>{
      'limitType': _limitType,
      'dailyMode': _dailyMode,
      'dailyQuotaMinutes': isDaily && _dailyMode == 'same' ? _dailyMinutes : 0,
      'dailyQuotas': isDaily && _dailyMode == 'per_day' ? _dailyQuotas : {},
      'weeklyQuotaMinutes': _weeklyMinutes,
      'weeklyResetDay': _weeklyResetDay,
    };
    Navigator.pop(context, result);
  }
}
