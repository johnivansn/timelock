import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _ch = MethodChannel('app.restriction/config');

  List<Map<String, dynamic>> _profiles = [];
  bool _loading = true;
  String? _activeProfileId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profiles =
          await _ch.invokeMethod<List<dynamic>>('getProfiles') ?? [];
      final activeId =
          await _ch.invokeMethod<String>('getActiveProfileId') ?? 'default';
      if (mounted) {
        setState(() {
          _profiles =
              profiles.map((e) => Map<String, dynamic>.from(e)).toList();
          _activeProfileId = activeId;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createProfile() async {
    if (_profiles.length >= 5) {
      _showSnack('Máximo 5 perfiles permitidos', isError: true);
      return;
    }
    if (!mounted) return;
    final name = await _showNameDialog(null);
    if (name == null || !mounted) return;

    try {
      await _ch.invokeMethod('createProfile', name);
      await _load();
    } catch (e) {
      if (mounted) _showSnack('Error al crear perfil', isError: true);
    }
  }

  Future<void> _renameProfile(Map<String, dynamic> profile) async {
    if (!mounted) return;
    final name = await _showNameDialog(profile['name'] as String);
    if (name == null || !mounted) return;

    try {
      await _ch.invokeMethod('renameProfile', {
        'id': profile['id'],
        'name': name,
      });
      await _load();
    } catch (_) {
      if (mounted) _showSnack('Error al renombrar perfil', isError: true);
    }
  }

  Future<void> _deleteProfile(Map<String, dynamic> profile) async {
    if (profile['isDefault'] == true) {
      _showSnack('No se puede eliminar el perfil Default', isError: true);
      return;
    }
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar perfil'),
        content: Text(
          '¿Eliminar "${profile['name']}" y todas sus restricciones?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _ch.invokeMethod('deleteProfile', profile['id']);
      await _load();
      _showSnack('Perfil eliminado');
    } catch (_) {
      if (mounted) _showSnack('Error al eliminar perfil', isError: true);
    }
  }

  Future<void> _setActive(Map<String, dynamic> profile) async {
    try {
      await _ch.invokeMethod('setActiveProfile', profile['id']);
      if (mounted) {
        setState(() => _activeProfileId = profile['id']);
        _showSnack('Perfil activo: ${profile['name']}');
      }
    } catch (_) {
      if (mounted) _showSnack('Error al cambiar perfil', isError: true);
    }
  }

  Future<String?> _showNameDialog(String? currentName) async {
    if (!mounted) return null;
    final ctrl = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(currentName != null ? 'Renombrar perfil' : 'Nuevo perfil'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nombre del perfil',
            filled: true,
            fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final val_ = ctrl.text.trim();
              if (val_.isNotEmpty) Navigator.pop(ctx, val_);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
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
            title: const Text('Perfiles',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  border: Border.all(color: colorScheme.primary),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.layers_rounded,
                        color: colorScheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Crea perfiles para diferentes contextos. Solo el perfil activo controla las restricciones.',
                        style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 13,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList.separated(
                itemCount: _profiles.length,
                itemBuilder: (_, i) => _profileCard(_profiles[i], colorScheme),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
              ),
            ),
        ],
      ),
      floatingActionButton: _profiles.length < 5
          ? FloatingActionButton.extended(
              onPressed: _createProfile,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo perfil'),
            )
          : null,
    );
  }

  Widget _profileCard(Map<String, dynamic> profile, ColorScheme colorScheme) {
    final isActive = profile['id'] == _activeProfileId;
    final isDefault = profile['isDefault'] as bool;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(color: colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isActive
                      ? colorScheme.primary.withValues(alpha: 0.2)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    isActive ? Icons.check_rounded : Icons.layers_rounded,
                    color: isActive
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          profile['name'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'DEFAULT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurfaceVariant,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ACTIVO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
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
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: colorScheme.onSurfaceVariant),
                onSelected: (value) {
                  switch (value) {
                    case 'activate':
                      _setActive(profile);
                    case 'rename':
                      _renameProfile(profile);
                    case 'delete':
                      _deleteProfile(profile);
                  }
                },
                itemBuilder: (_) => [
                  if (!isActive)
                    const PopupMenuItem(
                      value: 'activate',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, size: 20),
                          SizedBox(width: 12),
                          Text('Activar'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Renombrar'),
                      ],
                    ),
                  ),
                  if (!isDefault)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              color: colorScheme.error, size: 20),
                          const SizedBox(width: 12),
                          Text('Eliminar',
                              style: TextStyle(color: colorScheme.error)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
