import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../../../core/widgets/persistent_header.dart';
import '../../../core/theme/theme_provider.dart';
import 'settingspage.dart';
import 'pages/health_page.dart';
import 'pages/music_page.dart';
import 'widgets/page_indicator.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _showSwipeHint = false;

  @override
  void initState() {
    super.initState();
    _checkSwipeHint();
  }

  Future<void> _checkSwipeHint() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSwiped = prefs.getBool('has_swiped_insights') ?? false;
    if (!hasSwiped) {
      if (mounted) {
        setState(() => _showSwipeHint = true);
      }
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _showSwipeHint = false);
        }
      });
    }
  }

  Future<void> _markSwiped() async {
    if (!_showSwipeHint && _currentPage == 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_swiped_insights', true);
    if (mounted) {
      setState(() => _showSwipeHint = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final colors = themeState.colors;

    const pages = [
      //InsightsPage(),
      //LoopsPage(),
      HealthPage(),
      MusicPage(),
      //PipelinePage(),
    ];

    return Scaffold(
      backgroundColor: colors.bgTop,
      body: SafeArea(
        child: Column(
          children: [
            PersistentHeader(
              title: 'Health and Music',
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.settings_rounded,
                    color: colors.textDim,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MySettings(),
                      ),
                    );
                  },
                  tooltip: 'Settings',
                ),
                IconButton(
                  icon: Icon(Icons.logout_rounded, color: colors.textDim),
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                  tooltip: 'Sign out',
                ),
              ],
            ),
            if (_currentPage == 0)
              AnimatedOpacity(
                opacity: _showSwipeHint ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 600),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_back_ios,
                        size: 12,
                        color: colors.textDim,
                      ),
                      Text(
                        ' swipe to explore ',
                        style: TextStyle(color: colors.textDim, fontSize: 11),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: colors.textDim,
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                  if (i > 0) _markSwiped();
                },
                children: pages.map((page) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: colors.bgTop,
                      borderRadius: BorderRadius.circular(0),
                      boxShadow: [
                        BoxShadow(
                          color: colors.bgBottom.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(-4, 0), // shadow on left edge
                        ),
                      ],
                    ),
                    child: page,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 2),
            PageIndicator(currentPage: _currentPage, pageCount: pages.length),
            const SizedBox(height: 0),
          ],
        ),
      ),
    );
  }
}
