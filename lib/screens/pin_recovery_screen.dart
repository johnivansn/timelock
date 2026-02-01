import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class PinRecoveryScreen extends StatefulWidget {
  const PinRecoveryScreen({super.key});

  @override
  State<PinRecoveryScreen> createState() => _PinRecoveryScreenState();
}

class _PinRecoveryScreenState extends State<PinRecoveryScreen> {
  static const _ch = MethodChannel('app.restriction/config');

  bool _loading = true;
  bool _inRecovery = false;
  bool _ready = false;
  int _remainingSeconds = 0;
  String? _securityQuestion;
  Timer? _timer;

  final _answerController = TextEditingController();
  final List<int?> _newPin = List.filled(6, null);
  bool _showPinSetup = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final status =
          await _ch.invokeMethod<Map<dynamic, dynamic>>('getRecoveryStatus');
      if (status == null || !mounted) return;

      final inRecovery = status['inRecovery'] as bool? ?? false;
      final ready = status['ready'] as bool? ?? false;
      final remaining = status['remainingSeconds'] as int? ?? 0;
      final question = status['securityQuestion'] as String?;

      setState(() {
        _inRecovery = inRecovery;
        _ready = ready;
        _remainingSeconds = remaining;
        _securityQuestion = question;
        _loading = false;
      });

      if (_inRecovery && !_ready) {
        _startCountdown();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        setState(() => _ready = true);
      }
    });
  }

  Future<void> _startRecovery() async {
    try {
      final result =
          await _ch.invokeMethod<Map<dynamic, dynamic>>('startRecoveryMode');
      if (result == null || !mounted) return;

      final success = result['success'] as bool? ?? false;
      if (success) {
        await _checkStatus();
      } else {
        _showSnack(
            result['error'] as String? ?? 'Error al iniciar recuperación',
            isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Error al iniciar recuperación', isError: true);
    }
  }

  Future<void> _completeRecovery() async {
    final pinStr =
        _newPin.where((d) => d != null).map((d) => d.toString()).join();

    if (pinStr.length < 4) {
      setState(() => _error = 'El PIN debe tener al menos 4 dígitos');
      return;
    }

    setState(() => _saving = true);

    try {
      final args = {
        'newPin': pinStr,
        'securityAnswer': _answerController.text.trim().isNotEmpty
            ? _answerController.text.trim()
            : null,
      };

      final result = await _ch.invokeMethod<Map<dynamic, dynamic>>(
          'completeRecovery', args);
      if (result == null || !mounted) return;

      final success = result['success'] as bool? ?? false;
      if (success && mounted) {
        Navigator.pop(context, true);
      } else {
        final error = result['error'] as String? ?? 'Error desconocido';
        setState(() {
          _saving = false;
          _error = error;
          if (error.contains('Wrong')) {
            _answerController.clear();
          } else {
            _newPin.fillRange(0, _newPin.length, null);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Error inesperado';
        });
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_showPinSetup) {
      return _buildPinSetup(colorScheme);
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            pinned: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Recuperar PIN',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!_inRecovery) ..._buildNotInRecovery(colorScheme),
                if (_inRecovery && !_ready) ..._buildInProgress(colorScheme),
                if (_inRecovery && _ready) ..._buildReady(colorScheme),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNotInRecovery(ColorScheme colorScheme) {
    return [
      Icon(Icons.lock_reset_rounded,
          size: 80, color: colorScheme.primary.withValues(alpha: 0.5)),
      const SizedBox(height: 24),
      Text(
        '¿Olvidaste tu PIN?',
        style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        'Puedes iniciar el proceso de recuperación.\nDeberás esperar 24 horas para crear un nuevo PIN.',
        style: TextStyle(
            fontSize: 15, color: colorScheme.onSurfaceVariant, height: 1.5),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 32),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF39C12).withValues(alpha: 0.1),
          border: Border.all(color: const Color(0xFFF39C12)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFF39C12), size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Importante',
                    style: TextStyle(
                      color: Color(0xFFF39C12),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Durante el período de espera, las restricciones seguirán activas pero no podrás modificarlas.',
                    style: TextStyle(
                        color: Color(0xFFF39C12), fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: _startRecovery,
          icon: const Icon(Icons.timer_rounded),
          label: const Text('Iniciar recuperación (24h)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    ];
  }

  List<Widget> _buildInProgress(ColorScheme colorScheme) {
    return [
      Icon(Icons.hourglass_empty_rounded, size: 80, color: colorScheme.primary),
      const SizedBox(height: 24),
      Text(
        'Recuperación en proceso',
        style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        'Podrás crear un nuevo PIN cuando termine el período de espera',
        style: TextStyle(
            fontSize: 15, color: colorScheme.onSurfaceVariant, height: 1.5),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 32),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              'Tiempo restante',
              style:
                  TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDuration(_remainingSeconds),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildReady(ColorScheme colorScheme) {
    return [
      Icon(Icons.check_circle_rounded, size: 80, color: colorScheme.secondary),
      const SizedBox(height: 24),
      Text(
        'Listo para crear nuevo PIN',
        style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        'El período de espera ha terminado.\nAhora puedes crear un nuevo PIN.',
        style: TextStyle(
            fontSize: 15, color: colorScheme.onSurfaceVariant, height: 1.5),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 32),
      if (_securityQuestion != null) ...[
        Text(
          'Pregunta de seguridad',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _securityQuestion!,
          style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _answerController,
          decoration: InputDecoration(
            hintText: 'Tu respuesta',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
      SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: () => setState(() => _showPinSetup = true),
          icon: const Icon(Icons.lock_reset_rounded),
          label: const Text('Crear nuevo PIN',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    ];
  }

  Widget _buildPinSetup(ColorScheme colorScheme) {
    final filledCount = _newPin.where((d) => d != null).length;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          const SizedBox(height: 64),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () => setState(() {
                    _showPinSetup = false;
                    _newPin.fillRange(0, _newPin.length, null);
                    _error = null;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Icon(Icons.lock_open_rounded, color: colorScheme.primary, size: 48),
          const SizedBox(height: 20),
          Text(
            'Nuevo PIN',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea un PIN de 4 a 6 dígitos',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              final isFilled = i < filledCount;
              final isFocus = i == filledCount;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? colorScheme.primary : colorScheme.surface,
                    border: Border.all(
                      color: isFocus && !isFilled
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      width: 1.5,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Text(_error!,
                style: TextStyle(fontSize: 13, color: colorScheme.error))
          else
            const SizedBox(height: 18),
          const Spacer(),
          _buildNumpad(colorScheme),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildNumpad(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: Column(
        children: [
          _buildNumRow([1, 2, 3], colorScheme),
          const SizedBox(height: 12),
          _buildNumRow([4, 5, 6], colorScheme),
          const SizedBox(height: 12),
          _buildNumRow([7, 8, 9], colorScheme),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNumButton(0, colorScheme),
              _buildBackspaceButton(colorScheme),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _saving || _newPin.where((d) => d != null).length < 4
                  ? null
                  : _completeRecovery,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Confirmar',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumRow(List<int> digits, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits.map((d) => _buildNumButton(d, colorScheme)).toList(),
    );
  }

  Widget _buildNumButton(int digit, ColorScheme colorScheme) {
    return Material(
      color: colorScheme.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () {
          final idx = _newPin.indexWhere((v) => v == null);
          if (idx != -1) {
            setState(() {
              _error = null;
              _newPin[idx] = digit;
            });
          }
        },
        customBorder: const CircleBorder(),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.surfaceContainerHighest, width: 1),
          ),
          child: Center(
            child: Text(
              digit.toString(),
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton(ColorScheme colorScheme) {
    return Material(
      color: colorScheme.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () {
          int idx = -1;
          for (int i = _newPin.length - 1; i >= 0; i--) {
            if (_newPin[i] != null) {
              idx = i;
              break;
            }
          }
          if (idx != -1) {
            setState(() {
              _error = null;
              _newPin[idx] = null;
            });
          }
        },
        customBorder: const CircleBorder(),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.surfaceContainerHighest, width: 1),
          ),
          child: Center(
            child: Icon(Icons.backspace_outlined,
                color: colorScheme.onSurfaceVariant, size: 22),
          ),
        ),
      ),
    );
  }
}
