import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/app_utils.dart';

class QuotaTimePicker extends StatefulWidget {
  const QuotaTimePicker({super.key});

  @override
  State<QuotaTimePicker> createState() => _QuotaTimePickerState();
}

class _QuotaTimePickerState extends State<QuotaTimePicker> {
  static const _presets = [1, 5, 10, 15, 30, 60, 120];
  int? _selected;
  int _custom = 30;
  bool _useCustom = false;
  late final TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController(text: _custom.toString());
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _pick(int val) {
    setState(() {
      _selected = val;
      _useCustom = false;
      _customController.text = _custom.toString();
    });
  }

  void _pickCustom() {
    setState(() {
      _useCustom = true;
      _selected = null;
      _customController.text = _custom.toString();
    });
  }

  int get _value => _useCustom ? _custom : (_selected ?? _custom);

  bool get _valid => _value >= 1 && _value <= 480;

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
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Tiempo diario',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Selecciona el límite máximo de uso',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _presets.map((p) => _presetChip(p)).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            _customRow(),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: _valid ? () => Navigator.pop(context, _value) : null,
                child: Text('Confirmar — ${AppUtils.formatTime(_value)}'),
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
      label: Text(AppUtils.formatTime(minutes)),
      selected: isActive,
      onSelected: (_) => _pick(minutes),
      backgroundColor: AppColors.surfaceVariant,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isActive ? Colors.white : AppColors.textSecondary,
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
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
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _useCustom ? Colors.white : AppColors.textSecondary,
          ),
        ),
        if (_useCustom) ...[
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              controller: _customController,
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null) {
                  setState(() => _custom = n.clamp(1, 480));
                }
              },
              decoration: const InputDecoration(
                suffixText: 'min',
                contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
