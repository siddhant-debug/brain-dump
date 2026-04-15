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
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockBrainDumpNotifier mockNotifier;
  late TextEditingController controller;
  late FocusNode focusNode;

  setUp(() {
    mockNotifier = MockBrainDumpNotifier();
    controller = TextEditingController();
    focusNode = FocusNode();
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        brainDumpProvider.overrideWith((ref) => mockNotifier),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, child) {
              return BrainDumpInput(
                controller: controller,
                focusNode: focusNode,
                onSubmitted: (val) {
                  ref.read(brainDumpProvider.notifier).processInput(val);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  group('BrainDumpInput (Black Canvas)', () {
    testWidgets('renders in journal mode by default', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.textContaining('Drop a thought'), findsOneWidget);
      expect(find.text('JOURNAL'), findsOneWidget);
    });

    testWidgets('mode toggle switches to chat mode', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      when(() => mockNotifier.toggleMode()).thenAnswer((_) {
        mockNotifier.state = mockNotifier.state.copyWith(isChatMode: true);
      });

      await tester.tap(find.text('JOURNAL'));
      await tester.pump();

      verify(() => mockNotifier.toggleMode()).called(1);
      expect(find.text('CHAT'), findsOneWidget);
    });

    testWidgets('empty submit does not trigger processInput', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

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
