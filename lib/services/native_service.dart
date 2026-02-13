import 'package:flutter/services.dart';

class NativeService {
  static Future<Uint8List?> getAppIcon(String packageName) async {
    try {
      return await _channel.invokeMethod<Uint8List>('getAppIcon', packageName);
    } catch (_) {
      return null;
    }
  }

  static const _channel = MethodChannel('app.restriction/config');

  static Future<String?> getRuntimePackageName() async {
    return await _channel.invokeMethod<String>('getRuntimePackageName');
  }

  static Future<Uint8List?> getSelfAppIcon() async {
    try {
      return await _channel.invokeMethod<Uint8List>('getSelfAppIcon');
    } catch (_) {
      return null;
    }
  }

  static Future<bool> checkUsagePermission() async {
    return await _channel.invokeMethod<bool>('checkUsagePermission') ?? false;
  }

  static Future<void> requestUsagePermission() async {
    await _channel.invokeMethod('requestUsagePermission');
  }

  static Future<bool> checkAccessibilityPermission() async {
    return await _channel.invokeMethod<bool>('checkAccessibilityPermission') ??
        false;
  }

  static Future<void> requestAccessibilityPermission() async {
    await _channel.invokeMethod('requestAccessibilityPermission');
  }

  static Future<bool> checkOverlayPermission() async {
    return await _channel.invokeMethod<bool>('checkOverlayPermission') ?? false;
  }

  static Future<int> getMemoryClass() async {
    return await _channel.invokeMethod<int>('getMemoryClass') ?? 0;
  }

  static Future<void> requestOverlayPermission() async {
    await _channel.invokeMethod('requestOverlayPermission');
  }

  static Future<List<Map<String, dynamic>>> getInstalledApps() async {
    final raw =
        await _channel.invokeMethod<List<dynamic>>('getInstalledApps') ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<String?> getAppName(String packageName) async {
    return await _channel.invokeMethod<String>('getAppName', packageName);
  }

  static Future<List<Map<String, dynamic>>> getRestrictions() async {
    final raw =
        await _channel.invokeMethod<List<dynamic>>('getRestrictions') ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> addRestriction(Map<String, dynamic> data) async {
    await _channel.invokeMethod('addRestriction', data);
  }

  static Future<void> updateRestriction(Map<String, dynamic> data) async {
    await _channel.invokeMethod('updateRestriction', data);
  }

  static Future<void> deleteRestriction(String packageName) async {
    await _channel.invokeMethod('deleteRestriction', packageName);
  }

  static Future<Map<String, dynamic>> getUsageToday(String packageName) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getUsageToday', packageName);
    return result?.map((k, v) => MapEntry(k.toString(), v)) ??
        {
          'usedMinutes': 0,
          'isBlocked': false,
          'usedMillis': 0,
          'usedMinutesWeek': 0
        };
  }

  static Future<List<Map<String, dynamic>>> getSchedules(
      String packageName) async {
    final raw = await _channel.invokeMethod<List<dynamic>>(
            'getSchedules', packageName) ??
        [];
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> addSchedule(Map<String, dynamic> data) async {
    await _channel.invokeMethod('addSchedule', data);
  }

  static Future<void> updateSchedule(Map<String, dynamic> data) async {
    await _channel.invokeMethod('updateSchedule', data);
  }

  static Future<void> deleteSchedule(String scheduleId) async {
    await _channel.invokeMethod('deleteSchedule', scheduleId);
  }

  static Future<List<Map<String, dynamic>>> getDateBlocks(
      String packageName) async {
    final raw = await _channel.invokeMethod<List<dynamic>>(
            'getDateBlocks', packageName) ??
        [];
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> addDateBlock(Map<String, dynamic> data) async {
    await _channel.invokeMethod('addDateBlock', data);
  }

  static Future<void> updateDateBlock(Map<String, dynamic> data) async {
    await _channel.invokeMethod('updateDateBlock', data);
  }

  static Future<void> deleteDateBlock(String blockId) async {
    await _channel.invokeMethod('deleteDateBlock', blockId);
  }

  static Future<List<String>> getDirectBlockPackages() async {
    final raw =
        await _channel.invokeMethod<List<dynamic>>('getDirectBlockPackages') ??
            [];
    return raw.map((e) => e.toString()).toList();
  }

  static Future<void> deleteDirectBlocks(String packageName) async {
    await _channel.invokeMethod('deleteDirectBlocks', packageName);
  }

  static Future<List<Map<String, dynamic>>> getBlockTemplates() async {
    final raw =
        await _channel.invokeMethod<List<dynamic>>('getBlockTemplates') ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> saveBlockTemplate(Map<String, dynamic> data) async {
    await _channel.invokeMethod('saveBlockTemplate', data);
  }

  static Future<void> deleteBlockTemplate(String templateId) async {
    await _channel.invokeMethod('deleteBlockTemplate', templateId);
  }

  static Future<int?> getBatteryLevel() async {
    return await _channel.invokeMethod<int>('getBatteryLevel');
  }

  static Future<Map<String, dynamic>> getAppVersion() async {
    final res =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('getAppVersion');
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<List<Map<String, dynamic>>> getReleases() async {
    final res = await _channel.invokeMethod<List<dynamic>>('getReleases') ?? [];
    return res
        .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  static Future<bool> canInstallPackages() async {
    return await _channel.invokeMethod<bool>('canInstallPackages') ?? true;
  }

  static Future<void> requestInstallPermission() async {
    await _channel.invokeMethod('requestInstallPermission');
  }

  static Future<bool> downloadAndInstallApk({
    required String url,
    String? shaUrl,
  }) async {
    return await _channel.invokeMethod<bool>('downloadAndInstallApk', {
          'url': url,
          'shaUrl': shaUrl,
        }) ??
        false;
  }

  static Future<bool> downloadApkOnly({
    required String url,
    String? fileName,
  }) async {
    return await _channel.invokeMethod<bool>('downloadApkOnly', {
          'url': url,
          'fileName': fileName,
        }) ??
        false;
  }

  static Future<bool> isAdminEnabled() async {
    return await _channel.invokeMethod<bool>('isAdminEnabled') ?? false;
  }

  static Future<bool> setupAdminPin(String pin) async {
    return await _channel.invokeMethod<bool>('setupAdminPin', pin) ?? false;
  }

  static Future<Map<String, dynamic>> verifyAdminPin(String pin) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'verifyAdminPin', pin);
    return result?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<bool> disableAdmin() async {
    return await _channel.invokeMethod<bool>('disableAdmin') ?? false;
  }

  static Future<String?> exportConfig() async {
    return await _channel.invokeMethod<String>('exportConfig');
  }

  static Future<Map<String, dynamic>> importConfig(String json) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'importConfig', json);
    return result?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<bool> isBatterySaverEnabled() async {
    return await _channel.invokeMethod<bool>('isBatterySaverEnabled') ?? false;
  }

  static Future<void> setBatterySaverMode(bool enabled) async {
    await _channel.invokeMethod('setBatterySaverMode', enabled);
  }

  static Future<Map<String, dynamic>> getOptimizationStats() async {
    final result = await _channel
        .invokeMethod<Map<dynamic, dynamic>>('getOptimizationStats');
    return result?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<void> invalidateCache() async {
    await _channel.invokeMethod('invalidateCache');
  }

  static Future<void> forceCleanup() async {
    await _channel.invokeMethod('forceCleanup');
  }

  static Future<Map<dynamic, dynamic>?> getSharedPreferences(
      String prefsName) async {
    return await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getSharedPreferences', prefsName);
  }

  static Future<void> saveSharedPreference(Map<String, dynamic> data) async {
    await _channel.invokeMethod('saveSharedPreference', data);
  }

  static Future<void> startMonitoring() async {
    await _channel.invokeMethod('startMonitoring');
  }

  static Future<void> refreshWidgetsNow() async {
    await _channel.invokeMethod('refreshWidgetsNow');
  }

  static Future<bool> isDeviceAdminEnabled() async {
    return await _channel.invokeMethod<bool>('isDeviceAdminEnabled') ?? false;
  }

  static Future<void> enableDeviceAdmin() async {
    await _channel.invokeMethod('enableDeviceAdmin');
  }
}
