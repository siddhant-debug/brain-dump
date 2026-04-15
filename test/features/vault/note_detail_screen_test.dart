// test/features/vault/note_detail_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brain_dump/features/vault/presentation/note_detail_screen.dart';
import 'package:brain_dump/features/notes/models/note.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final testNote = Note(
    id: 1,
    content: 'This is a test thought content for detail screen.',
    createdAt: DateTime(2023, 10, 1),
    isFavorite: true,
    categories: ['Insight', 'Test'],
    sentiment: 'positive',
  );

  testWidgets('NoteDetailScreen renders content correctly', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: NoteDetailScreen(note: testNote),
        ),
      ),
    );

    expect(find.text('This is a test thought content for detail screen.'), findsOneWidget);
    expect(find.text('POSITIVE'), findsOneWidget);
    expect(find.text('#insight'), findsOneWidget);
    expect(find.text('#test'), findsOneWidget);
  });

  testWidgets('NoteDetailScreen has a back button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (context) => NoteDetailScreen(note: testNote),
            ),
          ),
        ),
      ),
    );

    // Standard AppBar automatically adds a BackButton if it can pop
    expect(find.byType(BackButton), findsOneWidget);
  });
}
