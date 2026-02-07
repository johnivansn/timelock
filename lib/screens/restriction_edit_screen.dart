import 'package:flutter/material.dart';
import 'package:timelock/widgets/limit_picker_dialog.dart';

class RestrictionEditScreen extends StatelessWidget {
  RestrictionEditScreen({
    super.key,
    required this.appName,
    this.packageName,
    this.initial,
    this.isCreate = false,
  });

  final String appName;
  final String? packageName;
  final Map<String, dynamic>? initial;
  final bool isCreate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LimitPickerDialog(
        appName: appName,
        initial: initial,
        fullScreen: true,
        useEditLayoutForCreate: isCreate,
        packageName: packageName,
      ),
    );
  }
}

