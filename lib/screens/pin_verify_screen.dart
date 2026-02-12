import 'package:flutter/material.dart';
import 'package:timelock/services/native_service.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/utils/app_motion.dart';
import 'package:timelock/utils/app_utils.dart';

class PinVerifyScreen extends StatefulWidget {
  const PinVerifyScreen({super.key, this.reason});

  final String? reason;

  @override
  State<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends State<PinVerifyScreen>
    with SingleTickerProviderStateMixin {
  static const _pinLength = 6;

  final List<int?> _pin = List.filled(_pinLength, null);
  bool _verifying = false;
  String? _error;
  int _lockedSeconds = 0;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: AppMotion.duration(const Duration(milliseconds: 400)),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -6.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 25),
    ]).animate(
        CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
    _checkLockStatus();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _checkLockStatus() async {
    try {
      final res = await NativeService.verifyAdminPin('');
      if (!mounted) return;
      final status = res['status'] as String;
      if (status == 'locked') {
        setState(() {
          _lockedSeconds = res['remainingSeconds'] as int;
          _error =
              'Bloqueado por ${AppUtils.formatDurationMillis(_lockedSeconds * 1000)}';
        });
        _startCountdown();
      }
    } catch (_) {}
  }

  Future<void> _verify() async {
    if (_verifying || _lockedSeconds > 0) return;
    final pinStr = _pin.where((d) => d != null).map((d) => d.toString()).join();

    setState(() => _verifying = true);
    try {
      final res = await NativeService.verifyAdminPin(pinStr);
      if (!mounted) return;

      final status = res['status'] as String;
      switch (status) {
        case 'success':
          Navigator.pop(context, true);
          return;
        case 'wrong_pin':
          final remaining = res['attemptsRemaining'] as int;
          if (mounted) {
            setState(() {
              _verifying = false;
              _error =
                  'PIN incorrecto. $remaining intento${remaining == 1 ? '' : 's'} restante${remaining == 1 ? '' : 's'}';
              _clearPin();
            });
            _shakeController.forward(from: 0);
          }
          break;
        case 'locked':
          final secs = res['remainingSeconds'] as int;
          if (mounted) {
            setState(() {
              _verifying = false;
              _lockedSeconds = secs;
              _error =
                  'Bloqueado por ${AppUtils.formatDurationMillis(secs * 1000)}';
              _clearPin();
            });
            _shakeController.forward(from: 0);
            _startCountdown();
          }
          break;
      }
    } catch (_) {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _clearPin() {
    for (int i = 0; i < _pin.length; i++) {
      _pin[i] = null;
    }
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _lockedSeconds <= 0) return;
      setState(() {
        _lockedSeconds--;
        if (_lockedSeconds <= 0) {
          _error = null;
        } else {
          _error =
              'Bloqueado por ${AppUtils.formatDurationMillis(_lockedSeconds * 1000)}';
        }
      });
      if (_lockedSeconds > 0) _startCountdown();
    });
  }

  void _onDigit(int d) {
    if (_verifying || _lockedSeconds > 0) return;
    final idx = _pin.indexWhere((v) => v == null);
    if (idx == -1) return;
    setState(() {
      _error = null;
      _pin[idx] = d;
    });
    if (idx == _pinLength - 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
    }
  }

  void _onBackspace() {
    if (_verifying || _lockedSeconds > 0) return;
    int idx = -1;
    for (int i = _pin.length - 1; i >= 0; i--) {
      if (_pin[i] != null) {
        idx = i;
        break;
      }
    }
    if (idx == -1) return;
    setState(() {
      _error = null;
      _pin[idx] = null;
    });
  }

  int get _filledCount => _pin.where((d) => d != null).length;

  @override
  Widget build(BuildContext context) {
    final isLocked = _lockedSeconds > 0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
              ),
              const Spacer(),
              Icon(
                isLocked ? Icons.lock_clock_rounded : Icons.shield_rounded,
                color: isLocked ? AppColors.error : AppColors.primary,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Modo Administrador',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.reason ?? 'Ingresa tu PIN para continuar',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (_, child) => Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child!,
                ),
                child: _dotIndicator(),
              ),
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
              _numpad(isLocked),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dotIndicator() {
    final filled = _filledCount;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (i) {
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

  Widget _numpad(bool isLocked) {
    final size = _buttonSize(context);
    return Column(
      children: [
        _numRow([1, 2, 3], isLocked, size),
        const SizedBox(height: AppSpacing.md),
        _numRow([4, 5, 6], isLocked, size),
        const SizedBox(height: AppSpacing.md),
        _numRow([7, 8, 9], isLocked, size),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(width: size, height: size),
            _numButton(0, isLocked, size),
            _backspaceButton(isLocked, size),
          ],
        ),
      ],
    );
  }

  Widget _numRow(List<int> digits, bool isLocked, double size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _numButton(d, isLocked, size)).toList(),
    );
  }

  Widget _numButton(int digit, bool isLocked, double size) {
    return InkWell(
      onTap: isLocked ? null : () => _onDigit(digit),
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
              color: isLocked ? AppColors.textTertiary : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _backspaceButton(bool isLocked, double size) {
    return InkWell(
      onTap: isLocked ? null : _onBackspace,
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
            color: isLocked ? AppColors.textTertiary : AppColors.textSecondary,
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
