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

  static Future<void> requestOverlayPermission() async {
    await _channel.invokeMethod('requestOverlayPermission');
  }


  static Future<List<Map<String, dynamic>>> getInstalledApps() async {
    final raw =
        await _channel.invokeMethod<List<dynamic>>('getInstalledApps') ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<List<Map<String, dynamic>>> getRestrictions() async {
    final raw =
        await _channel.invokeMethod<List<dynamic>>('getRestrictions') ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> addRestriction(Map<String, dynamic> data) async {
    await _channel.invokeMethod('addRestriction', data);
  }

  static Future<void> deleteRestriction(String packageName) async {
    await _channel.invokeMethod('deleteRestriction', packageName);
  }

  static Future<Map<String, dynamic>> getUsageToday(String packageName) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getUsageToday', packageName);
    return result?.map((k, v) => MapEntry(k.toString(), v)) ??
        {'usedMinutes': 0, 'isBlocked': false};
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

  static Future<bool> isDeviceAdminEnabled() async {
    return await _channel.invokeMethod<bool>('isDeviceAdminEnabled') ?? false;
  }

  static Future<void> enableDeviceAdmin() async {
    await _channel.invokeMethod('enableDeviceAdmin');
  }

  static Future<bool> isDeviceOwner() async {
    return await _channel.invokeMethod<bool>('isDeviceOwner') ?? false;
  }

  static Future<bool> setUninstallBlocked(bool enabled) async {
    return await _channel.invokeMethod<bool>('setUninstallBlocked', enabled) ??
        false;
  }
}
