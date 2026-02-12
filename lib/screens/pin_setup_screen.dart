import 'package:flutter/material.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/app_motion.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  static const _maxDigits = 4;
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

  void _onConfirmTap() {
    if (_pinFilledCount < _minDigits) return;
    setState(() => _confirming = true);
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
      final success = await NativeService.setupAdminPin(pinStr);
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _onBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
              ),
              const Spacer(),
              Icon(
                _confirming ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: AppColors.primary,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _confirming ? 'Confirma tu PIN' : 'Crea tu PIN',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _confirming
                    ? 'Ingresa el mismo PIN para confirmar'
                    : 'Usa 4 dígitos',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _dotIndicator(),
              const SizedBox(height: AppSpacing.md),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                const SizedBox(height: 16),
              const Spacer(),
              _numpad(),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: AnimatedContainer(
            duration: AppMotion.duration(const Duration(milliseconds: 200)),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? AppColors.primary : AppColors.surface,
              border: Border.all(
                color: isFocus && !isFilled
                    ? AppColors.primary
                    : AppColors.surfaceVariant,
                width: 1,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _numpad() {
    final size = _buttonSize(context);
    return Column(
      children: [
        _numRow([1, 2, 3], size),
        const SizedBox(height: AppSpacing.md),
        _numRow([4, 5, 6], size),
        const SizedBox(height: AppSpacing.md),
        _numRow([7, 8, 9], size),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(width: size, height: size),
            _numButton(0, size),
            _backspaceButton(size),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _saving
                ? null
                : (_confirming
                    ? (_canSave ? _onSave : null)
                    : (_canConfirm ? _onConfirmTap : null)),
            child: _saving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_confirming ? 'Guardar PIN' : 'Siguiente'),
          ),
        ),
      ],
    );
  }

  Widget _numRow(List<int> digits, double size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _numButton(d, size)).toList(),
    );
  }

  Widget _numButton(int digit, double size) {
    return InkWell(
      onTap: () => _onDigit(digit),
      customBorder: const CircleBorder(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surfaceVariant, width: 1),
        ),
        child: Center(
          child: Text(
            digit.toString(),
            style: TextStyle(
              fontSize: (size * 0.38).clamp(18, 26),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _backspaceButton(double size) {
    return InkWell(
      onTap: _onBackspace,
      customBorder: const CircleBorder(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surfaceVariant, width: 1),
        ),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: AppColors.textSecondary,
            size: (size * 0.32).clamp(18, 24),
          ),
        ),
      ),
    );
  }

  double _buttonSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final available = width - (AppSpacing.lg * 2);
    final size = (available / 4.2).clamp(52.0, 72.0);
    return size;
  }
}
