import '../models/health_snapshot.dart';

abstract class HealthServiceInterface {
  Future<bool> requestAuthorization();
  Future<Map<String, String>> checkAuthorization();
  Future<Set<String>> getAuthorizedTypes(); // partial auth support
  Future<HealthSnapshot?> getLatestSnapshot();
  Future<String> getRawDebugState();
  Future<void> reinitAfterAuthorization();
}
