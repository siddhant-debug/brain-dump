import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brain_dump/features/onboarding/providers/onboarding_provider.dart';
import 'package:brain_dump/features/onboarding/widgets/selection_card.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:brain_dump/features/auth/controllers/auth_controller.dart';

/*
1 : OnboardingScreen is a multi-step experience for new users.
It guides them through 'Hook', 'Raw Dump', and 'Calibration' phases.
*/
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  /*
  2 : _pageController: Manages horizontal scrolling between onboarding steps.
  _rawDumpController: Captures the initial stream of consciousness thoughts.
  */
  final PageController _pageController = PageController();
  final TextEditingController _rawDumpController = TextEditingController();
  int _currentPage = 0;

  // 3 : Question Data for the Calibration phase (Vibe selection)
  final Map<String, List<String>> _questions = {
    'Current Energy': [
      '🔋 Charged',
      '⚡ Scattered',
      '☁️ Foggy',
      '🔥 Burned Out',
    ],
    'Sonic Fuel': ['🎹 Lo-Fi', '🎸 Metal', '🎧 Techno', '🔇 Silence'],
    'Narrative Mode': [
      '🚀 Sci-Fi (Logic)',
      '⚔️ Fantasy (Lore)',
      '🕵️ Mystery (Analysis)',
      '🎭 Drama (People)',
    ],
    '2026 Goal': ['💻 Building', '📈 Climbing', '🧘 Balancing', '🎨 Creating'],
  };

  @override
  void dispose() {
    _pageController.dispose();
    _rawDumpController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage++);
  }

  @override
  Widget build(BuildContext context) {
    /*
    4 : Watches onboardingProvider to sync UI with selection state across pages.
    */
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // 5 : Phase 1 - The Hook (introductory animation)
          _buildHookPage(),
          // 6 : Phase 2 - The Raw Dump (initial note entry)
          _buildRawDumpPage(state, notifier),
          // 7 : Phase 3 - The Calibration (user preference selection)
          _buildCalibrationPage(state, notifier),
        ],
      ),
    );
  }

  // SCREEN 1: THE HOOK
  Widget _buildHookPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.5, 1.5),
                duration: 1.5.seconds,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 40),
          SizedBox(
            width: 300,
            child: Text(
              "Neural Link Established...\nTo function as your second brain, I need to sync with your reality.",
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                color: const Color(0xFFEDEDED),
                fontSize: 14,
                height: 1.6,
              ),
            ).animate().fadeIn(duration: 1.seconds),
          ),
          const SizedBox(height: 60),
          OutlinedButton(
            onPressed: _nextPage,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFEDEDED), width: 0.5),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Text(
              "SYNC NOW",
              style: GoogleFonts.spaceMono(
                color: const Color(0xFFEDEDED),
                letterSpacing: 2,
                fontSize: 12,
              ),
            ),
          ).animate().fadeIn(delay: 2.seconds).moveY(begin: 10, end: 0),
        ],
      ),
    );
  }

  // SCREEN 2: THE RAW DUMP
  Widget _buildRawDumpPage(OnboardingState state, OnboardingNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          Text(
            "What is occupying your RAM right now?",
            style: GoogleFonts.spaceMono(
              color: const Color(0xFF00E5FF),
              fontSize: 14,
            ),
          ).animate().fadeIn().moveX(begin: -20, end: 0),
          const SizedBox(height: 24),
          Expanded(
            child: TextField(
              controller: _rawDumpController,
              maxLines: null,
              onChanged: (value) {
                notifier.updateRawDump(value);
                setState(() {});
              },
              style: GoogleFonts.inter(
                color: const Color(0xFFEDEDED),
                fontSize: 18,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText:
                    "Don't overthink. Anxiety? Big idea? Todo list? Dump it here...",
                hintStyle: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                border: InputBorder.none,
              ),
              cursorColor: const Color(0xFF00E5FF),
              autofocus: true,
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: TextButton(
              onPressed: state.rawDump.length > 10 ? _nextPage : null,
              child: Text(
                "[ NEXT ]",
                style: GoogleFonts.spaceMono(
                  fontSize: 16,
                  color: state.rawDump.length > 10
                      ? const Color(0xFF00E5FF)
                      : Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // SCREEN 3: THE CALIBRATION
  Widget _buildCalibrationPage(
    OnboardingState state,
    OnboardingNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: ListView(
        children: [
          const SizedBox(height: 60),
          Text(
            "Calibrate System Vibe",
            style: GoogleFonts.spaceMono(
              color: const Color(0xFFFFD600),
              fontSize: 14,
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 32),
          ..._buildQuestionGroup(
            "Current Energy",
            _questions['Current Energy']!,
            state.energyLevel,
            notifier.updateEnergyLevel,
          ),
          ..._buildQuestionGroup(
            "Sonic Fuel",
            _questions['Sonic Fuel']!,
            state.flowMusic,
            notifier.updateFlowMusic,
          ),
          ..._buildQuestionGroup(
            "Narrative Mode",
            _questions['Narrative Mode']!,
            state.narrativeArchetype,
            notifier.updateNarrativeArchetype,
          ),
          ..._buildQuestionGroup(
            "2026 Goal",
            _questions['2026 Goal']!,
            state.primaryGoal,
            notifier.updatePrimaryGoal,
          ),
          const SizedBox(height: 40),
          Center(
            child: OutlinedButton(
              onPressed: _isCalibrationComplete(state)
                  ? () async {
                      notifier.completeOnboarding();

                      // DEBUG: Verify token exists before switching
                      const storage = FlutterSecureStorage();
                      final token = await storage.read(key: 'jwt_token');
                      debugPrint(
                        'DEBUGGING ONBOARDING EXIT: Token is ${token != null ? "PRESENT" : "NULL"}',
                      );

                      // Update provider to trigger main.dart switch
                      ref.read(isNewUserProvider.notifier).state = false;
                      // Navigator.of(context).pushReplacement(...) <-- REMOVED duplicate nav
                    }
                  : null,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _isCalibrationComplete(state)
                      ? const Color(0xFF00E5FF)
                      : Colors.white.withValues(alpha: 0.1),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
              ),
              child: Text(
                "INITIALIZE SYSTEM",
                style: GoogleFonts.spaceMono(
                  color: _isCalibrationComplete(state)
                      ? const Color(0xFF00E5FF)
                      : Colors.white.withValues(alpha: 0.2),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  List<Widget> _buildQuestionGroup(
    String title,
    List<String> options,
    String selectedValue,
    Function(String) onSelect,
  ) {
    return [
      Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: options.map((option) {
          final isSelected = selectedValue == option;
          return SelectionCard(
            label: option,
            isSelected: isSelected,
            onTap: () => onSelect(option),
          );
        }).toList(),
      ),
      const SizedBox(height: 24),
    ];
  }

  bool _isCalibrationComplete(OnboardingState state) {
    return state.energyLevel.isNotEmpty &&
        state.flowMusic.isNotEmpty &&
        state.narrativeArchetype.isNotEmpty &&
        state.primaryGoal.isNotEmpty;
  }
}
