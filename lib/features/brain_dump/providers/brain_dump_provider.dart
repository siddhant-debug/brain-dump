import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../services/brain_service.dart';
import '../../notes/services/note_service.dart';
import '../models/chat_message.dart';
import '../services/location_service.dart';
import '../../music/controllers/music_sync_controller.dart';
import '../../health/controllers/health_sync_controller.dart';
import 'package:dio/dio.dart';

String _formatError(dynamic e) {
  if (e is DioException) {
    if (e.response?.statusCode == 429) {
      return "You've reached your daily limit. Please try again later.";
    }
    final detail = e.response?.data?['detail'];
    if (detail != null) {
      return detail.toString();
    }
    return e.message ?? "Network error occurred";
  }
  return e.toString().replaceAll('Exception: ', '');
}

final brainDumpProvider =
    StateNotifierProvider<BrainDumpNotifier, BrainDumpState>((ref) {
      return BrainDumpNotifier(ref);
    });

class BrainDumpState {
  final List<ChatMessage> messages;
  final bool isProcessing;
  final String? error;
  final bool isChatMode;
  final bool isReflecting;

  BrainDumpState({
    this.messages = const [],
    this.isProcessing = false,
    this.error,
    this.isChatMode = false, // Default: Journal mode
    this.isReflecting = false,
  });

  BrainDumpState copyWith({
    List<ChatMessage>? messages,
    bool? isProcessing,
    String? error,
    bool clearError = false,
    bool? isChatMode,
    bool? isReflecting,
  }) {
    return BrainDumpState(
      messages: messages ?? this.messages,
      isProcessing: isProcessing ?? this.isProcessing,
      error: clearError ? null : (error ?? this.error),
      isChatMode: isChatMode ?? this.isChatMode,
      isReflecting: isReflecting ?? this.isReflecting,
    );
  }
}

class BrainDumpNotifier extends StateNotifier<BrainDumpState> {
  final Ref ref;
  final _uuid = const Uuid();
  StreamSubscription? _currentStreamSubscription;

  BrainDumpNotifier(this.ref) : super(BrainDumpState()) {
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    state = state.copyWith(isProcessing: true, clearError: true);
    try {
      final history = await ref.read(brainServiceProvider).getChatHistory();
      debugPrint(
        'DEBUG PROVIDER: Fetched ${history.length} items. Mounted: $mounted',
      );
      if (!mounted) return;
      if (history.isNotEmpty) {
        // [Architect] SAFE MERGE
        // We prepend history to any messages the user might have typed
        // while the history was loading.
        // History messages already have isRestored=true from fromJson
        state = state.copyWith(
          messages: [...history, ...state.messages],
          isProcessing: false,
        );
        debugPrint(
          'DEBUG PROVIDER: State updated! messages count: ${state.messages.length}',
        );
      } else {
        // Stop loading state even if empty
        state = state.copyWith(isProcessing: false);
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (!mounted) return;
      state = state.copyWith(
        error: "Failed to load history: ${_formatError(e)}",
        isProcessing: false,
      );
    }
  }

  @override
  void dispose() {
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

    // [PERSISTENCE] Save to Notes DB if NOT in Chat Mode
    // This prevents redundant entries for queries (e.g. "what is success?")
    if (!state.isChatMode) {
      unawaited(() async {
        try {
          await ref.read(noteServiceProvider).saveNote(trimmed);
          ref.invalidate(
            notesProvider,
          ); // Refresh "Recent Notes" and Thoughts list
          debugPrint("[DEBUG] Note saved successfully from OmniBar");
        } catch (e) {
          debugPrint("[DEBUG] Note persistence failed: $e");
        }
      }());
    } else {
      debugPrint("[DEBUG] Chat Mode: Skipping persistent note save.");
    }

    // 2. Add "Thinking..." placeholder IMMEDIATELY
    final aiMsgId = _uuid.v4();
    final placeholderMsg = ChatMessage(
      id: aiMsgId,
      content: "Thinking...",
      sender: MessageSender.ai,
      timestamp: DateTime.now(),
      status: MessageStatus.thinking,
    );

    state = state.copyWith(messages: [...state.messages, placeholderMsg]);

    // [CONTEXT] Fetch Location (Graceful degradation)
    Map<String, dynamic>? locationContext;
    try {
      // Add timeout to prevent blocking if location service hangs
      locationContext = await ref
          .read(locationServiceProvider)
          .getCurrentLocationContext()
          .timeout(const Duration(seconds: 3));
      debugPrint("[DEBUG] Location fetched: $locationContext");
    } catch (e) {
      debugPrint("[DEBUG] Location fetch skipped (Timeout/Error): $e");
    }

    // [CONTEXT] Fetch Music Vibe natively
    Map<String, dynamic>? musicContext;
    try {
      final musicState = ref.read(musicSyncControllerProvider);

      final hasCurrentSong =
          musicState.isPlaying && musicState.currentSong != null;
      final hasRecentSongs = musicState.recentSongs.isNotEmpty;

      if (hasCurrentSong || hasRecentSongs) {
        musicContext = {
          "is_playing_now": hasCurrentSong,
          "current_song": hasCurrentSong
              ? {
                  "title": musicState.currentSong!.title ?? "Unknown",
                  "artist": musicState.currentSong!.artistName ?? "Unknown",
                }
              : null,
          "recent_songs": musicState.recentSongs
              .map(
                (s) => {
                  "title": s.title ?? "Unknown",
                  "artist": s.artistName ?? "Unknown",
                },
              )
              .toList(),
          "primary_tone": musicState.analyzedVibe?.primaryTone,
          "short_description": musicState.analyzedVibe?.shortDescription,
        };
        debugPrint(
          "[DEBUG] Injecting Music Context to Chat Payload: $musicContext",
        );
      }
    } catch (e) {
      debugPrint("[DEBUG] Music context fetch skipped: $e");
    }
    
    // [CONTEXT] Fetch Health Snapshot from Riverpod State
    Map<String, dynamic>? healthContext;
    try {
      final healthState = ref.read(healthSyncControllerProvider);
      if (healthState.isAuthorized && healthState.latestSnapshot != null) {
        healthContext = healthState.latestSnapshot!.toJson();
        debugPrint("[DEBUG] Injecting Health Context to Chat Payload: $healthContext");
      }
    } catch (e) {
      debugPrint("[DEBUG] Health context fetch skipped: $e");
    }

    try {
      await _handleQuery(trimmed, locationContext, musicContext, healthContext, aiMsgId);
    } catch (e) {
      // Update ONLY the specific message by ID
      state = state.copyWith(
        messages: state.messages.map((msg) {
          if (msg.id == aiMsgId) {
            return ChatMessage(
              id: msg.id,
              content: "Error: ${_formatError(e)}",
              sender: msg.sender,
              timestamp: DateTime.now(),
              status: MessageStatus.error,
            );
          }
          return msg;
        }).toList(),
      );
      state = state.copyWith(error: e.toString(), isProcessing: false);
    }
  }

  Future<void> _handleQuery(
    String text,
    Map<String, dynamic>? location,
    Map<String, dynamic>? musicContext,
    Map<String, dynamic>? healthContext,
    String aiMsgId,
  ) async {
    // 2.5 Update placeholder with location if available
    if (location != null) {
      state = state.copyWith(
        messages: state.messages.map((msg) {
          if (msg.id == aiMsgId) {
            return msg.copyWith(
              locationContext: location,
            ); // Need to add copyWith to ChatMessage or just recreate
          }
          return msg;
        }).toList(),
      );
    }

    // 3. Stream AI response
    String fullAnswer = "";
    List<String> sources = [];

    try {
      await for (var data in ref.read(brainServiceProvider).askBrain(
        text,
        location: location,
        musicContext: musicContext,
        healthContext: healthContext,
      )) {
        // Handle text chunk
        if (data['chunk'] != null) {
          fullAnswer += data['chunk'];
        }

        // Handle citation sources (usually in the final chunk)
        if (data['sources'] != null) {
          try {
            sources = List<String>.from(data['sources']);
            debugPrint("Received sources: $sources");
          } catch (e) {
            debugPrint("Error parsing sources: $e");
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
                status: MessageStatus
                    .thinking, // Keep thinking status until fully done
                sources: sources.isNotEmpty ? sources : msg.sources,
                locationContext: location, // Ensure location persists
              );
            }
            return msg;
          }).toList(),
        );
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
              content: "Error: ${_formatError(e)}",
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
      state = state.copyWith(isProcessing: false, error: _formatError(e));
      rethrow;
    }
  }

  /// Clear message history from local state and signal backend to reflect
  void clearLocalHistory() {
    state = state.copyWith(messages: []);
    endSession(); // Trigger reflection in background
  }

  /// Signal the backend that a session has ended (manual trigger)
  Future<void> endSession() async {
    state = state.copyWith(isReflecting: true);
    try {
      await ref.read(brainServiceProvider).endSession();
      debugPrint("[DEBUG] End session signal sent to backend");
      
      // Keep reflecting state for a few seconds for visual feedback
      await Future.delayed(const Duration(seconds: 3));
    } catch (e) {
      debugPrint("[DEBUG] End session signal failed: $e");
    } finally {
      if (mounted) {
        state = state.copyWith(isReflecting: false);
      }
    }
  }

  /// Toggle between Chat and Journal mode
  void toggleMode() {
    state = state.copyWith(isChatMode: !state.isChatMode);
  }
}
