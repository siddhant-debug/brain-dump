// test/features/vault/widgets/typewriter_text_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_dump/features/vault/widgets/typewriter_text.dart';

void main() {
  group('TypewriterText', () {
    testWidgets('starts empty and fills over time', (tester) async {
      /// 113: starts empty and fills over time
      const testText = 'Hello World';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypewriterText(
              text: testText,
              typingDuration: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      // Initially 0 characters
      expect(find.text(''), findsOneWidget);
      expect(find.text(testText), findsNothing);

      // Advance time by 500ms -> should show 'Hello'
      await tester.pump(const Duration(milliseconds: 550));
      expect(find.text('Hello'), findsOneWidget);

      // Advance time to completion (total 1100ms)
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(testText), findsOneWidget);
    });

    testWidgets('updates when text changes', (tester) async {
      /// 114: updates when text changes
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypewriterText(
              text: 'Old Text',
              typingDuration: Duration(milliseconds: 10),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Old Text'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypewriterText(
              text: 'Newer',
              typingDuration: Duration(milliseconds: 10),
            ),
          ),
        ),
      );
      await tester.pump();

      // Should restart from empty
      expect(find.text(''), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Newer'), findsOneWidget);
    });
  });
}
