import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CarouselPickerColumn {
  const CarouselPickerColumn({
    required this.label,
    required this.min,
    required this.max,
    required this.initial,
    this.displayBuilder,
  });

  final String label;
  final int min;
  final int max;
  final int initial;
  final String Function(int value)? displayBuilder;
}

Future<List<int>?> showCarouselPickerDialog({
  required BuildContext context,
  required String title,
  required List<CarouselPickerColumn> columns,
  required Color surfaceColor,
  required Color borderColor,
  required Color textPrimary,
  required Color textSecondary,
  required Color overlayColor,
  String confirmLabel = 'Aplicar tiempo',
}) async {
  if (columns.isEmpty) return null;

  const virtualItems = 10000;
  final selected = <int>[];
  final controllers = <FixedExtentScrollController>[];

  for (final col in columns) {
    final safe = col.initial.clamp(col.min, col.max);
    selected.add(safe);
    final rangeCount = (col.max - col.min + 1).clamp(1, 9999);
    final middleBase = (virtualItems ~/ 2) - ((virtualItems ~/ 2) % rangeCount);
    controllers.add(
      FixedExtentScrollController(initialItem: middleBase + (safe - col.min)),
    );
  }

  try {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: Row(
                      children: List.generate(columns.length, (i) {
                        final col = columns[i];
                        final rangeCount = (col.max - col.min + 1).clamp(1, 9999);
                        return Expanded(
                          child: Column(
                            children: [
                              Text(
                                col.label,
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: CupertinoPicker.builder(
                                  itemExtent: 34,
                                  scrollController: controllers[i],
                                  selectionOverlay:
                                      CupertinoPickerDefaultSelectionOverlay(
                                    background: overlayColor,
                                  ),
                                  onSelectedItemChanged: (index) {
                                    selected[i] = col.min + (index % rangeCount);
                                  },
                                  childCount: virtualItems,
                                  itemBuilder: (_, index) {
                                    final value = col.min + (index % rangeCount);
                                    final text = col.displayBuilder?.call(value) ??
                                        value.toString().padLeft(2, '0');
                                    return Center(
                                      child: Text(
                                        text,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (accepted != true) return null;
    return List<int>.from(selected);
  } finally {
    for (final controller in controllers) {
      controller.dispose();
    }
  }
}
