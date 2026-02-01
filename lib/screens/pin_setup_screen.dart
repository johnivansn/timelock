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
  bool _showSecuritySetup = false;
  String? _error;

  String? _selectedQuestion;
  final _answerController = TextEditingController();

  final List<String> _securityQuestions = [
    '¿Nombre de tu primera mascota?',
    '¿Ciudad donde naciste?',
    '¿Nombre de tu mejor amigo de infancia?',
    '¿Comida favorita?',
    '¿Nombre de tu escuela primaria?',
  ];

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

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

  void _onSecuritySetup() {
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

    setState(() {
      _showSecuritySetup = true;
    });
  }

  void _onBack() {
    if (_showSecuritySetup) {
      setState(() {
        _showSecuritySetup = false;
      });
    } else if (_confirming) {
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

    setState(() => _saving = true);
    try {
      final args = {
        'pin': pinStr,
        'securityQuestion': _selectedQuestion,
        'securityAnswer': _answerController.text.trim().isNotEmpty
            ? _answerController.text.trim()
            : null,
      };

      final success =
          await _ch.invokeMethod<bool>('setupAdminPin', args) ?? false;
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
  bool get _canContinue =>
      _confirming &&
      _currentFilledCount >= _minDigits &&
      _currentFilledCount == _pinFilledCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_showSecuritySetup) {
      return _buildSecuritySetup(colorScheme);
    }

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
                  onPressed: _onBack,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Icon(
            _confirming ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
            color: colorScheme.primary,
            size: 48,
          ),
          const SizedBox(height: 20),
          Text(
            _confirming ? 'Confirma tu PIN' : 'Crea tu PIN',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            _confirming
                ? 'Ingresa el mismo PIN para confirmar'
                : 'Selecciona entre 4 y 6 dígitos',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 40),
          _dotIndicator(colorScheme),
          const SizedBox(height: 12),
          if (_error != null)
            Text(_error!,
                style: TextStyle(fontSize: 13, color: colorScheme.error))
          else
            const SizedBox(height: 18),
          const Spacer(),
          _numpad(colorScheme),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSecuritySetup(ColorScheme colorScheme) {
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
              onPressed: _onBack,
            ),
            title: const Text('Recuperación de PIN',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    border: Border.all(color: colorScheme.primary),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: colorScheme.primary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Opcional pero recomendado',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Si olvidas tu PIN, la pregunta de seguridad reduce el tiempo de espera de 24h a 12h',
                              style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 13,
                                  height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Pregunta de seguridad (opcional)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedQuestion,
                  decoration: InputDecoration(
                    hintText: 'Selecciona una pregunta',
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _securityQuestions.map((q) {
                    return DropdownMenuItem(
                        value: q,
                        child: Text(q, style: const TextStyle(fontSize: 14)));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedQuestion = value);
                  },
                ),
                if (_selectedQuestion != null) ...[
                  const SizedBox(height: 16),
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
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : _onSave,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar y continuar',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: TextButton(
                    onPressed: _saving ? null : _onSave,
                    child: const Text('Omitir pregunta de seguridad'),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dotIndicator(ColorScheme colorScheme) {
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
    );
  }

  Widget _numpad(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: Column(
        children: [
          _numRow([1, 2, 3], colorScheme),
          const SizedBox(height: 12),
          _numRow([4, 5, 6], colorScheme),
          const SizedBox(height: 12),
          _numRow([7, 8, 9], colorScheme),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _numButton(0, colorScheme),
              _backspaceButton(colorScheme),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _saving
                  ? null
                  : (_confirming
                      ? (_canContinue ? _onSecuritySetup : null)
                      : (_canConfirm ? _onConfirmTap : null)),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      _confirming ? 'Siguiente' : 'Confirmar',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numRow(List<int> digits, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits.map((d) => _numButton(d, colorScheme)).toList(),
    );
  }

  Widget _numButton(int digit, ColorScheme colorScheme) {
    return Material(
      color: colorScheme.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () => _onDigit(digit),
        customBorder: const CircleBorder(),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.surfaceVariant, width: 1),
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

  Widget _backspaceButton(ColorScheme colorScheme) {
    return Material(
      color: colorScheme.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: _onBackspace,
        customBorder: const CircleBorder(),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.surfaceVariant, width: 1),
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
