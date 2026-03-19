// test/features/vault/widgets/typewriter_text_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_dump/features/vault/widgets/typewriter_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('TypewriterText', () {
    testWidgets('starts empty and fills over time', (tester) async {
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
      // Use find.byType(Text) to avoid empty string issues and verify the first frame
      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, isEmpty);

      // Advance time by 500ms -> should show 'Hello'
      await tester.pump(const Duration(milliseconds: 550));
      expect(find.text('Hello'), findsOneWidget);

      // Advance time to completion
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(testText), findsOneWidget);
    });

    testWidgets('updates when text changes', (tester) async {
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
      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, isEmpty);

      await tester.pumpAndSettle();
      expect(find.text('Newer'), findsOneWidget);
    });
  });
}
