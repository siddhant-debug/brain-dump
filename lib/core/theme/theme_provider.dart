import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';

class ThemeState {
  final CircadianPhase phase;
  final bool isDark;
  final CircadianPhase? previousPhase;
  final double transitionProgress; // 0.0 = fully previous, 1.0 = fully current

  ThemeState({
    required this.phase,
    required this.isDark,
    this.previousPhase,
    this.transitionProgress = 1.0,
  });

  ThemeState copyWith({
    CircadianPhase? phase,
    bool? isDark,
    CircadianPhase? previousPhase,
    double? transitionProgress,
  }) {
    return ThemeState(
      phase: phase ?? this.phase,
      isDark: isDark ?? this.isDark,
      previousPhase: previousPhase ?? this.previousPhase,
      transitionProgress: transitionProgress ?? this.transitionProgress,
    );
  }

  CircadianColors get colors {
    if (previousPhase == null || transitionProgress >= 1.0) {
      return CircadianColors.forPhase(phase);
    }
    return CircadianColors.lerp(
      CircadianColors.forPhase(previousPhase!),
      CircadianColors.forPhase(phase),
      transitionProgress,
    );
  }

  ThemeData get themeData => AppTheme.build(phase);
}

class ThemeNotifier extends Notifier<ThemeState> {
  Timer? _timer;
  double _t = 1.0;
  Timer? _lerpTimer;

  @override
  ThemeState build() {
    final initialPhase = _calculatePhase();
    
    // Start periodic check every 60 seconds as requested
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      final newPhase = _calculatePhase();
      if (newPhase != state.phase) {
        final prev = state.phase;
        state = state.copyWith(
          phase: newPhase,
          isDark: _isDarkPhase(newPhase),
          previousPhase: prev,
          transitionProgress: 0.0,
        );
        _startTransition();
      }
    });

    // Ensure timer is cancelled when provider is disposed
    ref.onDispose(() {
      _timer?.cancel();
      _lerpTimer?.cancel();
    });

    return ThemeState(
      phase: initialPhase,
      isDark: _isDarkPhase(initialPhase),
    );
  }

  void _startTransition() {
    _t = 0.0;
    _lerpTimer?.cancel();
    _lerpTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _t = (_t + 16 / 600).clamp(0.0, 1.0);
      state = state.copyWith(transitionProgress: _t);
      if (_t >= 1.0) timer.cancel();
    });
  }

  void toggleTheme() {
    final nextPhase = _getNextPhase(state.phase);
    final prev = state.phase;
    state = state.copyWith(
      phase: nextPhase,
      isDark: _isDarkPhase(nextPhase),
      previousPhase: prev,
      transitionProgress: 0.0,
    );
    _startTransition();
  }

  CircadianPhase _getNextPhase(CircadianPhase current) {
    switch (current) {
      case CircadianPhase.dawn:
        return CircadianPhase.day;
      case CircadianPhase.day:
        return CircadianPhase.dusk;
      case CircadianPhase.dusk:
        return CircadianPhase.night;
      case CircadianPhase.night:
        return CircadianPhase.dawn;
    }
  }

  CircadianPhase _calculatePhase() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 10) return CircadianPhase.dawn;
    if (hour >= 10 && hour < 17) return CircadianPhase.day;
    if (hour >= 17 && hour < 21) return CircadianPhase.dusk;
    return CircadianPhase.night;
  }

  bool _isDarkPhase(CircadianPhase phase) {
    return phase == CircadianPhase.dusk || phase == CircadianPhase.night;
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);

// Legacy compatibility provider to minimize breaks in Stage 1
final themeModeProvider = Provider<bool>((ref) {
  return ref.watch(themeProvider).isDark;
});
