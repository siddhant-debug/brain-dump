import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brain_dump/features/onboarding/screens/onboarding_screen.dart';

void main() {
  group('OnboardingScreen Tests', () {
    testWidgets('renders first Hook page correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
      );

      // We need to pump multiple times because of the flutter_animate animations
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(find.textContaining('Neural Link Established'), findsOneWidget);
      expect(find.text('SYNC NOW'), findsOneWidget);
    });

    testWidgets('navigates to Raw Dump and allows typing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Tap SYNC NOW
      await tester.tap(find.text('SYNC NOW'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.text('What is occupying your RAM right now?'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'This is a test raw dump message.',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('[ NEXT ]'), findsOneWidget);
    });

    testWidgets('navigates to Calibration page and allows selection', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Tap SYNC NOW to go to page 2
      await tester.tap(find.text('SYNC NOW'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Enter text and tap NEXT to go to page 3
      await tester.enterText(
        find.byType(TextField),
        'This is a long test string to pass validation.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('[ NEXT ]'));
      await tester.pumpAndSettle();

      expect(find.text('Calibrate System Vibe'), findsOneWidget);

      // Select the first option
      await tester.tap(find.text('🔋 Charged'));
      await tester.pumpAndSettle();

      // INITIALIZE SYSTEM should be visible (though maybe grayed out until all are selected)
      expect(find.text('INITIALIZE SYSTEM'), findsOneWidget);
    });
  });
}
