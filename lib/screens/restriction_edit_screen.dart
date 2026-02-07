import 'package:flutter/material.dart';
import 'package:timelock/widgets/limit_picker_dialog.dart';

class RestrictionEditScreen extends StatelessWidget {
  const RestrictionEditScreen({
    super.key,
    required this.appName,
    required this.initial,
  });

  final String appName;
  final Map<String, dynamic> initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LimitPickerDialog(
        appName: appName,
        initial: initial,
        fullScreen: true,
      ),
    );
  }
}
