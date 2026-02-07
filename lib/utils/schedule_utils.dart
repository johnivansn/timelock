import 'package:flutter/material.dart';

List<int> normalizeScheduleDaysList(List<dynamic> rawDays) {
  final days = rawDays.map((e) => int.tryParse(e.toString()) ?? 0).toList();
  final converted = days.contains(0) ? days.map((d) => d + 1).toList() : days;
  return converted.where((d) => d >= 1 && d <= 7).toList();
}

Map<String, dynamic> normalizeScheduleDays(Map<String, dynamic> schedule) {
  final rawDays = schedule['daysOfWeek'] as List<dynamic>? ?? [];
  return {
    ...schedule,
    'daysOfWeek': normalizeScheduleDaysList(rawDays),
  };
}

String formatTime(int hour, int minute) {
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String formatTimeOfDay(TimeOfDay time) {
  return formatTime(time.hour, time.minute);
}

String formatTimeRange(
  int startHour,
  int startMinute,
  int endHour,
  int endMinute, {
  String dash = ' – ',
  String nextDaySuffix = ' (día sig.)',
}) {
  final start = formatTime(startHour, startMinute);
  final end = formatTime(endHour, endMinute);
  if (endHour * 60 + endMinute <= startHour * 60 + startMinute) {
    return '$start$dash$end$nextDaySuffix';
  }
  return '$start$dash$end';
}

String formatDays(
  List<int> days, {
  String separator = ' · ',
  Map<int, String>? labels,
}) {
  if (days.isEmpty) return 'Sin días';
  const defaultLabels = {
    1: 'D',
    2: 'L',
    3: 'M',
    4: 'X',
    5: 'J',
    6: 'V',
    7: 'S',
  };
  final map = labels ?? defaultLabels;
  return days.map((d) => map[d] ?? '?').join(separator);
}
