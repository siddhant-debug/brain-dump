import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GitaState {
  final int index;
  final bool isDailyRotation;

  GitaState({required this.index, this.isDailyRotation = true});
}

class GitaNotifier extends StateNotifier<GitaState> {
  final int maxQuotes;
  
  GitaNotifier(this.maxQuotes) : super(GitaState(index: 0)) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = prefs.getString('gita_last_date');
    
    if (lastDate == today) {
      final savedIndex = prefs.getInt('gita_index') ?? 0;
      state = GitaState(index: savedIndex, isDailyRotation: true);
    } else {
      // Rotate for new day
      final newIndex = (DateTime.now().difference(DateTime(2024)).inDays) % maxQuotes;
      await prefs.setString('gita_last_date', today);
      await prefs.setInt('gita_index', newIndex);
      state = GitaState(index: newIndex, isDailyRotation: true);
    }
  }

  Future<void> refresh() async {
    final nextIndex = (state.index + 1) % maxQuotes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gita_index', nextIndex);
    // Note: we don't update gita_last_date here to allow it to stay on this index for the day unless refreshed again
    state = GitaState(index: nextIndex, isDailyRotation: false);
  }
}

final gitaProvider = StateNotifierProvider<GitaNotifier, GitaState>((ref) {
  // Hardcoded for now but could be injected
  return GitaNotifier(4); // We have 4 quotes in the widget
});
