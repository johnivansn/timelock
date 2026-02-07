import 'package:flutter/material.dart';
import 'package:timelock/widgets/app_picker_dialog.dart';

class AppPickerScreen extends StatelessWidget {
  AppPickerScreen({super.key, required this.excludedPackages});

  final Set<String> excludedPackages;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Selecciona una app'),
      ),
      body: AppPickerDialog(
        excludedPackages: excludedPackages,
        fullScreen: true,
      ),
    );
  }
}

