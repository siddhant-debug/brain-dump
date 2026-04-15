import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/onboarding_provider.dart';

class LifePathOnboardingScreen extends ConsumerStatefulWidget {
  const LifePathOnboardingScreen({super.key});

  @override
  ConsumerState<LifePathOnboardingScreen> createState() => _LifePathOnboardingScreenState();
}

class _LifePathOnboardingScreenState extends ConsumerState<LifePathOnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _monologueController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _monologueController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildMCQStep(state, notifier),
                  _buildMonologueStep(state, notifier),
                  _buildMacroGoalStep(state, notifier),
                ],
              ),
            ),
            _buildFooter(state, notifier),
          ],
        ),
      ),
    );
  }

  Widget _buildMCQStep(OnboardingState state, OnboardingNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Let's calibrate your graph.",
            style: AppTextStyles.h1(Colors.white).copyWith(
            color: Colors.white.withValues(alpha: 0.9),
              fontSize: 28,
              fontWeight: FontWeight.w400,
            ),
          ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.1),
          const SizedBox(height: 48),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildQuestion(
                    "What brings you to the graph?",
                    [
                      "Organizing the chaos",
                      "Tracking personal growth",
                      "Building a project",
                      "A quiet place to think"
                    ],
                    state.baselineQ1,
                    notifier.updateBaselineQ1,
                  ),
                  const SizedBox(height: 32),
                  if (state.baselineQ1.isNotEmpty)
                    _buildQuestion(
                      "How does your mind feel lately?",
                      [
                        "Clear & focused",
                        "Racing with ideas",
                        "Overwhelmed",
                        "Seeking direction"
                      ],
                      state.baselineQ2,
                      notifier.updateBaselineQ2,
                    ).animate().fadeIn(),
                  const SizedBox(height: 32),
                  if (state.baselineQ2.isNotEmpty)
                    _buildQuestion(
                      "What's the biggest friction today?",
                      [
                        "Information overload",
                        "Lack of consistency",
                        "No clear macro view",
                        "Disconnect from goals"
                      ],
                      state.baselineQ3,
                      notifier.updateBaselineQ3,
                    ).animate().fadeIn(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(String question, List<String> options, String current, Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: AppTextStyles.body(Colors.white.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 16),
        ...options.map((opt) {
          final isSelected = current == opt;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: InkWell(
              onTap: () => onSelect(opt),
              borderRadius: BorderRadius.circular(30),
              child: AnimatedContainer(
                duration: 300.ms,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2A2A2A) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  opt,
                  style: AppTextStyles.h3(isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7)).copyWith(
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMonologueStep(OnboardingState state, OnboardingNotifier notifier) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text(
              "Your inner monologue.",
              style: AppTextStyles.h2(Colors.white).copyWith(fontSize: 24),
            ).animate().fadeIn(),
            const SizedBox(height: 8),
            Text(
              "What's the one thing you can't stop thinking about?",
              textAlign: TextAlign.center,
              style: AppTextStyles.body(Colors.white).copyWith(color: Colors.white54),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 48),
            TextField(
              controller: _monologueController,
              onChanged: notifier.updateInnerMonologue,
              maxLines: null,
              minLines: 3,
              autofocus: true,
              cursorColor: Colors.white24,
              style: AppTextStyles.bodyMed(Colors.white).copyWith(fontSize: 18),
              decoration: InputDecoration(
                hintText: "Type freely...",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.1)),
                border: InputBorder.none,
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroGoalStep(OnboardingState state, OnboardingNotifier notifier) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.blur_on, color: Colors.white24, size: 60).animate().scale(),
            const SizedBox(height: 24),
            Text(
              "Define your macro node.",
              style: AppTextStyles.h2(Colors.white).copyWith(fontSize: 24),
            ).animate().fadeIn(),
            const SizedBox(height: 8),
            Text(
              "This is the star everything else orbits.",
              style: AppTextStyles.body(Colors.white).copyWith(color: Colors.white54),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 48),
            TextField(
              controller: _goalController,
              onChanged: notifier.updateMacroGoal,
              textAlign: TextAlign.center,
              autofocus: true,
              cursorColor: Colors.white24,
              style: AppTextStyles.h2(Colors.white).copyWith(fontSize: 22),
              decoration: InputDecoration(
                hintText: "e.g. Building a legacy",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.05)),
                border: InputBorder.none,
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(OnboardingState state, OnboardingNotifier notifier) {
    bool canProceed = false;
    if (_currentPage == 0) {
      canProceed = state.baselineQ1.isNotEmpty && state.baselineQ2.isNotEmpty && state.baselineQ3.isNotEmpty;
    } else if (_currentPage == 1) {
      canProceed = state.innerMonologue.length > 10;
    } else {
      canProceed = state.macroGoal.length > 5;
    }

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            TextButton(
              onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
              ),
              child: Text(
                "Back",
                style: AppTextStyles.body(Colors.white).copyWith(color: Colors.white24),
              ),
            )
          else
            const SizedBox.shrink(),
          
          InkWell(
            onTap: canProceed ? (_currentPage < 2 ? _nextPage : _submit) : null,
            child: AnimatedContainer(
              duration: 300.ms,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: canProceed ? Colors.white : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(30),
                boxShadow: canProceed ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ] : [],
              ),
              child: Text(
                _currentPage < 2 ? "Continue" : "Begin Path →",
                style: AppTextStyles.h3(canProceed ? Colors.black : Colors.white24).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() async {
    final success = await ref.read(onboardingProvider.notifier).submitLifePathBaseline();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sync failed. Check connection.")),
      );
    }
  }
}
