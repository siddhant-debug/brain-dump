// test/providers/brain_dump_provider_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brain_dump/features/brain_dump/providers/brain_dump_provider.dart';
import 'package:brain_dump/features/brain_dump/services/brain_service.dart';
import 'package:brain_dump/features/notes/services/note_service.dart';
import 'package:brain_dump/features/brain_dump/services/location_service.dart';
import 'package:brain_dump/features/music/controllers/music_sync_controller.dart';
import 'package:brain_dump/features/health/controllers/health_sync_controller.dart';

class MockBrainService extends Mock implements BrainService {}
class MockNoteService extends Mock implements NoteService {}
class MockLocationService extends Mock implements LocationService {}
class MockMusicSyncController extends StateNotifier<MusicContextState> with Mock implements MusicSyncController {
  MockMusicSyncController() : super(MusicContextState());
}
class MockHealthSyncController extends StateNotifier<HealthContextState> with Mock implements HealthSyncController {
  MockHealthSyncController() : super(HealthContextState());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockBrainService mockBrainService;
  late MockNoteService mockNoteService;
  late MockLocationService mockLocationService;
  late MockMusicSyncController mockMusicController;
  late MockHealthSyncController mockHealthController;
  late ProviderContainer container;

  setUp(() {
    mockBrainService = MockBrainService();
    mockNoteService = MockNoteService();
    mockLocationService = MockLocationService();
    mockMusicController = MockMusicSyncController();
    mockHealthController = MockHealthSyncController();

    // Default stubs
    when(() => mockBrainService.getChatHistory()).thenAnswer((_) async => []);
    when(() => mockLocationService.getCurrentLocationContext()).thenAnswer((_) async => {});
    
    container = ProviderContainer(
      overrides: [
        brainServiceProvider.overrideWithValue(mockBrainService),
        noteServiceProvider.overrideWithValue(mockNoteService),
        locationServiceProvider.overrideWithValue(mockLocationService),
        musicSyncControllerProvider.overrideWith((ref) => mockMusicController),
        healthSyncControllerProvider.overrideWith((ref) => mockHealthController),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('BrainDumpProvider', () {
    test('initializes in journal mode', () {
      /// 38: initializes in journal mode
      final state = container.read(brainDumpProvider);
      expect(state.isChatMode, false);
    });

    test('toggleMode switches to chat mode', () {
      /// 39: toggleMode switches to chat mode
      container.read(brainDumpProvider.notifier).toggleMode();
      expect(container.read(brainDumpProvider).isChatMode, true);
    });

    test('toggleMode switches back to journal mode', () {
      /// 40: toggleMode switches back to journal mode
      final notifier = container.read(brainDumpProvider.notifier);
      notifier.toggleMode(); // to chat
      notifier.toggleMode(); // back to journal
      expect(container.read(brainDumpProvider).isChatMode, false);
    });

    test('processInput adds user message immediately', () async {
      /// 41: processInput adds user message immediately
      when(() => mockBrainService.askBrain(any(),
              location: any(named: 'location'),
              musicContext: any(named: 'musicContext'),
              healthContext: any(named: 'healthContext')))
          .thenAnswer((_) => Stream.fromIterable([]));
      when(() => mockNoteService.saveNote(any())).thenAnswer((_) async => {});

      final notifier = container.read(brainDumpProvider.notifier);
      final future = notifier.processInput('Hello Brain');

      final state = container.read(brainDumpProvider);
      expect(state.messages.any((m) => m.content == 'Hello Brain'), true);
      expect(state.isProcessing, true);

      await future;
    });

    test('processInput sets isProcessing true then false', () async {
      /// 42: processInput sets isProcessing true then false
      final controller = StreamController<Map<String, dynamic>>();
      when(() => mockBrainService.askBrain(any(),
              location: any(named: 'location'),
              musicContext: any(named: 'musicContext'),
              healthContext: any(named: 'healthContext')))
          .thenAnswer((_) => controller.stream);
      when(() => mockNoteService.saveNote(any())).thenAnswer((_) async => {});

      final notifier = container.read(brainDumpProvider.notifier);
      final future = notifier.processInput('Test query');

      expect(container.read(brainDumpProvider).isProcessing, true);

      controller.add({'chunk': 'Response', 'done': false});
      controller.add({'chunk': '', 'done': true});
      await controller.close();
      await future;

      expect(container.read(brainDumpProvider).isProcessing, false);
    });

    test('processInput with error sets error state', () async {
      /// 43: processInput with error sets error state
      when(() => mockBrainService.askBrain(any(),
              location: any(named: 'location'),
              musicContext: any(named: 'musicContext'),
              healthContext: any(named: 'healthContext')))
          .thenAnswer((_) => Stream.error(Exception('API Error')));
      when(() => mockNoteService.saveNote(any())).thenAnswer((_) async => {});

      final notifier = container.read(brainDumpProvider.notifier);
      await notifier.processInput('Test error');

      final state = container.read(brainDumpProvider);
      expect(state.error, contains('API Error'));
      expect(state.isProcessing, false);
    });

    test('saveNoteSilently does not add message to list', () async {
      /// 44: saveNoteSilently does not add message to list
      when(() => mockNoteService.saveNote(any())).thenAnswer((_) async => {});

      final notifier = container.read(brainDumpProvider.notifier);
      await notifier.saveNoteSilently('Secret thought');

      final state = container.read(brainDumpProvider);
      expect(state.messages.isEmpty, true);
      expect(state.isProcessing, false);
    });

    test('clearLocalHistory empties messages', () async {
      /// 45: clearLocalHistory empties messages
      when(() => mockBrainService.endSession()).thenAnswer((_) async => {});
      
      final notifier = container.read(brainDumpProvider.notifier);
      // Manually state injection for testing clear
      // We can't easily inject state into StateNotifier in Riverpod without mocking notifier or using a hack.
      // But we can just use processInput to add one.
      when(() => mockBrainService.askBrain(any())).thenAnswer((_) => Stream.empty());
      when(() => mockNoteService.saveNote(any())).thenAnswer((_) async => {});
      
      await notifier.processInput('Msg');
      expect(container.read(brainDumpProvider).messages.isNotEmpty, true);

      notifier.clearLocalHistory();
      expect(container.read(brainDumpProvider).messages.isEmpty, true);
    });

    test('empty input is ignored', () async {
      /// 46: empty input is ignored
      final notifier = container.read(brainDumpProvider.notifier);
      await notifier.processInput('   ');
      
      final state = container.read(brainDumpProvider);
      expect(state.messages.isEmpty, true);
      expect(state.isProcessing, false);
    });
  });
}
