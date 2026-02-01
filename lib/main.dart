import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const AppTimeControlApp());
}

class AppTimeControlApp extends StatelessWidget {
  const AppTimeControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppTimeControl',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const platform = MethodChannel('app.restriction/config');
  List<Map<String, dynamic>> restrictions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final hasUsagePermission = await _checkPermission();
    if (!hasUsagePermission) {
      await _requestPermission();
    }

    final hasAccessibilityPermission = await _checkAccessibilityPermission();
    if (!hasAccessibilityPermission) {
      await _requestAccessibilityPermission();
    }

    await _startMonitoring();
    await _loadRestrictions();
  }

  Future<bool> _checkPermission() async {
    try {
      final bool result = await platform.invokeMethod('checkUsagePermission');
      return result;
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return false;
    }
  }

  Future<void> _requestPermission() async {
    try {
      await platform.invokeMethod('requestUsagePermission');
    } catch (e) {
      debugPrint('Error requesting permission: $e');
      _showError('Error al solicitar permisos: $e');
    }
  }

  Future<bool> _checkAccessibilityPermission() async {
    try {
      final bool result =
          await platform.invokeMethod('checkAccessibilityPermission');
      return result;
    } catch (e) {
      debugPrint('Error checking accessibility permission: $e');
      return false;
    }
  }

  Future<void> _requestAccessibilityPermission() async {
    try {
      await platform.invokeMethod('requestAccessibilityPermission');
    } catch (e) {
      debugPrint('Error requesting accessibility permission: $e');
      _showError('Error al solicitar permisos de accesibilidad: $e');
    }
  }

  Future<void> _startMonitoring() async {
    try {
      await platform.invokeMethod('startMonitoring');
      debugPrint('Monitoring service started successfully');
    } catch (e) {
      debugPrint('Error starting monitoring: $e');
      _showError('Error al iniciar monitoreo: $e');
    }
  }

  Future<void> _loadRestrictions() async {
    try {
      final List<dynamic> result =
          await platform.invokeMethod('getRestrictions');
      setState(() {
        restrictions = result.map((e) => Map<String, dynamic>.from(e)).toList();
        isLoading = false;
      });
      debugPrint('Loaded ${restrictions.length} restrictions');
    } on PlatformException catch (e) {
      debugPrint('PlatformException loading restrictions: ${e.message}');
      setState(() {
        isLoading = false;
      });
      _showError('Error al cargar restricciones: ${e.message}');
    } catch (e) {
      debugPrint('Error loading restrictions: $e');
      setState(() {
        isLoading = false;
      });
      _showError('Error inesperado: $e');
    }
  }

  Future<void> _addRestriction(
      String packageName, String appName, int minutes) async {
    try {
      await platform.invokeMethod('addRestriction', {
        'packageName': packageName,
        'appName': appName,
        'dailyQuotaMinutes': minutes,
        'isEnabled': true,
        'blockedWifiSSIDs': [],
      });
      await _loadRestrictions();
      _showSuccess('Restricción agregada correctamente');
      debugPrint('Restriction added: $appName ($minutes min)');
    } on PlatformException catch (e) {
      debugPrint('PlatformException adding restriction: ${e.message}');
      _showError('Error al agregar restricción: ${e.message}');
    } catch (e) {
      debugPrint('Error adding restriction: $e');
      _showError('Error inesperado: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AppTimeControl'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : restrictions.isEmpty
              ? const Center(
                  child: Text(
                    'No hay restricciones configuradas',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: restrictions.length,
                  itemBuilder: (context, index) {
                    final restriction = restrictions[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(restriction['appName']),
                        subtitle: Text(
                            '${restriction['dailyQuotaMinutes']} minutos/día'),
                        trailing: Switch(
                          value: restriction['isEnabled'],
                          onChanged: (value) {},
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog() {
    final packageController = TextEditingController();
    final nameController = TextEditingController();
    final minutesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Restricción'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: packageController,
              decoration: const InputDecoration(labelText: 'Package Name'),
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'App Name'),
            ),
            TextField(
              controller: minutesController,
              decoration: const InputDecoration(labelText: 'Minutos diarios'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (packageController.text.isEmpty ||
                  nameController.text.isEmpty ||
                  minutesController.text.isEmpty) {
                _showError('Todos los campos son obligatorios');
                return;
              }

              final minutes = int.tryParse(minutesController.text);
              if (minutes == null || minutes < 5 || minutes > 480) {
                _showError('Los minutos deben estar entre 5 y 480');
                return;
              }

              _addRestriction(
                packageController.text,
                nameController.text,
                minutes,
              );
              Navigator.pop(context);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }
}
