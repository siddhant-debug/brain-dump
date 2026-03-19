// test/features/music/music_sync_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:brain_dump/features/music/controllers/music_sync_controller.dart';
import 'package:brain_dump/features/music/services/music_service_interface.dart';
import 'package:brain_dump/features/music/services/music_service.dart';

class MockMusicService extends Mock implements MusicServiceInterface {}
class MockSecureStorage extends Mock implements FlutterSecureStorage {}
class MockDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockMusicService mockService;
  late MockSecureStorage mockStorage;
  late MockDio mockDio;
  late ProviderContainer container;

  setUp(() {
    mockService = MockMusicService();
    mockStorage = MockSecureStorage();
    mockDio = MockDio();

    when(() => mockService.checkAuthorization()).thenAnswer((_) async => false);
    
    container = ProviderContainer(
      overrides: [
        musicSyncControllerProvider.overrideWith((ref) => MusicSyncController(mockService, mockStorage, mockDio)),
      ],
    );
  });

  group('MusicSyncController', () {
    test('initializes with no auth', () {
      /// 81: initializes with no auth
      final state = container.read(musicSyncControllerProvider);
      expect(state.isAuthorized, false);
    });

    test('requestPermission updates auth state', () async {
      /// 82: requestPermission updates auth state
      when(() => mockService.requestAuthorization()).thenAnswer((_) async => true);
      when(() => mockService.isPlaying()).thenAnswer((_) async => false);
      when(() => mockService.getCurrentSong()).thenAnswer((_) async => null);
      when(() => mockService.getRawPlayerState()).thenAnswer((_) async => 'Status: unknown');
      when(() => mockStorage.read(key: 'jwt_token')).thenAnswer((_) async => 'fake_jwt');
      when(() => mockService.getMusicUserToken()).thenAnswer((_) async => 'user_token');
      when(() => mockDio.get(any(), options: any(named: 'options')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: {'recent_songs': []}));
      when(() => mockDio.post(any(), options: any(named: 'options'), data: any(named: 'data')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: {'primary_tone': 'Neutral', 'short_description': 'Test'}));

      await container.read(musicSyncControllerProvider.notifier).requestPermission();

      final state = container.read(musicSyncControllerProvider);
      expect(state.isAuthorized, true);
    });

    test('_analyzeVibeOnBackend triggers post to backend', () async {
      /// 83: _analyzeVibeOnBackend triggers post to backend
      final notifier = container.read(musicSyncControllerProvider.notifier);
      final song = MusicItem(title: 'Happy', artistName: 'Pharrell');

      when(() => mockStorage.read(key: 'jwt_token')).thenAnswer((_) async => 'fake_jwt');
      when(() => mockDio.post('/api/music/context', options: any(named: 'options'), data: any(named: 'data')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: {
            'primary_tone': 'Joyful',
            'short_description': 'Upbeat song',
          }));

      // We can't directly call a private method, so we should trigger a flow that calls it.
      // Or we can just test if refreshMusicContext (which is public) triggers it.
      
      notifier.state = notifier.state.copyWith(isAuthorized: true);
      when(() => mockService.isPlaying()).thenAnswer((_) async => true);
      when(() => mockService.getCurrentSong()).thenAnswer((_) async => song);
      when(() => mockService.getRawPlayerState()).thenAnswer((_) async => 'Status: playing');
      when(() => mockService.getMusicUserToken()).thenAnswer((_) async => 'user_token');
      when(() => mockDio.get(any(), options: any(named: 'options')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: {'recent_songs': []}));

      await notifier.refreshMusicContext();

      verify(() => mockDio.post('/api/music/context', options: any(named: 'options'), data: any(named: 'data'))).called(1);
      expect(container.read(musicSyncControllerProvider).analyzedVibe?.primaryTone, 'Joyful');
    });

    test('recent songs are cached locally', () async {
      /// 84: recent songs are cached locally
    });

    test('handles 401 on backend sync', () async {
      /// 85: handles 401 on backend sync
      final notifier = container.read(musicSyncControllerProvider.notifier);
      notifier.state = notifier.state.copyWith(isAuthorized: true);
      
      when(() => mockService.isPlaying()).thenAnswer((_) async => true);
      when(() => mockService.getCurrentSong()).thenAnswer((_) async => MusicItem(title: 'S', artistName: 'A'));
      when(() => mockService.getRawPlayerState()).thenAnswer((_) async => 'S');
      when(() => mockService.getMusicUserToken()).thenAnswer((_) async => 'T');
      when(() => mockStorage.read(key: 'jwt_token')).thenAnswer((_) async => 'J');
      when(() => mockDio.get(any(), options: any(named: 'options'))).thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: {'recent_songs': []}));
      
      when(() => mockDio.post(any(), options: any(named: 'options'), data: any(named: 'data')))
          .thenThrow(DioException(requestOptions: RequestOptions(path: ''), response: Response(requestOptions: RequestOptions(path: ''), statusCode: 401)));

      await notifier.refreshMusicContext();

      expect(container.read(musicSyncControllerProvider).error, contains('401'));
    });
   group('Lifecycle', () {
      test('polling logic starts after permission', () async {
        /// 87: polling logic starts after permission
      });
    });
  });
}
