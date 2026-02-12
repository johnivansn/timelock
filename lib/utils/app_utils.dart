class AppUtils {
  static String formatTime(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    }
    return '${minutes}m';
  }

  static String formatDurationMillis(int millis) {
    final totalSeconds = (millis / 1000).floor().clamp(0, 1 << 31);
    var remaining = totalSeconds;
    final days = remaining ~/ 86400;
    remaining %= 86400;
    final hours = remaining ~/ 3600;
    remaining %= 3600;
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;

    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}m');
    if (seconds > 0 || parts.isEmpty) parts.add('${seconds}s');
    return parts.join(' ');
  }

  static DateTime lastWeeklyReset(
      DateTime now, int resetDay, int resetHour, int resetMinute) {
    final targetWeekday = resetDay == 1 ? 7 : resetDay - 1;
    final todayReset =
        DateTime(now.year, now.month, now.day, resetHour, resetMinute);
    final daysBack = (now.weekday - targetWeekday) % 7;
    var candidate = todayReset.subtract(Duration(days: daysBack));
    if (now.isBefore(candidate)) {
      candidate = candidate.subtract(const Duration(days: 7));
    }
    return candidate;
  }

  static String formatWeeklyResetLabel(
      int resetDay, int resetHour, int resetMinute,
      {DateTime? now}) {
    final anchor = lastWeeklyReset(
        now ?? DateTime.now(), resetDay, resetHour, resetMinute);
    const labels = {
      1: 'Lun',
      2: 'Mar',
      3: 'Mié',
      4: 'Jue',
      5: 'Vie',
      6: 'Sáb',
      7: 'Dom',
    };
    final dayLabel = labels[anchor.weekday] ?? 'Día';
    final h = anchor.hour.toString().padLeft(2, '0');
    final m = anchor.minute.toString().padLeft(2, '0');
    return 'desde $dayLabel $h:$m';
  }

  static DateTime nextWeeklyReset(
      DateTime now, int resetDay, int resetHour, int resetMinute) {
    final last = lastWeeklyReset(now, resetDay, resetHour, resetMinute);
    return last.add(const Duration(days: 7));
  }

  static String formatWeeklyNextResetLabel(
      int resetDay, int resetHour, int resetMinute,
      {DateTime? now}) {
    final anchor = nextWeeklyReset(
        now ?? DateTime.now(), resetDay, resetHour, resetMinute);
    const labels = {
      1: 'Lun',
      2: 'Mar',
      3: 'Mié',
      4: 'Jue',
      5: 'Vie',
      6: 'Sáb',
      7: 'Dom',
    };
    final dayLabel = labels[anchor.weekday] ?? 'Día';
    final h = anchor.hour.toString().padLeft(2, '0');
    final m = anchor.minute.toString().padLeft(2, '0');
    return 'hasta $dayLabel $h:$m';
  }

  static String formatUsageText({
    required int usedMinutes,
    required int usedMillis,
    required String limitType,
    required int weeklyResetDay,
    required int weeklyResetHour,
    required int weeklyResetMinute,
    String dailySuffix = '',
  }) {
    if (limitType == 'weekly') {
      final weeklyMillis = usedMinutes * 60000;
      final resetLabel = formatWeeklyResetLabel(
          weeklyResetDay, weeklyResetHour, weeklyResetMinute);
      return '${formatDurationMillis(weeklyMillis)} usados $resetLabel';
    }
    final suffix = dailySuffix.isNotEmpty ? ' $dailySuffix' : '';
    return '${formatDurationMillis(usedMillis)} usados$suffix';
  }

  static String formatRemainingText({
    required int remainingMinutes,
    required int remainingMillis,
    required int quotaMinutes,
    required String limitType,
    required int weeklyResetDay,
    required int weeklyResetHour,
    required int weeklyResetMinute,
    String weeklySuffix = 'esta semana',
  }) {
    if (limitType == 'weekly') {
      final nextLabel = formatWeeklyNextResetLabel(
          weeklyResetDay, weeklyResetHour, weeklyResetMinute);
      return '${formatTime(remainingMinutes)} restantes $weeklySuffix ($nextLabel)';
    }
    if (quotaMinutes <= 1) {
      final seconds = (remainingMillis / 1000).ceil();
      return '${seconds}s restantes';
    }
    return '${formatTime(remainingMinutes)} restantes';
  }

  static int computeIconPrefetchCount({
    required double screenWidth,
    required int memoryClassMb,
    required bool powerSave,
  }) {
    int base;
    if (memoryClassMb <= 256) {
      base = 12;
    } else if (memoryClassMb <= 384) {
      base = 20;
    } else {
      base = 30;
    }

    if (screenWidth < 360) {
      base = base.clamp(8, 16);
    }

    if (powerSave) {
      base = (base * 0.5).round().clamp(6, base);
    }

    return base;
  }

  static double computeIconCacheLimitMb({
    required int memoryClassMb,
    required bool powerSave,
  }) {
    double base;
    if (memoryClassMb <= 256) {
      base = 5;
    } else if (memoryClassMb <= 384) {
      base = 10;
    } else {
      base = 20;
    }

    if (powerSave) {
      base *= 0.6;
    }

    return base;
  }
}
