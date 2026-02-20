import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../services/brain_service.dart';
import '../../notes/services/note_service.dart';
import '../models/chat_message.dart';
import '../services/location_service.dart';

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
    bool clearError = false,
  }) {
    return BrainDumpState(
      messages: messages ?? this.messages,
      isProcessing: isProcessing ?? this.isProcessing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class BrainDumpNotifier extends StateNotifier<BrainDumpState> {
  final Ref ref;
  final _uuid = const Uuid();
  Timer? _noteCleanupTimer;
  StreamSubscription? _currentStreamSubscription;

  BrainDumpNotifier(this.ref) : super(BrainDumpState()) {
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final history = await ref.read(brainServiceProvider).getChatHistory();
      if (history.isNotEmpty) {
        // [Architect] SAFE MERGE
        // We prepend history to any messages the user might have typed
        // while the history was loading.
        // History messages already have isRestored=true from fromJson
        state = state.copyWith(messages: [...history, ...state.messages]);
      }
    } catch (e) {
      print('Error loading history: $e');
    }
  }

  @override
  void dispose() {
    _noteCleanupTimer?.cancel();
    _currentStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> processInput(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Cancel any ongoing stream
    await _currentStreamSubscription?.cancel();

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

    // [CONTEXT] Fetch Location (Graceful degradation)
    Map<String, dynamic>? locationContext;
    try {
      // Add timeout to prevent blocking if location service hangs
      locationContext = await ref
          .read(locationServiceProvider)
          .getCurrentLocationContext()
          .timeout(const Duration(seconds: 3));
      print("[DEBUG] Location fetched: $locationContext");
    } catch (e) {
      print("[DEBUG] Location fetch skipped (Timeout/Error): $e");
    }

    String? aiMessageId;

    try {
      if (trimmed.endsWith('?')) {
        aiMessageId = await _handleQuery(trimmed, locationContext);
      } else {
        aiMessageId = await _saveNote(trimmed, locationContext);
      }
    } catch (e) {
      // Update ONLY the specific message by ID
      if (aiMessageId != null) {
        state = state.copyWith(
          messages: state.messages.map((msg) {
            if (msg.id == aiMessageId) {
              return ChatMessage(
                id: msg.id,
                content: "Error: ${e.toString().replaceAll('Exception: ', '')}",
                sender: msg.sender,
                timestamp: DateTime.now(),
                status: MessageStatus.error,
              );
            }
            return msg;
          }).toList(),
          error: e.toString(),
          isProcessing: false,
        );
      }
    }
  }

  Future<String> _handleQuery(
    String text,
    Map<String, dynamic>? location,
  ) async {
    // 2. Add "Thinking..." placeholder
    final aiMsgId = _uuid.v4();
    final placeholderMsg = ChatMessage(
      id: aiMsgId,
      content: "Thinking...",
      sender: MessageSender.ai,
      timestamp: DateTime.now(),
      status: MessageStatus.thinking,
      locationContext: location, // Attach location to AI message
    );

    state = state.copyWith(messages: [...state.messages, placeholderMsg]);

    // 3. Stream AI response
    String fullAnswer = "";
    bool isFirstChunk = true;
    List<String> sources = [];

    try {
      await for (var data
          in ref
              .read(brainServiceProvider)
              .askBrain(text, location: location)) {
        // Handle text chunk
        if (data['chunk'] != null) {
          fullAnswer += data['chunk'];
        }

        // Handle citation sources (usually in the final chunk)
        if (data['sources'] != null) {
          try {
            sources = List<String>.from(data['sources']);
            print("Received sources: $sources");
          } catch (e) {
            print("Error parsing sources: $e");
          }
        }

        // Update message with accumulated response
        state = state.copyWith(
          messages: state.messages.map((msg) {
            if (msg.id == aiMsgId) {
              return ChatMessage(
                id: msg.id,
                content: fullAnswer,
                sender: MessageSender.ai,
                timestamp: DateTime.now(),
                status: isFirstChunk ? MessageStatus.sent : msg.status,
                sources: sources.isNotEmpty ? sources : msg.sources,
                locationContext: location, // Ensure location persists
              );
            }
            return msg;
          }).toList(),
        );

        isFirstChunk = false;
      }

      // Mark as complete
      state = state.copyWith(
        messages: state.messages.map((msg) {
          if (msg.id == aiMsgId) {
            return ChatMessage(
              id: msg.id,
              content: fullAnswer,
              sender: MessageSender.ai,
              timestamp: DateTime.now(),
              status: MessageStatus.sent,
              sources: sources, // [Architect] FIX: Pass collected sources here
              isRestored: false, // Live message
              locationContext: location, // Final attachment
            );
          }
          return msg;
        }).toList(),
        isProcessing: false,
      );
    } catch (e) {
      // Handle error
      state = state.copyWith(
        messages: state.messages.map((msg) {
          if (msg.id == aiMsgId) {
            return ChatMessage(
              id: msg.id,
              content: "Error: ${e.toString().replaceAll('Exception: ', '')}",
              sender: MessageSender.ai,
              timestamp: DateTime.now(),
              status: MessageStatus.sent,
            );
          }
          return msg;
        }).toList(),
        error: e.toString(),
        isProcessing: false,
      );
    }

    return aiMsgId;
  }

  Future<String> _saveNote(String text, Map<String, dynamic>? location) async {
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

    // 3. Call API (Notes Service)
    await ref.read(noteServiceProvider).saveNote(text, location: location);

    // [Architect] INVALIDATE PROVIDER
    // This forces the thoughts list to refresh immediately
    ref.invalidate(notesProvider);

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
    // Cancel previous timer if exists
    _noteCleanupTimer?.cancel();

    // Use Timer instead of Future.delayed to prevent memory leaks
    _noteCleanupTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        state = state.copyWith(
          messages: state.messages
              .where((msg) => msg.id != userNoteId && msg.id != systemMsgId)
              .toList(),
          isProcessing: false,
        );
      }
    });

    return systemMsgId;
  }

  /// Save note silently without adding any messages to chat
  /// Used for Black Canvas UI where notes don't appear in the list
  Future<void> saveNoteSilently(String text) async {
    state = state.copyWith(isProcessing: true);

    try {
      await ref.read(noteServiceProvider).saveNote(text);
      ref.invalidate(notesProvider); // Refresh list
      state = state.copyWith(isProcessing: false);
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
      rethrow;
    }
  }

  /// Clear message history from local state (doesn't affect backend)
  void clearLocalHistory() {
    state = state.copyWith(messages: []);
  }
}
