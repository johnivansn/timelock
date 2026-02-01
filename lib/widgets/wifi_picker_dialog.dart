import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          color: const Color(0xFF1A1A2E),
          child: DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.4,
            maxChildSize: 0.8,
            builder: (_, scroll) {
              return Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A3E),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bloqueo por WiFi',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white),
                              ),
                              Text(
                                widget.appName,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.white38),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (_currentWifi != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0x1A27AE60),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.wifi,
                                    color: Color(0xFF27AE60), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  _currentWifi!,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF27AE60),
                                      fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            controller: TextEditingController(text: _manual),
                            onChanged: (v) => setState(() => _manual = v),
                            onSubmitted: (_) => _addManual(),
                            decoration: InputDecoration(
                              hintText: 'Nombre de red manual...',
                              hintStyle: const TextStyle(
                                  color: Colors.white38, fontSize: 13),
                              prefixIcon: const Icon(Icons.wifi_outlined,
                                  color: Colors.white38, size: 20),
                              filled: true,
                              fillColor: const Color(0xFF2A2A3E),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _addManual,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C5CE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(Icons.add,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : _available.isEmpty
                            ? const Center(
                                child: Text(
                                  'No se encontraron redes guardadas.\nAgrega una manualmente.',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.builder(
                                controller: scroll,
                                itemCount: _available.length,
                                itemBuilder: (_, i) =>
                                    _networkTile(_available[i]),
                              ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(
                          _selected.isEmpty
                              ? 'Guardar (sin redes)'
                              : 'Guardar — ${_selected.length} red${_selected.length == 1 ? '' : 'es'}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _networkTile(String ssid) {
    final isSelected = _selected.contains(ssid);
    final isCurrent = ssid == _currentWifi;

    return InkWell(
      onTap: () => _toggle(ssid),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0x1A6C5CE7) : null,
            border: isSelected
                ? Border.all(color: const Color(0xFF6C5CE7), width: 1)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.wifi,
                color: isCurrent ? const Color(0xFF27AE60) : Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        ssid,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0x1A27AE60),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'actual',
                          style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF27AE60),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? const Color(0xFF6C5CE7) : Colors.white24,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
