import 'package:flutter/services.dart';
import 'reminder_service_interface.dart';

class ReminderService implements ReminderServiceInterface {
  static const _channel = MethodChannel('com.braindump.reminders');

  @override
  Future<bool> requestPermissions() async {
    try {
      final result = await _channel.invokeMethod('requestPermissions');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> checkPermissions() async {
    try {
      final result = await _channel.invokeMethod('checkPermissions');
      return result as String;
    } catch (e) {
      return 'unknown';
    }
  }

  @override
  Future<bool> createReminder({
    required String title,
    required DateTime triggerTime,
    Map<String, dynamic>? recurrence,
  }) async {
    try {
      final result = await _channel.invokeMethod('createReminder', {
        'title': title,
        'trigger_time': triggerTime.toIso8601String(),
        'recurrence': recurrence,
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> openSettings() async {
    await _channel.invokeMethod('openSettings');
  }
}
