// test/features/vault/thoughts_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brain_dump/features/vault/presentation/thoughts_screen.dart';
import 'package:brain_dump/features/notes/models/note.dart';
import 'package:brain_dump/features/notes/services/note_service.dart';

class MockNoteService extends Mock implements NoteService {}

void main() {
  late MockNoteService mockService;
  late List<Note> testNotes;

  setUp(() {
    mockService = MockNoteService();
    testNotes = [
      Note(
        id: 1,
        content: 'Test Thought 1',
        createdAt: DateTime.now(),
        isFavorite: false,
        categories: ['test'],
        sentiment: 'positive',
      ),
      Note(
        id: 2,
        content: 'Test Thought 2',
        createdAt: DateTime.now(),
        isFavorite: true,
        categories: ['demo'],
        sentiment: 'neutral',
      ),
    ];

    when(() => mockService.getNotes()).thenAnswer((_) async => testNotes);
  });

  Widget createWidget() {
    return ProviderScope(
      overrides: [
        noteServiceProvider.overrideWithValue(mockService),
      ],
      child: const MaterialApp(
        home: ThoughtsScreen(),
      ),
    );
  }

  group('ThoughtsScreen', () {
    testWidgets('renders list of notes', (tester) async {
      /// 92: renders list of notes
      await tester.pumpWidget(createWidget());
      await tester.pump(); // Start loading
      await tester.pump(); // Data loaded

      expect(find.text('Test Thought 1'), findsOneWidget);
      expect(find.text('Test Thought 2'), findsOneWidget);
      expect(find.text('#test'), findsOneWidget);
      expect(find.text('#demo'), findsOneWidget);
    });

    testWidgets('shows delete confirmation dialog', (tester) async {
      /// 93: shows delete confirmation dialog
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      final deleteIcon = find.byIcon(Icons.delete_outline).first;
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      expect(find.text('Delete Thought?'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('calls deleteNote on service when confirmed', (tester) async {
      /// 94: calls deleteNote on service when confirmed
      when(() => mockService.deleteNote(any())).thenAnswer((_) async => {});

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => mockService.deleteNote(1)).called(1);
    });

    testWidgets('shows empty state when no notes', (tester) async {
      /// 95: shows empty state when no notes
      when(() => mockService.getNotes()).thenAnswer((_) async => []);

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('No thoughts saved yet.'), findsOneWidget);
    });
    group('Add Note', () {
      testWidgets('opens add note dialog', (tester) async {
        /// 96: opens add note dialog
        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pumpAndSettle();

        expect(find.text('New Thought'), findsOneWidget);
      });
    });
  });
}
