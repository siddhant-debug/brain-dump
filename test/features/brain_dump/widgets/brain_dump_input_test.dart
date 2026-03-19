// test/features/brain_dump/widgets/brain_dump_input_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:brain_dump/features/brain_dump/widgets/brain_dump_input.dart';
import 'package:brain_dump/features/brain_dump/providers/brain_dump_provider.dart';

class MockBrainDumpNotifier extends StateNotifier<BrainDumpState> with Mock implements BrainDumpNotifier {
  MockBrainDumpNotifier() : super(BrainDumpState());
}

void main() {
  late MockBrainDumpNotifier mockNotifier;

  setUp(() {
    mockNotifier = MockBrainDumpNotifier();
  });

  Widget createWidgetUnderTest() {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    
    return ProviderScope(
      overrides: [
        brainDumpProvider.overrideWith((ref) => mockNotifier),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: BrainDumpInput(
            controller: controller,
            focusNode: focusNode,
            onSubmitted: (_) {},
          ),
        ),
      ),
    );
  }

  group('BrainDumpInput (Black Canvas)', () {
    testWidgets('renders in journal mode by default', (tester) async {
      /// 99: renders in journal mode by default
      // state defaults to isChatMode: false
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.textContaining('Drop a thought'), findsOneWidget);
      expect(find.text('JOURNAL'), findsOneWidget);
    });

    testWidgets('mode toggle switches to chat mode', (tester) async {
      /// 100: mode toggle switches to chat mode
      await tester.pumpWidget(createWidgetUnderTest());

      // Since it's a mock, we need to handle the toggle call
      when(() => mockNotifier.toggleMode()).thenAnswer((_) {
        mockNotifier.state = mockNotifier.state.copyWith(isChatMode: true);
      });

      // Better: find by text 'JOURNAL' or the specific icon
      await tester.tap(find.text('JOURNAL'));
      await tester.pump();

      verify(() => mockNotifier.toggleMode()).called(1);
      expect(find.text('CHAT'), findsOneWidget);
    });

    testWidgets('empty submit does not trigger processInput', (tester) async {
      /// 101: empty submit does not trigger processInput
      await tester.pumpWidget(createWidgetUnderTest());

      // Tap send button (IconButton)
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();

      verifyNever(() => mockNotifier.processInput(any()));
    });
    
    testWidgets('typing and submitting triggers processInput', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      
      when(() => mockNotifier.processInput(any())).thenAnswer((_) async {});

      await tester.enterText(find.byType(TextField), 'Hello Brain');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();

      verify(() => mockNotifier.processInput('Hello Brain')).called(1);
    });
  });
}
