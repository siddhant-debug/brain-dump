import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../notes/services/note_service.dart';

final brainDumpProvider =
    StateNotifierProvider<BrainDumpNotifier, BrainDumpState>((ref) {
      return BrainDumpNotifier(ref);
    });

class BrainDumpState {
  final bool isProcessing;
  final String? error;

  BrainDumpState({this.isProcessing = false, this.error});

  BrainDumpState copyWith({bool? isProcessing, String? error}) {
    return BrainDumpState(
      isProcessing: isProcessing ?? this.isProcessing,
      error: error ?? this.error,
    );
  }
}

/*
1 : BrainDumpNotifier orchestrates the processing of user input.
It differentiates between queries (ending in '?') and standard notes.
*/
class BrainDumpNotifier extends StateNotifier<BrainDumpState> {
  final Ref ref;
  BrainDumpNotifier(this.ref) : super(BrainDumpState());

  /*
  2 : processInput: The primary entry point for submissions from BrainDumpScreen.
  It triggers either query handling or note shifting/saving.
  */
  Future<void> processInput(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    state = state.copyWith(isProcessing: true);

    try {
      if (trimmed.endsWith('?')) {
        // Handle as a search/query
        await _handleQuery(trimmed);
      } else {
        // Handle as a memory/note to persist
        await _saveNote(trimmed);
      }
      state = state.copyWith(error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      state = state.copyWith(isProcessing: false);
    }
  }

  /*
  3 : _handleQuery: Dedicated logic for conversational interactions (Future integration site).
  */
  Future<void> _handleQuery(String text) async {
    debugPrint('🔍 [Architect] Query logic: "$text"');
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /*
  4 : _saveNote: Uses NoteService to persist the thought to the cloud vault.
  */
  Future<void> _saveNote(String text) async {
    await ref.read(noteServiceProvider).saveNote(text);
  }
}
