import 'package:flutter/material.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/widgets/app_picker_dialog.dart';

class AppPickerScreen extends StatelessWidget {
  const AppPickerScreen({super.key, required this.excludedPackages});

  final Set<String> excludedPackages;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Selecciona una app'),
      ),
      body: AppPickerDialog(
        excludedPackages: excludedPackages,
        fullScreen: true,
      ),
    );
  }
}
