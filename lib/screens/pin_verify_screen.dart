import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timelock/screens/pin_recovery_screen.dart';

class PinVerifyScreen extends StatefulWidget {
  const PinVerifyScreen({super.key, this.reason});

  final String? reason;

  @override
  State<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends State<PinVerifyScreen>
    with SingleTickerProviderStateMixin {
  static const _ch = MethodChannel('app.restriction/config');
  static const _pinLength = 6;

  final List<int?> _pin = List.filled(_pinLength, null);
  bool _verifying = false;
  bool _canStartRecovery = false;
  String? _error;
  int _lockedSeconds = 0;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
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
      final res =
          await _ch.invokeMethod<Map<dynamic, dynamic>>('verifyAdminPin', '');
      if (res == null || !mounted) return;
      final status = res['status'] as String;
      if (status == 'locked') {
        setState(() {
          _lockedSeconds = res['remainingSeconds'] as int;
          _error = 'Bloqueado por ${_formatTime(_lockedSeconds)}';
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
      final res = await _ch.invokeMethod<Map<dynamic, dynamic>>(
          'verifyAdminPin', pinStr);
      if (res == null || !mounted) return;

      final status = res['status'] as String;
      switch (status) {
        case 'success':
          Navigator.pop(context, true);
          return;
        case 'wrong_pin':
          final remaining = res['attemptsRemaining'] as int;
          final canRecover = res['canStartRecovery'] as bool? ?? false;
          if (mounted) {
            setState(() {
              _verifying = false;
              _canStartRecovery = canRecover;
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
              _error = 'Bloqueado por ${_formatTime(secs)}';
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

  void _navigateToRecovery() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PinRecoveryScreen()),
    ).then((recovered) {
      if (recovered == true) {
        Navigator.pop(context, true);
      }
    });
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _lockedSeconds <= 0) return;
      setState(() {
        _lockedSeconds--;
        if (_lockedSeconds <= 0) {
          _error = null;
        } else {
          _error = 'Bloqueado por ${_formatTime(_lockedSeconds)}';
        }
      });
      if (_lockedSeconds > 0) _startCountdown();
    });
  }

  String _formatTime(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
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
      backgroundColor: const Color(0xFF0F0F1A),
      body: Column(
        children: [
          const SizedBox(height: 64),
          IconButton(
            alignment: Alignment.centerLeft,
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context, false),
          ),
          const SizedBox(height: 32),
          Icon(
            isLocked ? Icons.lock : Icons.shield_outlined,
            color: isLocked ? const Color(0xFFE74C3C) : const Color(0xFF6C5CE7),
            size: 48,
          ),
          const SizedBox(height: 20),
          const Text(
            'Modo Administrador',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            widget.reason ?? 'Ingresa tu PIN para continuar',
            style: const TextStyle(fontSize: 14, color: Colors.white38),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (_, child) => Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: child!,
            ),
            child: _dotIndicator(),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Text(_error!,
                style: const TextStyle(fontSize: 13, color: Color(0xFFE74C3C)))
          else
            const SizedBox(height: 18),
          const Spacer(),
          _numpad(isLocked),
          const SizedBox(height: 40),
          if (_canStartRecovery) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: _navigateToRecovery,
              child: const Text('¿Olvidaste tu PIN?'),
            ),
          ],
        ],
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

  Widget _numpad(bool isLocked) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: Column(
        children: [
          _numRow([1, 2, 3], isLocked),
          const SizedBox(height: 12),
          _numRow([4, 5, 6], isLocked),
          const SizedBox(height: 12),
          _numRow([7, 8, 9], isLocked),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _numButton(0, isLocked),
              _backspaceButton(isLocked),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numRow(List<int> digits, bool isLocked) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits.map((d) => _numButton(d, isLocked)).toList(),
    );
  }

  Widget _numButton(int digit, bool isLocked) {
    return GestureDetector(
      onTap: isLocked ? null : () => _onDigit(digit),
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
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: isLocked ? Colors.white24 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _backspaceButton(bool isLocked) {
    return GestureDetector(
      onTap: isLocked ? null : _onBackspace,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF2A2A3E), width: 1),
        ),
        child: Center(
          child: Icon(Icons.backspace_outlined,
              color: isLocked ? Colors.white24 : Colors.white70, size: 22),
        ),
      ),
    );
  }
}
