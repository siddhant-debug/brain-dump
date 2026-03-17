import '../models/reminder_parse_result.dart';

enum SmartReminderStatus {
  idle,
  parsing,
  prompting,
  executing,
  success,
  permissionDenied,
  error
}

class SmartReminderState {
  final SmartReminderStatus status;
  final ReminderParseResult? parseResult;
  final String? errorMessage;

  SmartReminderState({
    this.status = SmartReminderStatus.idle,
    this.parseResult,
    this.errorMessage,
  });

  SmartReminderState copyWith({
    SmartReminderStatus? status,
    ReminderParseResult? parseResult,
    String? errorMessage,
  }) {
    return SmartReminderState(
      status: status ?? this.status,
      parseResult: parseResult ?? this.parseResult,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
