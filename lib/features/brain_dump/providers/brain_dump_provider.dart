import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../services/brain_service.dart';
import '../models/chat_message.dart';

final brainDumpProvider =
    StateNotifierProvider<BrainDumpNotifier, BrainDumpState>((ref) {
      return BrainDumpNotifier(ref);
    });

class BrainDumpState {
  final List<ChatMessage> messages;
  final bool isProcessing;
  final String? error;

  BrainDumpState({
    this.messages = const [],
    this.isProcessing = false,
    this.error,
  });

  BrainDumpState copyWith({
    List<ChatMessage>? messages,
    bool? isProcessing,
    String? error,
  }) {
    return BrainDumpState(
      messages: messages ?? this.messages,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error ?? this.error,
    );
  }
}

class BrainDumpNotifier extends StateNotifier<BrainDumpState> {
  final Ref ref;
  final _uuid = const Uuid();

  BrainDumpNotifier(this.ref) : super(BrainDumpState());

  Future<void> processInput(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // 1. Add User Message immediately
    final userMsgId = _uuid.v4();
    final userMsg = ChatMessage(
      id: userMsgId,
      content: trimmed,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isProcessing: true,
      error: null,
    );

    try {
      if (trimmed.endsWith('?')) {
        await _handleQuery(trimmed);
      } else {
        await _saveNote(trimmed);
      }
    } catch (e) {
      // Find and update the "Thinking..." or "Memorizing..." message to show error
      state = state.copyWith(
        messages: state.messages.map((msg) {
          if (msg.status == MessageStatus.thinking ||
              msg.status == MessageStatus.memorizing) {
            return ChatMessage(
              id: msg.id,
              content: "Error: ${e.toString().replaceAll('Exception: ', '')}",
              sender: msg.sender,
              timestamp: DateTime.now(),
              status: MessageStatus
                  .sent, // Stop the spinner, show content as error text
            );
          }
          return msg;
        }).toList(),
        error: e.toString(),
        isProcessing: false,
      );
    }
  }

  Future<void> _handleQuery(String text) async {
    // 2. Add "Thinking..." placeholder
    final aiMsgId = _uuid.v4();
    final placeholderMsg = ChatMessage(
      id: aiMsgId,
      content: "Thinking...",
      sender: MessageSender.ai,
      timestamp: DateTime.now(),
      status: MessageStatus.thinking,
    );

    state = state.copyWith(messages: [...state.messages, placeholderMsg]);

    // 3. Call API
    final result = await ref.read(brainServiceProvider).askBrain(text);
    final answer = result['answer'];

    // 4. Update placeholder with real answer
    state = state.copyWith(
      messages: state.messages.map((msg) {
        if (msg.id == aiMsgId) {
          return ChatMessage(
            id: msg.id,
            content: answer,
            sender: MessageSender.ai,
            timestamp: DateTime.now(),
            status: MessageStatus.sent,
          );
        }
        return msg;
      }).toList(),
    );
  }

  Future<void> _saveNote(String text) async {
    // Remove the user's note message immediately (keep canvas clean)
    final userNoteId = state.messages.last.id;

    // 2. Add "Memorizing..." placeholder
    final systemMsgId = _uuid.v4();
    final placeholderMsg = ChatMessage(
      id: systemMsgId,
      content: "Memorizing...",
      sender: MessageSender.system,
      timestamp: DateTime.now(),
      status: MessageStatus.memorizing,
    );

    state = state.copyWith(messages: [...state.messages, placeholderMsg]);

    // 3. Call API
    await ref.read(brainServiceProvider).saveNote(text);

    // 4. Update placeholder to "Memorized ✓"
    state = state.copyWith(
      messages: state.messages.map((msg) {
        if (msg.id == systemMsgId) {
          return ChatMessage(
            id: msg.id,
            content: "Memorized ✓",
            sender: MessageSender.system,
            timestamp: DateTime.now(),
            status: MessageStatus.memorized,
          );
        }
        return msg;
      }).toList(),
    );

    // 5. Remove both user note and "Memorized ✓" after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      state = state.copyWith(
        messages: state.messages
            .where((msg) => msg.id != userNoteId && msg.id != systemMsgId)
            .toList(),
        isProcessing: false,
      );
    });
  }
}
