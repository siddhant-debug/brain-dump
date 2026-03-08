import 'package:brain_dump/features/analytics/presentation/settingspage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../../../core/widgets/persistent_header.dart';
import '../../../core/theme/app_theme.dart';
import '../services/analytics_service.dart';
import '../models/analytics_models.dart';

import '../widgets/pipeline_graph_widget.dart';
import '../../music/controllers/music_sync_controller.dart';
import '../../music/services/music_service.dart';
import '../../health/controllers/health_sync_controller.dart';
import '../../health/models/health_snapshot.dart';

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
    final pages = [
      const _InsightsPage(),
      const _LoopsPage(),
      const _HealthPage(),
      const _MusicPage(),
      const _PipelinePage(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            PersistentHeader(
              title: 'Brain Insights',
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.settings_rounded,
                    color: Colors.white24,
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
                  icon: const Icon(Icons.logout_rounded, color: Colors.white24),
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
                    children: const [
                      Icon(
                        Icons.arrow_back_ios,
                        size: 12,
                        color: Colors.white24,
                      ),
                      Text(
                        ' swipe to explore ',
                        style: TextStyle(color: Colors.white24, fontSize: 11),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Colors.white24,
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
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
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
            _PageIndicator(currentPage: _currentPage, pageCount: pages.length),
            const SizedBox(height: 0),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE INDICATOR
// ─────────────────────────────────────────────────────────────────────────────

const _pageAccents = [
  Color(0xFF9b8aff), // Insights — purple
  Color(0xFF60a5fa), // Loops — blue
  Color(0xFF4ade80), // Health — green
  Color(0xFFf472b6), // Music — pink
  Color(0xFF2979FF), // Pipeline — indigo
];

const _pageLabels = ['Insights', 'Loops', 'Health', 'Music', 'Pipeline'];

class _PageIndicator extends StatelessWidget {
  final int currentPage;
  final int pageCount;

  const _PageIndicator({required this.currentPage, required this.pageCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pageCount, (index) {
              final isActive = index == currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: isActive ? 16 : 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isActive ? _pageAccents[index] : Colors.white12,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            _pageLabels[currentPage],
            style: TextStyle(
              color: _pageAccents[currentPage],
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FULL PAGE HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _FullPageHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final Widget? trailing;

  const _FullPageHeader({
    required this.icon,
    required this.title,
    required this.accent,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            ?trailing,
          ],
        ),
        const SizedBox(height: 12),
        Divider(color: accent.withValues(alpha: 0.3), height: 1, thickness: 1),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGES
// ─────────────────────────────────────────────────────────────────────────────

class _InsightsPage extends ConsumerWidget {
  const _InsightsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(consistencyProvider);
        ref.invalidate(themesProvider);
        ref.invalidate(loopsProvider);
        ref.invalidate(pipelineProvider);
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: Colors.white,
      backgroundColor: AppColors.surfaceHigh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
        child: Column(
          children: const [
            _ConsistencyCard(),
            SizedBox(height: 16),
            _ThemesCard(),
          ],
        ),
      ),
    );
  }
}

class _LoopsPage extends ConsumerWidget {
  const _LoopsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loopsProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const _FullPageError(message: 'Could not load loops'),
      data: (data) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FullPageHeader(
              icon: Icons.all_inclusive_rounded,
              title: 'Recurring Loops',
              accent: const Color(0xFF60a5fa),
              trailing: Text(
                '${data.notesScanned} notes',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),
            if (data.loops.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Text(
                  'No recurring patterns found. Keep writing — loops surface over time.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...data.loops.map((loop) => _LoopTile(loop: loop)),
          ],
        ),
      ),
    );
  }
}

class _HealthPage extends ConsumerWidget {
  const _HealthPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthState = ref.watch(healthSyncControllerProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
      child: Column(
        children: [
          _FullPageHeader(
            icon: Icons.health_and_safety_rounded,
            title: 'Health',
            accent: const Color(0xFF4ade80),
            trailing: _HealthStatusChip(state: healthState),
          ),
          const SizedBox(height: 16),
          if (healthState.error != null) _ErrorBanner(healthState.error!),
          if (healthState.isFetching && healthState.latestSnapshot == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (healthState.isAuthorized) ...[
            if (healthState.latestSnapshot != null) ...[
              _buildAllMetrics(healthState.latestSnapshot!),
              const SizedBox(height: 20),
              _DebugPanel(healthState.latestSnapshot!),
            ] else
              _EmptyState(),
          ] else
            _NotConnectedHint(),
        ],
      ),
    );
  }

  Widget _buildAllMetrics(HealthSnapshot snap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Heart'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.favorite_rounded,
                color: Colors.redAccent,
                title: 'Heart Rate',
                value: snap.heartRateCurrent?.toStringAsFixed(0) ?? '--',
                unit: 'bpm',
                subtitle: snap.heartRateAvg24h != null
                    ? '24h avg: ${snap.heartRateAvg24h!.toStringAsFixed(0)} bpm'
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.monitor_heart_outlined,
                color: Colors.pinkAccent,
                title: 'Resting HR',
                value: snap.restingHeartRate?.toStringAsFixed(0) ?? '--',
                unit: 'bpm',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _HRVCard(snap),
        const SizedBox(height: 20),
        const _SectionLabel('Sleep'),
        const SizedBox(height: 10),
        _SleepCard(snap.lastNightSleep),
        const SizedBox(height: 20),
        const _SectionLabel('Activity'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.directions_walk_rounded,
                color: Colors.orangeAccent,
                title: 'Steps Today',
                value: snap.stepsToday?.toString() ?? '--',
                unit: 'steps',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.local_fire_department_rounded,
                color: Colors.deepOrangeAccent,
                title: 'Active Energy',
                value: snap.activeEnergyToday?.toStringAsFixed(0) ?? '--',
                unit: 'kcal',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (snap.weightKg != null || snap.heightCm != null) ...[
          const _SectionLabel('Body'),
          const SizedBox(height: 10),
          Row(
            children: [
              if (snap.weightKg != null)
                Expanded(
                  child: _MetricCard(
                    icon: Icons.monitor_weight_outlined,
                    color: Colors.tealAccent,
                    title: 'Weight',
                    value: snap.weightKg!.toStringAsFixed(1),
                    unit: 'kg',
                  ),
                ),
              if (snap.weightKg != null && snap.heightCm != null)
                const SizedBox(width: 12),
              if (snap.heightCm != null)
                Expanded(
                  child: _MetricCard(
                    icon: Icons.straighten_rounded,
                    color: Colors.cyanAccent,
                    title: 'Height',
                    value: snap.heightCm!.toStringAsFixed(0),
                    unit: 'cm',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        _WorkoutCard(snap.lastWorkout),
      ],
    );
  }
}

class _MusicPage extends ConsumerWidget {
  const _MusicPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final musicState = ref.watch(musicSyncControllerProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
      child: Column(
        children: [
          _FullPageHeader(
            icon: Icons.music_note_rounded,
            title: 'Music Vibe',
            accent: const Color(0xFFf472b6),
            trailing: _MusicStatusChip(state: musicState),
          ),
          const SizedBox(height: 16),
          _buildMusicContent(musicState, ref),
        ],
      ),
    );
  }

  Widget _buildMusicContent(MusicContextState musicState, WidgetRef ref) {
    if (musicState.isAnalyzing) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Analyzing your current vibe...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (!musicState.isAuthorized) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Apple Music is not connected. Connect in the settings to start tracking your music vibe.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref
                .read(musicSyncControllerProvider.notifier)
                .requestPermission(),
            icon: const Icon(Icons.music_note_rounded),
            label: const Text('Connect Apple Music'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      );
    }

    if (!musicState.isPlaying || musicState.currentSong == null) {
      if (musicState.recentSongs.isNotEmpty) {
        return _buildVibeContent(null, musicState);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Play a song on Apple Music to see your current vibe analysis.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      );
    }

    return _buildVibeContent(musicState.currentSong, musicState);
  }

  Widget _buildVibeContent(MusicItem? song, MusicContextState musicState) {
    final vibe = musicState.analyzedVibe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (song != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.album_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Now Playing',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.title ?? 'Unknown Song',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        song.artistName ?? 'Unknown Artist',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.graphic_eq_rounded, color: AppColors.accent),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ] else if (musicState.recentSongs.isNotEmpty) ...[
          Text(
            'Based on your recent listening',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (vibe != null) ...[
          Text(
            'Current Mood',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.subtleCardGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFA5B4FC),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      vibe.primaryTone,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  vibe.shortDescription,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (musicState.recentSongs.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Recent Context',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...musicState.recentSongs.take(5).map((recentSong) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        color: AppColors.textSecondary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recentSong.title ?? 'Unknown Song',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            recentSong.artistName ?? 'Unknown Artist',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ] else if (musicState.error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    musicState.error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PipelinePage extends ConsumerWidget {
  const _PipelinePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pipelineState = ref.watch(pipelineProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
      child: Column(
        children: [
          const _FullPageHeader(
            icon: Icons.account_tree_rounded,
            title: 'Knowledge Pipeline',
            accent: Color(0xFF2979FF),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 500,
            child: pipelineState.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: Colors.white24,
                  strokeWidth: 1.5,
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white24,
                        size: 40,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Could not load pipeline',
                        style: TextStyle(color: Colors.white54, fontSize: 15),
                      ),
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: () => ref.invalidate(pipelineProvider),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              data: (data) => PipelineGraphWidget(nodes: data.nodes),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullPageError extends StatelessWidget {
  final String message;
  const _FullPageError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AppColors.error)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS CHIPS (Helper Widgets)
// ─────────────────────────────────────────────────────────────────────────────

class _HealthStatusChip extends StatelessWidget {
  final HealthContextState state;
  const _HealthStatusChip({required this.state});

  @override
  Widget build(BuildContext context) {
    if (!state.isAuthorized) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Disconnected',
          style: TextStyle(color: AppColors.error, fontSize: 11),
        ),
      );
    }
    final label = state.latestSnapshot?.readinessLabel ?? 'SYNCING';
    final color = switch (label) {
      'HIGH' => Colors.greenAccent,
      'MODERATE' => Colors.orangeAccent,
      'LOW' => Colors.redAccent,
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MusicStatusChip extends StatelessWidget {
  final MusicContextState state;
  const _MusicStatusChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final status = state.isAuthorized ? 'Connected' : 'Disconnected';
    final color = state.isAuthorized ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD SHELL (Modified to remove trailing from Consistency card)
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _Card({required this.title, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.subtleCardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: child,
          ),
        ],
      ),
    );
  }
}

Widget _loadingCard(String title) => _Card(
  title: title,
  child: const Center(
    child: Padding(
      padding: EdgeInsets.all(12),
      child: CircularProgressIndicator(strokeWidth: 2.0),
    ),
  ),
);

Widget _errorCard(String title, String msg) => _Card(
  title: title,
  child: Text(
    msg,
    style: const TextStyle(color: AppColors.error, fontSize: 13),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// CONSISTENCY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ConsistencyCard extends ConsumerWidget {
  const _ConsistencyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(consistencyProvider);
    return state.when(
      loading: () => _loadingCard('Consistency'),
      error: (e, _) =>
          _errorCard('Consistency', 'Could not load consistency data'),
      data: (data) => _ConsistencyContent(data: data),
    );
  }
}

class _ConsistencyContent extends ConsumerWidget {
  final ConsistencyData data;
  const _ConsistencyContent({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      title: 'Consistency',
      subtitle: 'last 30 days',
      // trailing: REMOVED per prompt
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${data.currentStreak}',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'days streak',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 4, 4, 5).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Best: ${data.longestStreak} days  ·  ${data.activeDaysLast30}/30 days active  ·  ${data.totalNotes} notes total',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _HeatmapRow(heatmap: data.heatmap),
        ],
      ),
    );
  }
}

class _HeatmapRow extends StatelessWidget {
  final List<HeatmapDay> heatmap;
  const _HeatmapRow({required this.heatmap});

  @override
  Widget build(BuildContext context) {
    final max = heatmap.fold<int>(0, (m, d) => d.count > m ? d.count : m);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: heatmap.map((day) {
        final intensity = max == 0 ? 0.0 : day.count / max;
        final isActive = day.count > 0;

        return Tooltip(
          message: '${day.date}: ${day.count} note${day.count == 1 ? '' : 's'}',
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.accent.withValues(alpha: 0.3 + (intensity * 0.7))
                  : const Color.fromARGB(
                      255,
                      66,
                      66,
                      80,
                    ).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEMES CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ThemesCard extends ConsumerWidget {
  const _ThemesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(themesProvider);
    return state.when(
      loading: () => _loadingCard('What you think about'),
      error: (e, _) =>
          _errorCard('What you think about', 'Could not load theme data'),
      data: (data) => _ThemesContent(data: data),
    );
  }
}

class _ThemesContent extends StatelessWidget {
  final ThemesData data;
  const _ThemesContent({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.themes.isEmpty) {
      return _Card(
        title: 'What you think about',
        subtitle:
            'last ${data.windowDays} days — ${data.totalNotesAnalyzed} notes',
        child: Text(
          'Not enough notes to identify themes yet.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      );
    }

    return _Card(
      title: 'What you think about',
      subtitle:
          'last ${data.windowDays} days — ${data.totalNotesAnalyzed} notes',
      child: Column(
        children: data.themes.take(6).map((theme) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      theme.name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${theme.pct}%',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Container(
                          height: 6,
                          width: constraints.maxWidth,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHighlight.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Container(
                          height: 6,
                          width:
                              constraints.maxWidth *
                              (theme.pct / 100).clamp(0, 1),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOOPS HELPER WIDGETS (Self-contained)
// ─────────────────────────────────────────────────────────────────────────────

class _LoopTile extends StatefulWidget {
  final LoopCluster loop;
  const _LoopTile({required this.loop});

  @override
  State<_LoopTile> createState() => _LoopTileState();
}

class _LoopTileState extends State<_LoopTile> {
  bool _expanded = false;

  Color get _severityColor {
    switch (widget.loop.severity) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return Colors.orangeAccent;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loop = widget.loop;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _severityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _severityColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${loop.occurrences}×',
                      style: TextStyle(
                        color: _severityColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loop.themeGuess,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${loop.firstSeen} → ${loop.lastSeen}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: Colors.white12),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...loop.notes.map(
                    (n) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4, right: 10),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.date,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  n.preview,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _severityColor.withValues(alpha: 0.15),
                          _severityColor.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _severityColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          color: _severityColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            loop.pathForward,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEALTH HELPER WIDGETS (Self-contained)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String unit;
  final String? subtitle;

  const _MetricCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.unit,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _HRVCard extends StatelessWidget {
  final HealthSnapshot snap;
  const _HRVCard(this.snap);

  @override
  Widget build(BuildContext context) {
    final current = snap.hrvCurrent;
    final avg = snap.hrvAvg7d;
    final hasData = current != null;

    Color trendColor = AppColors.textSecondary;
    String trendLabel = '';
    if (current != null && avg != null) {
      if (current >= avg) {
        trendColor = Colors.greenAccent;
        trendLabel = '↑ Above 7d avg';
      } else if (current >= avg * 0.85) {
        trendColor = Colors.orangeAccent;
        trendLabel = '~ Near 7d avg';
      } else {
        trendColor = Colors.redAccent;
        trendLabel = '↓ Below 7d avg';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.graphic_eq_rounded,
            color: Colors.purpleAccent,
            size: 22,
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HRV (Heart Rate Variability)',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    hasData ? current.toStringAsFixed(1) : '--',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ms',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (avg != null)
                Text(
                  '7d avg: ${avg.toStringAsFixed(1)} ms',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 4),
              if (trendLabel.isNotEmpty)
                Text(
                  trendLabel,
                  style: TextStyle(
                    color: trendColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SleepCard extends StatelessWidget {
  final SleepSummary? sleep;
  const _SleepCard(this.sleep);

  @override
  Widget build(BuildContext context) {
    if (sleep == null) {
      return const _EmptyMetricCard(
        icon: Icons.nights_stay_rounded,
        color: Colors.indigoAccent,
        title: 'Sleep',
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.nights_stay_rounded,
                color: Colors.indigoAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Sleep Last Night',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    sleep!.totalHours.toStringAsFixed(1),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'hrs',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SleepStage(
                label: 'Deep',
                hours: sleep!.deepHours,
                color: Colors.indigoAccent,
              ),
              const SizedBox(width: 12),
              _SleepStage(
                label: 'REM',
                hours: sleep!.remHours,
                color: Colors.purpleAccent,
              ),
              const SizedBox(width: 12),
              _SleepStage(
                label: 'Awake',
                hours: sleep!.awakeHours,
                color: Colors.orangeAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SleepStage extends StatelessWidget {
  final String label;
  final double hours;
  final Color color;
  const _SleepStage({
    required this.label,
    required this.hours,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label ${hours.toStringAsFixed(1)}h',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final WorkoutSummary? workout;
  const _WorkoutCard(this.workout);

  @override
  Widget build(BuildContext context) {
    if (workout == null) {
      return const _EmptyMetricCard(
        icon: Icons.fitness_center_rounded,
        color: Colors.lightGreenAccent,
        title: 'Last Workout',
      );
    }
    return _MetricCard(
      icon: Icons.fitness_center_rounded,
      color: Colors.lightGreenAccent,
      title: 'Last Workout',
      value: workout!.durationMinutes.toStringAsFixed(0),
      unit: 'min',
      subtitle: workout!.calories != null
          ? '${workout!.type} · ${workout!.calories!.toStringAsFixed(0)} kcal'
          : workout!.type,
    );
  }
}

class _EmptyMetricCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  const _EmptyMetricCard({
    required this.icon,
    required this.color,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color.withValues(alpha: 0.3), size: 16),
              const SizedBox(width: 6),
              const Text(
                'No data',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String error;
  const _ErrorBanner(this.error);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'No health data yet — try refreshing.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _NotConnectedHint extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Text(
              'Tap "Connect Apple Health" to grant access\nand see your health data here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref
                  .read(healthSyncControllerProvider.notifier)
                  .requestPermission(),
              icon: const Icon(Icons.health_and_safety_rounded),
              label: const Text('Connect Apple Health'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugPanel extends StatefulWidget {
  final HealthSnapshot snap;
  const _DebugPanel(this.snap);

  @override
  State<_DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<_DebugPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Text(
              'RAG Debug Data',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            trailing: Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
              size: 16,
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                widget.snap.toRagContext(),
                style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  fontFamily: 'Courier',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
