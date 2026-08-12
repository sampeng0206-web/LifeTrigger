import 'dart:io';
import 'package:flutter/services.dart';

class ExactAlarmService {
  static const _channel = MethodChannel('com.sampeng.lifetrigger/exact_alarm');

  /// Check if the app currently has permission to schedule exact alarms.
  /// On iOS or Android < 12 (API 31), this always returns `true`.
  static Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool result = await _channel.invokeMethod('canScheduleExactAlarms');
      return result;
    } on PlatformException catch (_) {
      // Fallback to true to prevent blocking if the native call fails
      return true;
    }
  }

  /// Open the system settings page where the user can enable exact alarm permission for this app.
  /// On non-Android or Android < 12, this does nothing.
  static Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openExactAlarmSettings');
    } on PlatformException catch (_) {
      // Silent catch
    }
  }
}
