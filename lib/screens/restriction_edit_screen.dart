import 'package:flutter/material.dart';
import 'package:timelock/theme/app_theme.dart';
import 'package:timelock/widgets/limit_picker_dialog.dart';

class RestrictionEditScreen extends StatelessWidget {
  const RestrictionEditScreen({
    super.key,
    required this.appName,
    this.packageName,
    this.initial,
    this.isCreate = false,
    this.initialSection = 'limit',
    this.initialDirectTab = 'schedule',
  });

  final String appName;
  final String? packageName;
  final Map<String, dynamic>? initial;
  final bool isCreate;
  final String initialSection;
  final String initialDirectTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LimitPickerDialog(
        appName: appName,
        initial: initial,
        fullScreen: true,
        useEditLayoutForCreate: isCreate,
        packageName: packageName,
        initialSection: initialSection,
        initialDirectTab: initialDirectTab,
      ),
    );
  }
}
