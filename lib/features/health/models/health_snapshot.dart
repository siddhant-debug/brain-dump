class SleepSummary {
  final double totalHours;
  final double deepHours;
  final double remHours;
  final double awakeHours;

  SleepSummary({
    required this.totalHours,
    required this.deepHours,
    required this.remHours,
    required this.awakeHours,
  });

  factory SleepSummary.fromMap(Map<Object?, Object?> map) {
    return SleepSummary(
      totalHours: (map['total_hours'] as num?)?.toDouble() ?? 0.0,
      deepHours: (map['deep_hours'] as num?)?.toDouble() ?? 0.0,
      remHours: (map['rem_hours'] as num?)?.toDouble() ?? 0.0,
      awakeHours: (map['awake_hours'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_hours': totalHours,
    'deep_hours': deepHours,
    'rem_hours': remHours,
    'awake_hours': awakeHours,
  };
}

class WorkoutSummary {
  final String type;
  final double durationMinutes;
  final double? calories;

  WorkoutSummary({
    required this.type,
    required this.durationMinutes,
    this.calories,
  });

  factory WorkoutSummary.fromMap(Map<Object?, Object?> map) {
    return WorkoutSummary(
      type: map['type'] as String? ?? 'Unknown',
      durationMinutes: (map['duration_minutes'] as num?)?.toDouble() ?? 0.0,
      calories: (map['calories'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'duration_minutes': durationMinutes,
    'calories': calories,
  };
}

class HealthSnapshot {
  final double? heartRateCurrent;
  final double? heartRateAvg24h;
  final double? restingHeartRate;
  final double? hrvCurrent;
  final double? hrvAvg7d;
  final SleepSummary? lastNightSleep;
  final int? stepsToday;
  final double? activeEnergyToday;
  final double? weightKg;
  final double? heightCm;
  final WorkoutSummary? lastWorkout;
  final Set<String> authorizedTypes;
  final DateTime fetchedAt;

  HealthSnapshot({
    this.heartRateCurrent,
    this.heartRateAvg24h,
    this.restingHeartRate,
    this.hrvCurrent,
    this.hrvAvg7d,
    this.lastNightSleep,
    this.stepsToday,
    this.activeEnergyToday,
    this.weightKg,
    this.heightCm,
    this.lastWorkout,
    required this.authorizedTypes,
    required this.fetchedAt,
  });

  String get readinessLabel {
    int score = 0;
    int factors = 0;

    if (restingHeartRate != null) {
      factors++;
      if (restingHeartRate! < 65) {
        score += 2;
      } else if (restingHeartRate! < 75) {
        score += 1;
      }
    }
    if (stepsToday != null) {
      factors++;
      if (stepsToday! >= 8000) {
        score += 2;
      } else if (stepsToday! >= 4000) {
        score += 1;
      }
    }
    if (activeEnergyToday != null) {
      factors++;
      if (activeEnergyToday! >= 500) {
        score += 2;
      } else if (activeEnergyToday! >= 250) {
        score += 1;
      }
    }
    if (lastNightSleep != null) {
      factors++;
      if (lastNightSleep!.totalHours >= 7.5) {
        score += 2;
      } else if (lastNightSleep!.totalHours >= 6.0) {
        score += 1;
      }
    }
    if (hrvCurrent != null && hrvAvg7d != null) {
      factors++;
      if (hrvCurrent! >= hrvAvg7d!) {
        score += 2;
      } else if (hrvCurrent! >= hrvAvg7d! * 0.85) {
        score += 1;
      }
    }

    // Need at least 2 real data points to make a meaningful judgment
    if (factors < 2) return 'SYNCING';
    final ratio = score / (factors * 2);
    if (ratio >= 0.7) return 'HIGH';
    if (ratio >= 0.4) return 'MODERATE';
    return 'LOW';
  }

  Map<String, dynamic> toJson() => {
    'readiness': readinessLabel,
    'heart_rate': {
      'current': heartRateCurrent,
      'avg_24h': heartRateAvg24h,
      'resting': restingHeartRate,
    },
    'hrv': {'current': hrvCurrent, 'avg_7d': hrvAvg7d},
    'sleep': lastNightSleep?.toJson(),
    'steps_today': stepsToday,
    'active_energy_kcal': activeEnergyToday,
    'weight_kg': weightKg,
    'height_cm': heightCm,
    'last_workout': lastWorkout?.toJson(),
    'fetched_at': fetchedAt.toIso8601String(),
  };
}
