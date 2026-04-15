class ReminderParseResult {
  final String action;
  final DateTime triggerTime;
  final RecurrenceDetails recurrence;

  ReminderParseResult({
    required this.action,
    required this.triggerTime,
    required this.recurrence,
  });

  factory ReminderParseResult.fromJson(Map<String, dynamic> json) {
    return ReminderParseResult(
      action: json['action'] ?? 'Reminder',
      triggerTime: DateTime.parse(json['trigger_time']),
      recurrence: RecurrenceDetails.fromJson(json['recurrence'] ?? {}),
    );
  }
}

class RecurrenceDetails {
  final String? frequency;
  final int interval;
  final List<int>? daysOfWeek;
  final DateTime? endDate;

  RecurrenceDetails({
    this.frequency,
    this.interval = 1,
    this.daysOfWeek,
    this.endDate,
  });

  factory RecurrenceDetails.fromJson(Map<String, dynamic> json) {
    return RecurrenceDetails(
      frequency: json['frequency'],
      interval: json['interval'] ?? 1,
      daysOfWeek: (json['days_of_week'] as List?)?.cast<int>(),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'frequency': frequency,
      'interval': interval,
      'days_of_week': daysOfWeek,
      'end_date': endDate?.toIso8601String(),
    };
  }
}
