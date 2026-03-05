import 'package:brain_dump/features/analytics/presentation/settingspage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../../../core/widgets/persistent_header.dart';
import '../../../core/theme/app_theme.dart';
import '../services/analytics_service.dart';
import '../models/analytics_models.dart';

import '../widgets/pipeline_sheet.dart';
import '../widgets/loops_bottom_sheet.dart';
import '../../music/controllers/music_sync_controller.dart';
import '../../music/presentation/widgets/music_vibe_bottom_sheet.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Main content (header + scrollable cards) ─────────────────
            Column(
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
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white24,
                      ),
                      onPressed: () =>
                          ref.read(authControllerProvider.notifier).signOut(),
                      tooltip: 'Sign out',
                    ),
                  ],
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(consistencyProvider);
                      ref.invalidate(themesProvider);
                      ref.invalidate(loopsProvider);
                      ref.invalidate(pipelineProvider);
                      // Adding a small delay to let the UI show the loading indicator
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    color: Colors.white,
                    backgroundColor: AppColors.surfaceHigh,
                    child: SingleChildScrollView(
                      physics:
                          const AlwaysScrollableScrollPhysics(), // Important for RefreshIndicator
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
                      child: Column(
                        children: const [
                          _ConsistencyCard(),
                          SizedBox(height: 16),
                          _ThemesCard(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD SHELL
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  const _Card({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

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
                ?trailing,
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
// 1. CONSISTENCY CARD
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
    final loopsState = ref.watch(loopsProvider);
    final musicState = ref.watch(musicSyncControllerProvider);

    return _Card(
      title: 'Consistency',
      subtitle: 'last 30 days',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPipelineButton(context),
          const SizedBox(width: 8),
          _buildMusicButton(context, musicState),
          const SizedBox(width: 8),
          _buildLoopsButton(context, loopsState),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Big streak number
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
                padding: EdgeInsets.only(bottom: 10),
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
          // Heatmap — 30 dots in a row
          _HeatmapRow(heatmap: data.heatmap),
        ],
      ),
    );
  }

  Widget _buildLoopsButton(
    BuildContext context,
    AsyncValue<LoopsData> loopsState,
  ) {
    return loopsState.when(
      data: (loopsData) => IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.all_inclusive_rounded,
            color: AppColors.accent,
            size: 20,
          ),
        ),
        tooltip: 'View Recurring Loops',
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (context) => LoopsBottomSheet(data: loopsData),
          );
        },
      ),
      loading: () => const Padding(
        padding: EdgeInsets.all(12.0),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildMusicButton(BuildContext context, MusicContextState musicState) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          shape: BoxShape.circle,
        ),
        child: Icon(
          musicState.isPlaying
              ? Icons.graphic_eq_rounded
              : Icons.music_note_rounded,
          color: musicState.isPlaying
              ? AppColors.accent
              : AppColors.textSecondary,
          size: 20,
        ),
      ),
      tooltip: 'Current Music Vibe',
      onPressed: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => const MusicVibeBottomSheet(),
        );
      },
    );
  }

  Widget _buildPipelineButton(BuildContext context) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.account_tree_rounded,
          color: Color(0xFF2979FF),
          size: 20,
        ),
      ),
      tooltip: 'View Knowledge Pipeline',
      onPressed: () => showPipelineSheet(context),
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

        // Use a gradient for active days or empty dark surface container
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
// 2. THEMES CARD
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
                // Progress bar
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
                            color: AppColors.success, // India Green for growth
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
