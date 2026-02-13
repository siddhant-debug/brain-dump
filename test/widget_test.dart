import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brain_dump/main.dart';

void main() {
  testWidgets('Brain Dump screen renders correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BrainDumpApp());

    // The hint text should be visible on launch.
    expect(find.text('just start typing…'), findsOneWidget);

    // The upload button should be present.
    expect(find.byIcon(Icons.upload_file_rounded), findsOneWidget);

    // The submit button should be present.
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });
}
