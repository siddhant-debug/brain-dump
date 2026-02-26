import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:brain_dump/main.dart';

void main() {
  testWidgets('Brain Dump screen renders correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // The app should start in a loading state or login state initially
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
