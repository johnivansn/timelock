DateTime? parseDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

String formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String formatShortDateLabel(String value) {
  final date = parseDate(value);
  if (date == null) return value;
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic'
  ];
  final month = months[(date.month - 1).clamp(0, 11)];
  return '${date.day} $month ${date.year}';
}

String formatDateRangeLabel(String startDate, String endDate) {
  if (startDate == endDate) return formatShortDateLabel(startDate);
  return '${formatShortDateLabel(startDate)} – ${formatShortDateLabel(endDate)}';
}
