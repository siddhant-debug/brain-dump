// test/features/music/music_service_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_kit/music_kit.dart';
import 'package:brain_dump/features/music/services/music_service.dart';

class MockMusicKit extends Mock implements MusicKit {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockMusicKit mockMusicKit;
  late MusicService service;
  const channel = MethodChannel('com.braindump.music');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    mockMusicKit = MockMusicKit();
    service = MusicService(mockMusicKit);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      if (methodCall.method == 'getSystemMusicPlayerState') {
        return {
          'isPlaying': true,
          'title': 'Test Song',
          'artist': 'Test Artist',
          'rawStatus': 'playing'
        };
      }
      return null;
    });
  });

  group('MusicService', () {
    test('requestAuthorization calls music_kit', () async {
      /// 76: requestAuthorization calls music_kit
      when(() => mockMusicKit.requestAuthorizationStatus())
          .thenAnswer((_) async => MusicAuthorizationStatusAuthorized('token'));
      
      final result = await service.requestAuthorization();
      expect(result, true);
      verify(() => mockMusicKit.requestAuthorizationStatus()).called(1);
    });

    test('checkAuthorization calls music_kit', () async {
      /// 77: checkAuthorization calls music_kit
      when(() => mockMusicKit.authorizationStatus)
          .thenAnswer((_) async => MusicAuthorizationStatusAuthorized('token'));
      
      final result = await service.checkAuthorization();
      expect(result, true);
    });

    test('isPlaying handles system player state', () async {
      /// 78: isPlaying handles system player state
      final result = await service.isPlaying();
      expect(result, true);
      expect(log.any((call) => call.method == 'getSystemMusicPlayerState'), true);
    });

    test('getCurrentSong parses native response', () async {
      /// 79: getCurrentSong parses native response
      final song = await service.getCurrentSong();
      expect(song?.title, 'Test Song');
      expect(song?.artistName, 'Test Artist');
    });

    test('getMusicUserToken two-step flow', () async {
      /// 80: getMusicUserToken two-step flow
      when(() => mockMusicKit.requestDeveloperToken()).thenAnswer((_) async => 'dev_token');
      when(() => mockMusicKit.requestUserToken('dev_token')).thenAnswer((_) async => 'user_token');

      final token = await service.getMusicUserToken();
      expect(token, 'user_token');
    });
  });
}
