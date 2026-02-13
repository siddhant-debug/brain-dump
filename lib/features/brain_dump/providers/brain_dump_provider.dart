import 'dart:io';
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

class BrainDumpNotifier extends StateNotifier<BrainDumpState> {
  final Ref ref;
  BrainDumpNotifier(this.ref) : super(BrainDumpState());

  Future<void> processInput(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    state = state.copyWith(isProcessing: true);

    try {
      if (trimmed.endsWith('?')) {
        await _handleQuery(trimmed);
      } else {
        await _saveNote(trimmed);
      }
      state = state.copyWith(error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow; // So screen can catch it too
    } finally {
      state = state.copyWith(isProcessing: false);
    }
  }

  Future<void> uploadMarkdown(File file) async {
    state = state.copyWith(isProcessing: true);
    try {
      debugPrint('📎 [Architect] Processing MD Upload: ${file.path}');
      await Future.delayed(const Duration(milliseconds: 800));
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isProcessing: false);
    }
  }

  Future<void> _handleQuery(String text) async {
    debugPrint('🔍 [Architect] Query logic: "$text"');
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _saveNote(String text) async {
    await ref.read(noteServiceProvider).saveNote(text);
  }
}
