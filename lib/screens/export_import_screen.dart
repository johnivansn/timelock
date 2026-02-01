import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class ExportImportScreen extends StatefulWidget {
  const ExportImportScreen({super.key});

  @override
  State<ExportImportScreen> createState() => _ExportImportScreenState();
}

class _ExportImportScreenState extends State<ExportImportScreen> {
  static const _ch = MethodChannel('app.restriction/config');

  bool _exporting = false;
  bool _importing = false;
  String? _lastExportJson;
  String? _feedback;
  bool _feedbackIsError = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final json = await _ch.invokeMethod<String>('exportConfig');
      if (json != null && mounted) {
        setState(() {
          _lastExportJson = json;
          _exporting = false;
        });
        await _shareJson(json);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _exporting = false);
        _show('Error al exportar', isError: true);
      }
    }
  }

  Future<void> _shareJson(String json) async {
    await Clipboard.setData(ClipboardData(text: json));
    _show('Copiado al portapapeles');
  }

  Future<void> _copyToClipboard() async {
    if (_lastExportJson == null) return;
    await Clipboard.setData(ClipboardData(text: _lastExportJson!));
    _show('Copiado al portapapeles');
  }

  Future<void> _pasteAndImport() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _show('Portapapeles vacío', isError: true);
      return;
    }
    await _importJson(text);
  }

  Future<void> _importFromText(String json) async {
    await _importJson(json);
  }

  Future<void> _importJson(String json) async {
    try {
      jsonDecode(json);
    } catch (_) {
      _show('JSON inválido', isError: true);
      return;
    }

    setState(() => _importing = true);
    try {
      final res =
          await _ch.invokeMethod<Map<dynamic, dynamic>>('importConfig', json);
      if (res == null || !mounted) return;
      setState(() => _importing = false);

      final success = res['success'] as bool? ?? false;
      if (success) {
        final imported = res['imported'] as int? ?? 0;
        final skipped = res['skipped'] as int? ?? 0;
        if (skipped > 0) {
          _show('Importado: $imported | Ya existían: $skipped');
        } else {
          _show(
              'Importado correctamente: $imported restricción${imported == 1 ? '' : 'es'}');
        }
      } else {
        _show(res['error'] as String? ?? 'Error desconocido', isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _importing = false);
        _show('Error al importar', isError: true);
      }
    }
  }

  void _show(String msg, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _feedback = msg;
      _feedbackIsError = isError;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _feedback = null);
    });
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x1A6C5CE7),
        border: Border.all(color: const Color(0xFF6C5CE7), width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sync_outlined, color: Color(0xFF6C5CE7), size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Exporta y comparte tu configuración entre dispositivos o como respaldo',
              style: TextStyle(
                  color: Color(0xFF6C5CE7), fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0x1A6C5CE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.upload_outlined,
                      size: 22, color: Color(0xFF6C5CE7)),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exportar configuración',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                    Text(
                      'Genera un archivo JSON con todas tus restricciones',
                      style: TextStyle(
                          fontSize: 12, color: Colors.white38, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.share_outlined,
                  label: 'Compartir',
                  color: const Color(0xFF6C5CE7),
                  loading: _exporting,
                  onTap: _export,
                ),
              ),
              if (_lastExportJson != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _actionButton(
                    icon: Icons.copy_outlined,
                    label: 'Copiar',
                    color: const Color(0xFF2A2A3E),
                    onTap: _copyToClipboard,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _importCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0x1A27AE60),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.download_outlined,
                      size: 22, color: Color(0xFF27AE60)),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Importar configuración',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                    Text(
                      'Pega el JSON exportado para restaurar restricciones',
                      style: TextStyle(
                          fontSize: 12, color: Colors.white38, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _actionButton(
            icon: Icons.paste_outlined,
            label: 'Pegar desde portapapeles',
            color: const Color(0xFF27AE60),
            loading: _importing,
            onTap: _pasteAndImport,
            full: true,
          ),
        ],
      ),
    );
  }

  Widget _notesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _noteItem(
              'Las restricciones importadas no sobreescriben las existentes'),
          const SizedBox(height: 10),
          _noteItem('El modo administrador (PIN) no se exporta por seguridad'),
          const SizedBox(height: 10),
          _noteItem('Los contadores de uso diario no se exportan'),
          const SizedBox(height: 10),
          _noteItem(
              'Las redes WiFi bloqueadas sí se incluyen en la exportación'),
        ],
      ),
    );
  }

  static Widget _noteItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 4),
        const Icon(Icons.info_outline, color: Colors.white24, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 12, color: Colors.white38, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    bool loading = false,
    bool full = false,
    required VoidCallback onTap,
  }) {
    final isDark = color == const Color(0xFF2A2A3E);
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: full ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            else
              Icon(icon,
                  size: 18, color: isDark ? Colors.white70 : Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: const Color(0xFF0F0F1A),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text(
                  'Export / Import',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _infoCard(),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text(
                    'EXPORTAR',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white38,
                        letterSpacing: 1.0),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _exportCard(),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text(
                    'IMPORTAR',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white38,
                        letterSpacing: 1.0),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _importCard(),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text(
                    'NOTAS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white38,
                        letterSpacing: 1.0),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _notesCard(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
          if (_feedback != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: AnimatedOpacity(
                opacity: _feedback != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: _feedbackIsError
                        ? const Color(0xFFE74C3C)
                        : const Color(0xFF27AE60),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                          _feedbackIsError
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                          color: Colors.white,
                          size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _feedback!,
                          style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
