import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:brain_dump/main.dart';
import 'package:brain_dump/core/widgets/persistent_header.dart';

import 'package:brain_dump/features/analytics/presentation/analytics_screen.dart';
import 'package:brain_dump/features/analytics/services/analytics_service.dart';
import 'package:brain_dump/features/analytics/models/analytics_models.dart';
import 'package:brain_dump/features/analytics/models/pipeline_models.dart';

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
        const MaterialApp(
          home: Scaffold(body: PersistentHeader(title: 'Test Header')),
        ),
      );
      expect(find.text('Test Header'), findsOneWidget);
    });

    testWidgets('AnalyticsScreen loads and displays analytics data', (
      WidgetTester tester,
    ) async {
      final mockConsistency = ConsistencyData(
        currentStreak: 5,
        longestStreak: 10,
        totalNotes: 50,
        activeDaysLast30: 20,
        heatmap: const [],
      );

      final mockThemes = ThemesData(
        windowDays: 30,
        totalNotesAnalyzed: 50,
        themes: [
          const ThemeItem(
            key: 'work',
            name: 'Work Theme',
            count: 10,
            pct: 20.0,
            sample: 'Meeting notes',
          ),
        ],
      );

      final mockLoops = LoopsData(loops: const [], notesScanned: 50);

      final mockPipeline = PipelineData(
        generatedAt: DateTime.now(),
        lanes: const [],
        nodes: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            consistencyProvider.overrideWith(
              (ref) => Future.value(mockConsistency),
            ),
            themesProvider.overrideWith((ref) => Future.value(mockThemes)),
            loopsProvider.overrideWith((ref) => Future.value(mockLoops)),
            pipelineProvider.overrideWith((ref) => Future.value(mockPipeline)),
          ],
          child: const MaterialApp(home: Scaffold(body: AnalyticsScreen())),
        ),
      );

      // Settle the pumps (FutureProviders need a frame to resolve)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Brain Insights'), findsOneWidget);

      // Since mock data has 5 days streak
      expect(find.text('5'), findsOneWidget);
      expect(find.text('days streak'), findsOneWidget);

      // Themes data check
      expect(find.text('Work Theme'), findsOneWidget);

      // Loops check (open bottom sheet first)
      final loopsButton = find.byIcon(Icons.all_inclusive_rounded);
      expect(loopsButton, findsOneWidget);

      await tester.tap(loopsButton);
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text(
          'No recurring patterns found. Keep writing — loops surface over time.',
        ),
        findsOneWidget,
      );
    });
  });
}
