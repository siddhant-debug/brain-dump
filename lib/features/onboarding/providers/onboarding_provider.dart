import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingState {
  final String rawDump;
  final String energyLevel;
  final String flowMusic;
  final String narrativeArchetype;
  final String primaryGoal;

  const OnboardingState({
    this.rawDump = '',
    this.energyLevel = '',
    this.flowMusic = '',
    this.narrativeArchetype = '',
    this.primaryGoal = '',
  });

  OnboardingState copyWith({
    String? rawDump,
    String? energyLevel,
    String? flowMusic,
    String? narrativeArchetype,
    String? primaryGoal,
  }) {
    return OnboardingState(
      rawDump: rawDump ?? this.rawDump,
      energyLevel: energyLevel ?? this.energyLevel,
      flowMusic: flowMusic ?? this.flowMusic,
      narrativeArchetype: narrativeArchetype ?? this.narrativeArchetype,
      primaryGoal: primaryGoal ?? this.primaryGoal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rawDump': rawDump,
      'energyLevel': energyLevel,
      'flowMusic': flowMusic,
      'narrativeArchetype': narrativeArchetype,
      'primaryGoal': primaryGoal,
    };
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  void updateRawDump(String dump) {
    state = state.copyWith(rawDump: dump);
  }

  void updateEnergyLevel(String level) {
    state = state.copyWith(energyLevel: level);
  }

  void updateFlowMusic(String music) {
    state = state.copyWith(flowMusic: music);
  }

  void updateNarrativeArchetype(String archetype) {
    state = state.copyWith(narrativeArchetype: archetype);
  }

  void updatePrimaryGoal(String goal) {
    state = state.copyWith(primaryGoal: goal);
  }

  Map<String, dynamic> completeOnboarding() {
    final data = state.toJson();
    // In a real app, this would be an API call
    print('[Onboarding] Syncing to Neural Core: $data');
    return data;
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
      return OnboardingNotifier();
    });
