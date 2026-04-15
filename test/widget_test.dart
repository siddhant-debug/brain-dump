import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:brain_dump/main.dart';
import 'package:brain_dump/core/widgets/persistent_header.dart';

import 'package:brain_dump/features/analytics/presentation/analytics_screen.dart';

void main() {
  group('Brain Dump App Tests', () {
    testWidgets('App root component renders correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: MyApp()));
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('PersistentHeader renders title correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: PersistentHeader(title: 'Test Header')),
          ),
        ),
      );
      expect(find.text('Test Header'), findsOneWidget);
    });

    testWidgets('AnalyticsScreen loads and displays basic UI', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: AnalyticsScreen())),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Health and Music'), findsOneWidget);
    });
  });
}
