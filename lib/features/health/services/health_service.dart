import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/health_snapshot.dart';
import 'health_service_interface.dart';

class HealthService implements HealthServiceInterface {
  static const _channel = MethodChannel('com.braindump.health');

  @override
  Future<bool> requestAuthorization() async {
    try {
      final result = await _channel.invokeMethod('requestAuthorization');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint(
        '[HealthService] PlatformException requesting auth: ${e.message}',
      );
      throw Exception(e.message ?? 'Unknown HealthKit Error');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<Map<String, String>> checkAuthorization() async {
    try {
      final statusMap = await _channel.invokeMethod('checkAuthorizationStatus');
      if (statusMap is Map) {
        return Map<String, String>.from(statusMap);
      }
      return {};
    } catch (e) {
      debugPrint('[HealthService] Error checking authorization: $e');
      return {};
    }
  }

  @override
  Future<Set<String>> getAuthorizedTypes() async {
    final statusMap = await checkAuthorization();
    return statusMap.entries
        .where((e) => e.value == 'authorized')
        .map((e) => e.key)
        .toSet();
  }

  @override
  Future<void> reinitAfterAuthorization() async {
    // No-op for HealthKit — no tokens to refresh.
  }

  @override
  Future<String> getRawDebugState() async {
    try {
      final statuses = await checkAuthorization();
      return 'Auth Statuses: $statuses';
    } catch (e) {
      return 'Raw State Error: $e';
    }
  }

  @override
  Future<HealthSnapshot?> getLatestSnapshot() async {
    try {
      // Fetch all concurrently — includes every field the model now tracks
      final responses = await Future.wait([
        _channel.invokeMethod('getHeartRate'), // 0
        _channel.invokeMethod('getHRV'), // 1
        _channel.invokeMethod('getSleep'), // 2
        _channel.invokeMethod('getSteps'), // 3
        _channel.invokeMethod('getActiveEnergy'), // 4
        _channel.invokeMethod('getWorkouts'), // 5
        _channel.invokeMethod('getRestingHeartRate'), // 6
        _channel.invokeMethod('getWeight'), // 7
        _channel.invokeMethod('getHeight'), // 8
      ]);

      final heartRateData = responses[0] as Map<Object?, Object?>?;
      final hrvData = responses[1] as Map<Object?, Object?>?;
      final sleepData = responses[2] as Map<Object?, Object?>?;
      final stepsData = responses[3];
      final energyData = responses[4];
      final workoutData = responses[5] as Map<Object?, Object?>?;
      final restingHRData = responses[6];
      final weightData = responses[7];
      final heightData = responses[8];

      final authorizedTypes = await getAuthorizedTypes();

      return HealthSnapshot(
        heartRateCurrent: (heartRateData?['current'] as num?)?.toDouble(),
        heartRateAvg24h: (heartRateData?['avg_24h'] as num?)?.toDouble(),
        restingHeartRate: (restingHRData as num?)?.toDouble(),
        hrvCurrent: (hrvData?['current'] as num?)?.toDouble(),
        hrvAvg7d: (hrvData?['avg_7d'] as num?)?.toDouble(),
        lastNightSleep: sleepData != null
            ? SleepSummary.fromMap(sleepData)
            : null,
        stepsToday: (stepsData as num?)?.toInt(),
        activeEnergyToday: (energyData as num?)?.toDouble(),
        weightKg: (weightData as num?)?.toDouble(),
        heightCm: (heightData as num?)?.toDouble(),
        lastWorkout: workoutData != null
            ? WorkoutSummary.fromMap(workoutData)
            : null,
        authorizedTypes: authorizedTypes,
        fetchedAt: DateTime.now().toUtc(),
      );
    } catch (e) {
      debugPrint('[HealthService] Error getting latest snapshot: $e');
      return null;
    }
  }
}
