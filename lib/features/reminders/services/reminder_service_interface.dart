abstract class ReminderServiceInterface {
  Future<bool> requestPermissions();
  Future<String> checkPermissions();
  Future<bool> createReminder({
    required String title,
    required DateTime triggerTime,
    Map<String, dynamic>? recurrence,
  });
  Future<void> openSettings();
}
