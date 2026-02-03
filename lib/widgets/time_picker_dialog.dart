import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timelock/theme/app_theme.dart';

class QuotaTimePicker extends StatefulWidget {
  const QuotaTimePicker({super.key});

  @override
  State<QuotaTimePicker> createState() => _QuotaTimePickerState();
}

class _QuotaTimePickerState extends State<QuotaTimePicker> {
  static const _presets = [5, 10, 15, 30, 60, 120];
  int? _selected;
  int _custom = 30;
  bool _useCustom = false;

  void _pick(int val) {
    setState(() {
      _selected = val;
      _useCustom = false;
    });
  }

  void _pickCustom() {
    setState(() {
      _useCustom = true;
      _selected = null;
    });
  }

  int get _value => _useCustom ? _custom : (_selected ?? _custom);

  bool get _valid => _value >= 5 && _value <= 480;

  String _label(int m) {
    if (m >= 60) {
      final h = m ~/ 60;
      final rem = m % 60;
      return rem == 0 ? '${h}h' : '${h}h ${rem}m';
    }
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Tiempo diario',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Selecciona el límite máximo de uso',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _presets.map((p) => _presetChip(p)).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            _customRow(),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _valid ? () => Navigator.pop(context, _value) : null,
                child: Text('Confirmar — ${_label(_value)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(int minutes) {
    final isActive = !_useCustom && _selected == minutes;
    return FilterChip(
      label: Text(_label(minutes)),
      selected: isActive,
      onSelected: (_) => _pick(minutes),
      backgroundColor: AppColors.surfaceVariant,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: isActive ? Colors.white : AppColors.textSecondary,
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }

  Widget _customRow() {
    return Row(
      children: [
        FilterChip(
          label: const Text('Personalizado'),
          selected: _useCustom,
          onSelected: (_) => _pickCustom(),
          backgroundColor: AppColors.surfaceVariant,
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _useCustom ? Colors.white : AppColors.textSecondary,
          ),
        ),
        if (_useCustom) ...[
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_rounded),
                  onPressed: _custom > 5
                      ? () =>
                          setState(() => _custom = (_custom - 5).clamp(5, 480))
                      : null,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    controller: TextEditingController(text: _custom.toString()),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null) setState(() => _custom = n.clamp(5, 480));
                    },
                    decoration: const InputDecoration(
                      suffixText: 'min',
                      contentPadding:
                          EdgeInsets.symmetric(vertical: AppSpacing.md),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: _custom < 480
                      ? () =>
                          setState(() => _custom = (_custom + 5).clamp(5, 480))
                      : null,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
