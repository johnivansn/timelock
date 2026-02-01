import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  static const _ch = MethodChannel('app.restriction/config');
  static const _maxDigits = 6;
  static const _minDigits = 4;

  final List<int?> _pin = List.filled(_maxDigits, null);
  List<int?> _confirm = List.filled(_maxDigits, null);
  bool _confirming = false;
  bool _saving = false;
  String? _error;

  List<int?> get _current => _confirming ? _confirm : _pin;

  int get _pinFilledCount => _pin.where((d) => d != null).length;
  int get _currentFilledCount => _current.where((d) => d != null).length;

  void _onDigit(int d) {
    if (_saving) return;
    final idx = _current.indexWhere((v) => v == null);
    if (idx == -1) return;
    setState(() {
      _error = null;
      _current[idx] = d;
    });
  }

  void _onBackspace() {
    if (_saving) return;
    int idx = -1;
    for (int i = _current.length - 1; i >= 0; i--) {
      if (_current[i] != null) {
        idx = i;
        break;
      }
    }
    if (idx == -1) return;
    setState(() {
      _error = null;
      _current[idx] = null;
    });
  }

  void _onConfirmTap() {
    if (_pinFilledCount < _minDigits) return;
    setState(() {
      _confirming = true;
    });
  }

  void _onBack() {
    if (_confirming) {
      setState(() {
        _confirming = false;
        _confirm = List.filled(_maxDigits, null);
      });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _onSave() async {
    final pinStr = _pin.where((d) => d != null).map((d) => d.toString()).join();
    final confirmStr =
        _confirm.where((d) => d != null).map((d) => d.toString()).join();

    if (pinStr != confirmStr) {
      setState(() {
        _error = 'Los PINs no coinciden';
        _confirm = List.filled(_maxDigits, null);
      });
      return;
    }

    setState(() => _saving = true);
    try {
      final success =
          await _ch.invokeMethod<bool>('setupAdminPin', pinStr) ?? false;
      if (success && mounted) {
        Navigator.pop(context, true);
      } else if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Error al guardar PIN';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Error inesperado';
        });
      }
    }
  }

  bool get _canConfirm => !_confirming && _pinFilledCount >= _minDigits;
  bool get _canSave =>
      _confirming &&
      _currentFilledCount >= _minDigits &&
      _currentFilledCount == _pinFilledCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Column(
        children: [
          const SizedBox(height: 64),
          IconButton(
            alignment: Alignment.centerLeft,
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white70, size: 20),
            onPressed: _onBack,
          ),
          const SizedBox(height: 32),
          Icon(
            _confirming ? Icons.lock_outline : Icons.lock_open_outlined,
            color: const Color(0xFF6C5CE7),
            size: 48,
          ),
          const SizedBox(height: 20),
          Text(
            _confirming ? 'Confirma tu PIN' : 'Crea tu PIN',
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            _confirming
                ? 'Ingresa el mismo PIN para confirmar'
                : 'Selecciona entre 4 y 6 dígitos',
            style: const TextStyle(fontSize: 14, color: Colors.white38),
          ),
          const SizedBox(height: 40),
          _dotIndicator(),
          const SizedBox(height: 12),
          if (_error != null)
            Text(_error!,
                style: const TextStyle(fontSize: 13, color: Color(0xFFE74C3C)))
          else
            const SizedBox(height: 18),
          const Spacer(),
          _numpad(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _dotIndicator() {
    final displayCount = _confirming ? _pinFilledCount : _maxDigits;
    final filled = _currentFilledCount;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(displayCount, (i) {
        final isFilled = i < filled;
        final isFocus = i == filled;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isFilled ? const Color(0xFF6C5CE7) : const Color(0xFF1A1A2E),
              border: Border.all(
                color: isFocus && !isFilled
                    ? const Color(0xFF6C5CE7)
                    : const Color(0xFF2A2A3E),
                width: 1.5,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _numpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: Column(
        children: [
          _numRow([1, 2, 3]),
          const SizedBox(height: 12),
          _numRow([4, 5, 6]),
          const SizedBox(height: 12),
          _numRow([7, 8, 9]),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _numButton(0),
              _backspaceButton(),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving
                  ? null
                  : (_confirming
                      ? (_canSave ? _onSave : null)
                      : (_canConfirm ? _onConfirmTap : null)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                disabledBackgroundColor: const Color(0xFF2A2A3E),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white38,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      _confirming ? 'Guardar PIN' : 'Siguiente',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numRow(List<int> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits.map((d) => _numButton(d)).toList(),
    );
  }

  Widget _numButton(int digit) {
    return GestureDetector(
      onTap: () => _onDigit(digit),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF2A2A3E), width: 1),
        ),
        child: Center(
          child: Text(
            digit.toString(),
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w500, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _backspaceButton() {
    return GestureDetector(
      onTap: _onBackspace,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF2A2A3E), width: 1),
        ),
        child: const Center(
          child:
              Icon(Icons.backspace_outlined, color: Colors.white70, size: 22),
        ),
      ),
    );
  }
}
