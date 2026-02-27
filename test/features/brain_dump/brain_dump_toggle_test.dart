import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brain_dump/features/brain_dump/providers/brain_dump_provider.dart';
import 'package:brain_dump/features/brain_dump/models/chat_message.dart';

void main() {
  group('BrainDumpState', () {
    test('defaults to Journal mode (isChatMode = false)', () {
      final state = BrainDumpState();
      expect(state.isChatMode, false);
      expect(state.messages, isEmpty);
      expect(state.isProcessing, false);
      expect(state.error, isNull);
    });

    test('copyWith preserves isChatMode when not specified', () {
      final state = BrainDumpState(isChatMode: true);
      final copied = state.copyWith(isProcessing: true);
      expect(copied.isChatMode, true);
      expect(copied.isProcessing, true);
    });

    test('copyWith updates isChatMode', () {
      final state = BrainDumpState();
      final toggled = state.copyWith(isChatMode: true);
      expect(toggled.isChatMode, true);
      // Original unchanged (immutability)
      expect(state.isChatMode, false);
    });

    test('copyWith preserves all other fields when toggling mode', () {
      final msg = ChatMessage(
        id: '1',
        content: 'test',
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      );
      final state = BrainDumpState(
        messages: [msg],
        isProcessing: true,
        error: 'some error',
        isChatMode: false,
      );

      final toggled = state.copyWith(isChatMode: true);
      expect(toggled.messages.length, 1);
      expect(toggled.messages.first.content, 'test');
      expect(toggled.isProcessing, true);
      expect(toggled.error, 'some error');
      expect(toggled.isChatMode, true);
    });

    test('copyWith with clearError resets error but keeps isChatMode', () {
      final state = BrainDumpState(error: 'oops', isChatMode: true);
      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
      expect(cleared.isChatMode, true);
    });
  });

  group('BrainDumpNotifier.toggleMode', () {
    test('toggleMode flips isChatMode from false to true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(brainDumpProvider).isChatMode, false);
      container.read(brainDumpProvider.notifier).toggleMode();
      expect(container.read(brainDumpProvider).isChatMode, true);
    });

    test('toggleMode flips isChatMode from true to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Toggle to true first
      container.read(brainDumpProvider.notifier).toggleMode();
      expect(container.read(brainDumpProvider).isChatMode, true);

      // Toggle back
      container.read(brainDumpProvider.notifier).toggleMode();
      expect(container.read(brainDumpProvider).isChatMode, false);
    });

    test('toggleMode preserves messages and other state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Verify initial state has messages from history fetch (or empty)
      final initialMessages = container.read(brainDumpProvider).messages.length;

      container.read(brainDumpProvider.notifier).toggleMode();
      expect(
        container.read(brainDumpProvider).messages.length,
        initialMessages,
      );
    });

    test('rapid toggles do not corrupt state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Simulate rapid toggles (user stress test)
      for (int i = 0; i < 100; i++) {
        container.read(brainDumpProvider.notifier).toggleMode();
      }
      // Even number of toggles = back to default
      expect(container.read(brainDumpProvider).isChatMode, false);

      // One more toggle
      container.read(brainDumpProvider.notifier).toggleMode();
      expect(container.read(brainDumpProvider).isChatMode, true);
    });
  });
}
