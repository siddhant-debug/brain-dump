// test/features/health/health_service_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_dump/features/health/services/health_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HealthService service;
  const channel = MethodChannel('com.braindump.health');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    service = HealthService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'requestAuthorization':
          return true;
        case 'checkAuthorizationStatus':
          return {'heart_rate': 'authorized', 'steps': 'not_determined'};
        case 'getHeartRate':
          return {'current': 72.0, 'avg_24h': 68.5};
        case 'getSteps':
          return 5000;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    log.clear();
  });

  group('HealthService', () {
    test('requestAuthorization calls native method', () async {
      /// 62: requestAuthorization calls native method
      final result = await service.requestAuthorization();
      expect(result, true);
      expect(log.any((call) => call.method == 'requestAuthorization'), true);
    });

    test('getAuthorizedTypes parses status map', () async {
      /// 63: getAuthorizedTypes parses status map
      final types = await service.getAuthorizedTypes();
      expect(types, contains('heart_rate'));
      expect(types, isNot(contains('steps')));
    });

    test('getLatestSnapshot aggregates values', () async {
      /// 64: getLatestSnapshot aggregates values
      final snapshot = await service.getLatestSnapshot();
      expect(snapshot, isNotNull);
      expect(snapshot?.heartRateCurrent, 72.0);
      expect(snapshot?.stepsToday, 5000);
    });

    test('handles PlatformException gracefully', () async {
      /// 65: handles PlatformException gracefully
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(code: 'ERROR', message: 'HealthKit error');
      });

      expect(() => service.requestAuthorization(), throwsException);
    });
  });
}
