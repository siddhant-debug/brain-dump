import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/providers/dio_provider.dart';
import '../../auth/controllers/auth_controller.dart';

class OnboardingState {
  final String baselineQ1;
  final String baselineQ2;
  final String baselineQ3;
  final String innerMonologue;
  final String macroGoal;

  const OnboardingState({
    this.baselineQ1 = '',
    this.baselineQ2 = '',
    this.baselineQ3 = '',
    this.innerMonologue = '',
    this.macroGoal = '',
  });

  OnboardingState copyWith({
    String? baselineQ1,
    String? baselineQ2,
    String? baselineQ3,
    String? innerMonologue,
    String? macroGoal,
  }) {
    return OnboardingState(
      baselineQ1: baselineQ1 ?? this.baselineQ1,
      baselineQ2: baselineQ2 ?? this.baselineQ2,
      baselineQ3: baselineQ3 ?? this.baselineQ3,
      innerMonologue: innerMonologue ?? this.innerMonologue,
      macroGoal: macroGoal ?? this.macroGoal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'baselineQ1': baselineQ1,
      'baselineQ2': baselineQ2,
      'baselineQ3': baselineQ3,
      'innerMonologue': innerMonologue,
      'macroGoal': macroGoal,
    };
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final Ref ref;
  OnboardingNotifier(this.ref) : super(const OnboardingState());

  void updateBaselineQ1(String value) => state = state.copyWith(baselineQ1: value);
  void updateBaselineQ2(String value) => state = state.copyWith(baselineQ2: value);
  void updateBaselineQ3(String value) => state = state.copyWith(baselineQ3: value);
  void updateInnerMonologue(String value) => state = state.copyWith(innerMonologue: value);
  void updateMacroGoal(String value) => state = state.copyWith(macroGoal: value);

  /*
  2 : completeOnboarding: Serializes the collected 'Vibe' data for persistence.
  */
  Future<bool> submitLifePathBaseline() async {
    final dio = ref.read(dioProvider);
    final authController = ref.read(authControllerProvider.notifier);
    final token = await authController.getToken();

    if (token == null) return false;

    // Package Step 1 & 2 answers as the baseline text
    final baselineText = """
Friction: ${state.baselineQ3}
Current Mindset: ${state.baselineQ2}
Core Intent: ${state.baselineQ1}
Monologue: ${state.innerMonologue}
""".trim();

    try {
      final response = await dio.post(
        '/api/lifepath/baseline',
        data: {
          'baseline_text': baselineText,
          'macro_goal': state.macroGoal,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        // Refresh the user state so main.dart knows we're done
        ref.invalidate(userProvider);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Onboarding] Submission failed: $e');
      return false;
    }
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier(ref);
});
