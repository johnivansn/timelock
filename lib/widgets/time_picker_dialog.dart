import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        color: const Color(0xFF1A1A2E),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tiempo diario',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
            const SizedBox(height: 4),
            const Text(
              'Selecciona el límite máximo',
              style: TextStyle(fontSize: 13, color: Colors.white38),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((p) => _presetChip(p)).toList(),
            ),
            const SizedBox(height: 16),
            _customRow(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _valid ? () => Navigator.pop(context, _value) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  disabledBackgroundColor: const Color(0xFF2A2A3E),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white38,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  'Confirmar — ${_label(_value)}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(int minutes) {
    final isActive = !_useCustom && _selected == minutes;
    return GestureDetector(
      onTap: () => _pick(minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6C5CE7) : const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          _label(minutes),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _customRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: _pickCustom,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _useCustom
                  ? const Color(0xFF6C5CE7)
                  : const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Personalizado',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _useCustom ? Colors.white : Colors.white70,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (_useCustom)
          Expanded(
            child: Row(
              children: [
                _iconBtn(Icons.remove, () {
                  if (_custom > 5) {
                    setState(() => _custom = (_custom - 5).clamp(5, 480));
                  }
                }),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    controller: TextEditingController(text: _custom.toString()),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null) setState(() => _custom = n.clamp(5, 480));
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF2A2A3E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      suffixText: 'min',
                      suffixStyle:
                          const TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _iconBtn(Icons.add, () {
                  if (_custom < 480) {
                    setState(() => _custom = (_custom + 5).clamp(5, 480));
                  }
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Icon(icon, color: Colors.white70, size: 18)),
      ),
    );
  }
}
