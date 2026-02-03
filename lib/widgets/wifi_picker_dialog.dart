import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timelock/theme/app_theme.dart';

class WifiPickerDialog extends StatefulWidget {
  const WifiPickerDialog({
    super.key,
    required this.appName,
    required this.packageName,
    required this.currentSSIDs,
  });

  final String appName;
  final String packageName;
  final List<String> currentSSIDs;

  @override
  State<WifiPickerDialog> createState() => _WifiPickerDialogState();
}

class _WifiPickerDialogState extends State<WifiPickerDialog> {
  static const _ch = MethodChannel('app.restriction/config');

  List<String> _available = [];
  Set<String> _selected = {};
  String? _currentWifi;
  bool _loading = true;
  String _manual = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.currentSSIDs.toSet();
    _load();
  }

  Future<void> _load() async {
    try {
      final networks =
          await _ch.invokeMethod<List<dynamic>>('getSavedWifiNetworks') ?? [];
      final current = await _ch.invokeMethod<String?>('getCurrentWifi');
      if (mounted) {
        setState(() {
          _available = networks.map((e) => e.toString()).toList();
          _currentWifi = current;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(String ssid) {
    setState(() {
      if (_selected.contains(ssid)) {
        _selected.remove(ssid);
      } else {
        _selected.add(ssid);
      }
    });
  }

  void _addManual() {
    final trimmed = _manual.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _selected.add(trimmed);
      if (!_available.contains(trimmed)) _available.insert(0, trimmed);
      _manual = '';
    });
  }

  Future<void> _save() async {
    try {
      await _ch.invokeMethod('updateRestrictionWifi', {
        'packageName': widget.packageName,
        'blockedWifiSSIDs': _selected.toList(),
      });
      if (mounted) Navigator.pop(context, _selected.toList());
    } catch (_) {
      if (mounted) Navigator.pop(context, _selected.toList());
    }
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bloqueo por WiFi',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          widget.appName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_currentWifi != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_rounded,
                              color: AppColors.success, size: 16),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            _currentWifi!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: _manual),
                      onChanged: (v) => setState(() => _manual = v),
                      onSubmitted: (_) => _addManual(),
                      decoration: const InputDecoration(
                        hintText: 'Agregar red manualmente...',
                        prefixIcon: Icon(Icons.wifi_outlined, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    onPressed: _addManual,
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(AppSpacing.md),
                    ),
                  ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 3))
                      : _available.isEmpty
                          ? const Center(
                              child: Text(
                                'No hay redes guardadas\nAgrega una manualmente',
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg),
                              itemCount: _available.length,
                              itemBuilder: (_, i) =>
                                  _networkTile(_available[i]),
                            ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(
                        _selected.isEmpty
                            ? 'Guardar sin redes'
                            : 'Guardar ${_selected.length} red${_selected.length == 1 ? '' : 'es'}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
      )
    );
  }

  Widget _networkTile(String ssid) {
    final isSelected = _selected.contains(ssid);
    final isCurrent = ssid == _currentWifi;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => _toggle(ssid),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: isSelected
              ? BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 2),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                )
              : null,
          child: Row(
            children: [
              Icon(
                Icons.wifi_rounded,
                color: isCurrent ? AppColors.success : AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            ssid,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ACTUAL',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
