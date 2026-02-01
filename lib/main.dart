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
    final hasPermission = await _checkPermission();
    if (!hasPermission) {
      await _requestPermission();
    }
    await _startMonitoring();
    await _loadRestrictions();
  }

  Future<bool> _checkPermission() async {
    try {
      final bool result = await platform.invokeMethod('checkUsagePermission');
      return result;
    } catch (e) {
      return false;
    }
  }

  Future<void> _requestPermission() async {
    try {
      await platform.invokeMethod('requestUsagePermission');
    } catch (e) {
      debugPrint('Error requesting permission: $e');
    }
  }

  Future<void> _startMonitoring() async {
    try {
      await platform.invokeMethod('startMonitoring');
    } catch (e) {
      debugPrint('Error starting monitoring: $e');
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
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint('Error loading restrictions: $e');
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
    } catch (e) {
      debugPrint('Error adding restriction: $e');
    }
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
              _addRestriction(
                packageController.text,
                nameController.text,
                int.tryParse(minutesController.text) ?? 30,
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
