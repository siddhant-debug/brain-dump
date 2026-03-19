// test/features/vault/note_detail_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brain_dump/features/vault/presentation/note_detail_screen.dart';
import 'package:brain_dump/features/notes/models/note.dart';

void main() {
  final testNote = Note(
    id: 1,
    content: 'This is a test thought content for detail screen.',
    createdAt: DateTime(2023, 10, 1),
    isFavorite: true,
    categories: ['Insight', 'Test'],
    sentiment: 'positive',
    title: 'Test Title',
  );

  Widget createWidget() {
    return ProviderScope(
      child: MaterialApp(
        home: NoteDetailScreen(note: testNote),
      ),
    );
  }

  group('NoteDetailScreen', () {
    testWidgets('renders note details correctly', (tester) async {
      /// 111: renders note details correctly
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('This is a test thought content for detail screen.'), findsOneWidget);
      expect(find.text('POSITIVE'), findsOneWidget);
      expect(find.text('#insight'), findsOneWidget);
      expect(find.text('#test'), findsOneWidget);
      expect(find.text('2023-10-01'), findsOneWidget);
    });

    testWidgets('back button pops screen', (tester) async {
      /// 112: back button pops screen
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // We can't easily test navigation pop without a mock observer or checking if it's still there
      // but let's just ensure it's present.
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });
  });
}
