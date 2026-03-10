import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/health_service.dart';
import '../services/health_service_interface.dart';

final healthServiceProvider = Provider<HealthServiceInterface>((ref) {
  return HealthService();
});
