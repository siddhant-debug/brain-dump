import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';

// Screens
import 'brain_dump_screen.dart';
import '../features/analytics/presentation/analytics_screen.dart';
import '../features/music/controllers/music_sync_controller.dart';
import '../features/vault/presentation/file_vault_screen.dart';
import '../features/vault/presentation/thoughts_screen.dart';
import '../features/health/controllers/health_sync_controller.dart';
import '../widgets/gita_quote_widget.dart';
import '../widgets/life_path_widget.dart';
import '../widgets/readiness_row.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../features/notes/models/note.dart';
import '../features/notes/services/note_service.dart';
import '../features/brain_dump/providers/brain_dump_provider.dart';
import '../../widgets/omni_bar.dart';
import '../features/music/models/music_playback_state.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const _HomeTab(),
    const BrainDumpScreen(),
    const AnalyticsScreen(),
    const FileVaultScreen(isEmbedded: true),
    const ThoughtsScreen(isEmbedded: true),
  ];

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final colors = themeState.colors;

    return Scaffold(
      backgroundColor: colors.bgTop,
      body: AnimatedContainer(
        duration: AppDuration.phaseTransition,
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.bgTop, colors.bgBottom],
          ),
        ),
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: _buildFlatBottomNav(colors),
    );
  }

  Widget _buildFlatBottomNav(CircadianColors colors) {
    final items = [
      (Icons.home_outlined, Icons.home_rounded, 'Home'),
      (Icons.psychology_outlined, Icons.psychology_rounded, 'Brain'),
      (Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Insights'),
      (Icons.folder_outlined, Icons.folder_rounded, 'Vault'),
      (Icons.lightbulb_outline, Icons.lightbulb_rounded, 'Thoughts'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: colors.bgTop,
        border: Border(
          top: BorderSide(color: colors.surfaceBorder, width: 0.5),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(items.length, (index) {
          final isSelected = _currentIndex == index;
          final item = items[index];
          
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (index == 2) {}
              setState(() => _currentIndex = index);
            },
            child: SizedBox(
              width: 60,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // IMPROVEMENT: Area 2f — BottomNav Active Indicator Refinement
                  AnimatedScale(
                    scale: isSelected ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      isSelected ? item.$2 : item.$1,
                      size: 24,
                      color: isSelected ? colors.accent : colors.textDim.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? 4 : 0,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _HomeTab extends ConsumerStatefulWidget {
  const _HomeTab();

  @override
  ConsumerState<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<_HomeTab> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSubmitted() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(brainDumpProvider.notifier).processInput(text);
    _controller.clear();
    _focusNode.unfocus();
  }

  String _getGreeting(String? email, String? fullName) {
    final name = fullName?.trim().isNotEmpty == true
        ? fullName!.split(' ').first
        : email?.split('@').first.trim();
    return name?.isNotEmpty == true ? name! : '';
  }

  String _getGreetPrefix(CircadianPhase phase) {
    switch (phase) {
      case CircadianPhase.dawn:
        return "Good morning,";
      case CircadianPhase.day:
        return "Good afternoon,";
      case CircadianPhase.dusk:
        return "Good evening,";
      case CircadianPhase.night:
        return "Good night,";
    }
  }

  MusicPlaybackState _getPlaybackState(MusicContextState? music) {
    if (music == null) return MusicPlaybackState.unknown;
    if (!music.isAuthorized) return MusicPlaybackState.noPermission;
    if (music.isPlaying) return MusicPlaybackState.playing;
    if (music.currentSong != null) return MusicPlaybackState.paused;
    return MusicPlaybackState.stopped;
  }

  Widget _buildContextPill({
    required String icon,
    String? value,
    Color? valueColor,
    required CircadianColors colors,
  }) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: _ContextPill(
        icon: icon,
        label: value,
        color: valueColor ?? colors.textDim,
        borderColor: colors.surfaceBorder,
      ),
    );
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return "${(steps / 1000).toStringAsFixed(1)}k";
    }
    return steps.toString();
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  Widget _buildNoteMetadata(Note note, CircadianColors colors) {
    final List<Widget> tags = [];

    if (note.locationName?.isNotEmpty == true) {
      tags.add(_MetaTag(icon: "📍", label: note.locationName!, colors: colors));
    }
    if (note.musicTrack?.isNotEmpty == true) {
      // Truncate long track names so the row doesn't overflow
      final track = note.musicTrack!.length > 22
          ? '${note.musicTrack!.substring(0, 22)}…'
          : note.musicTrack!;
      tags.add(_MetaTag(icon: "🎵", label: track, colors: colors));
    }
    if (note.focusMode?.isNotEmpty == true) {
      tags.add(_MetaTag(icon: "🎯", label: note.focusMode!, colors: colors));
    }
    if (note.healthReadiness?.isNotEmpty == true) {
      tags.add(_MetaTag(icon: "⚡", label: note.healthReadiness!, colors: colors));
    }
    // Time always last
    tags.add(_MetaTag(icon: "🕒", label: _formatTime(note.createdAt), colors: colors));

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: tags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final colors = themeState.colors;
    final musicState = ref.watch(musicSyncControllerProvider);
    final healthState = ref.watch(healthSyncControllerProvider);
    final notesAsync = ref.watch(notesProvider);
    final userAsync = ref.watch(userProvider);

    final user = userAsync.value;
    final name = _getGreeting(user?.email, user?.fullName);
    final prefix = _getGreetPrefix(themeState.phase);
    final greetText = name.isEmpty ? prefix : "$prefix $name";

    final musicStatus = _getPlaybackState(musicState);
    final isMusicVisible =
        musicStatus == MusicPlaybackState.playing ||
        musicStatus == MusicPlaybackState.paused;

    return SafeArea(
      child: RefreshIndicator(
        // IMPROVEMENT: Area 2g — Pull-to-Refresh Indicator Theming
        color: colors.accent,
        backgroundColor: colors.bgTop,
        onRefresh: () async {
          ref.invalidate(notesProvider);
          ref.invalidate(userProvider);
          ref.invalidate(healthSyncControllerProvider);
          ref.invalidate(musicSyncControllerProvider);
          ref.invalidate(brainDumpProvider);
          // Wait a bit to show the indicator
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
              // 1. Header (HTML .nav style)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: AppTextStyles.greeting(colors.text),
                              children: [
                                TextSpan(text: greetText),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: colors.rHigh,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                themeState.phase.name.toUpperCase(),
                                style: AppTextStyles.micro(colors.textFaint),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.accentBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "READYNESS",
                                  style: AppTextStyles.micro(colors.accent)
                                      .copyWith(
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "${healthState.latestSnapshot?.heartRateCurrent?.toInt() ?? '--'} BPM",
                                style: AppTextStyles.micro(colors.textFaint),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        themeState.isDark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        color: colors.textDim,
                        size: 20,
                      ),
                      onPressed: () =>
                          ref.read(themeProvider.notifier).toggleTheme(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
  
              // 5. Gita Quote
              const GitaQuoteWidget(),
              const SizedBox(height: 14),
             // const _MinimalDivider(),
  
              // 2. OmniBar (Dump your thoughts) — Softened edges
              OmniBar(
                controller: _controller,
                focusNode: _focusNode,
                onSubmitted: _onSubmitted,
                hintText: "What's the focus for today?",
                showMic: true,
                isProcessing: ref.watch(brainDumpProvider).isProcessing,
              ),
  
   const _MinimalDivider(),
              // 3. Live Context (Pills like HTML .live-strip)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: 8,
                ),
                child: Text("NOW", style: AppTextStyles.label(colors.textFaint)),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Row(
                  children: [
                    _buildContextPill(
                      icon: "👟",
                      value: (healthState.latestSnapshot?.stepsToday ?? 0) > 0
                          ? _formatSteps(healthState.latestSnapshot!.stepsToday!)
                          : null,
                      colors: colors,
                    ),
                    _buildContextPill(
                      icon: "❤️",
                      value: (healthState.latestSnapshot?.heartRateCurrent ?? 0) >
                              0
                          ? "${healthState.latestSnapshot!.heartRateCurrent!.toInt()}"
                          : null,
                      colors: colors,
                    ),
                    _buildContextPill(
                      icon: "🔥",
                      value: (healthState.latestSnapshot?.activeEnergyToday ?? 0) >
                              0
                          ? "${healthState.latestSnapshot!.activeEnergyToday!.toInt()} kcal"
                          : null,
                      colors: colors,
                    ),
                    if (isMusicVisible)
                      _MusicPill(
                        trackName: musicState.currentSong?.title ?? "Unknown",
                        state: musicStatus,
                        colors: colors,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
  
              // 4. Readiness Section
              ReadinessRow(snapshot: healthState.latestSnapshot),
  
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: 12,
                ),
                child: Text(
                  "Body recovered. Push with intention.",
                  style: AppTextStyles.serifBody(colors.textDim),
                ),
              ),
  
              const _MinimalDivider(),
              
              // 6. Life Path
              const LifePathWidget(),
  
              const _MinimalDivider(),
  
              // 7. Recent Notes (HTML .dump-wrap style)
              // 7. Recent Notes
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Text(
                  "RECENT",
                  style: AppTextStyles.label(
                    colors.textDim.withValues(alpha: 0.5),
                  ).copyWith(letterSpacing: 1.2),
                ),
              ),
              const SizedBox(height: 16),
              notesAsync.when(
                data: (notes) {
                  if (notes.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                      child: Text(
                        "No notes yet.",
                        style: AppTextStyles.body(colors.textFaint),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: IntrinsicHeight(
                      child: Stack(
                        children: [
                          // Vertical Spine
                          Positioned(
                            left: 7, // Center of the 1.5 width line relative to the 14 padding
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 1.5,
                              color: colors.spine.withValues(alpha: 0.15),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: notes.take(3).map((note) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: Container(
                                  key: ValueKey(note.id),
                                  padding: const EdgeInsets.only(left: 24), // Space from spine
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        note.content,
                                        style: AppTextStyles.bodyMed(colors.text).copyWith(
                                          height: 1.5,
                                          fontSize: 14,
                                        ),
                                      ),
                                      _buildNoteMetadata(note, colors),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: Text(
                    "Error loading notes.",
                    style: AppTextStyles.micro(colors.red),
                  ),
                ),
              ),
              const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final String icon;
  final String label;
  final CircadianColors colors;

  const _MetaTag({
    required this.icon,
    required this.label,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.label(colors.textDim).copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _MinimalDivider extends StatelessWidget {

  const _MinimalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: 32,
      ),
      color: AppColors.divider.withValues(alpha: 0.2),
    );
  }
}

class _ContextPill extends StatelessWidget {
  final String label;
  final String icon;
  final Color color;
  final Color borderColor;
  final double iconOpacity;

  const _ContextPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.borderColor,
    this.iconOpacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: iconOpacity,
            child: Text(icon, style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.label(
              color,
            ).copyWith(fontSize: 11, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}

class _MusicPill extends StatefulWidget {
  final String trackName;
  final MusicPlaybackState state;
  final CircadianColors colors;

  const _MusicPill({
    required this.trackName,
    required this.state,
    required this.colors,
  });

  @override
  State<_MusicPill> createState() => _MusicPillState();
}

class _MusicPillState extends State<_MusicPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
      lowerBound: 0.7,
      upperBound: 1.0,
    );
    if (widget.state == MusicPlaybackState.playing) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_MusicPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == MusicPlaybackState.playing) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = widget.state == MusicPlaybackState.playing;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => _ContextPill(
        icon: '🎵',
        label: widget.trackName,
        color: isPlaying ? widget.colors.accent : widget.colors.textDim,
        borderColor: isPlaying ? widget.colors.accentBorder : widget.colors.surfaceBorder,
        iconOpacity: isPlaying ? _pulse.value : 1.0,
      ),
    );
  }
}

