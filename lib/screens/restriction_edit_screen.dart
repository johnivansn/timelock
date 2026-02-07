import 'package:flutter/material.dart';
import 'package:timelock/widgets/limit_picker_dialog.dart';

class RestrictionEditScreen extends StatelessWidget {
  const RestrictionEditScreen({
    super.key,
    required this.appName,
    this.initial,
    this.isCreate = false,
  });

  final String appName;
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
      ),
    );
  }
}
