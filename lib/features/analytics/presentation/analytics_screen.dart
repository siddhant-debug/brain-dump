import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../../../core/widgets/persistent_header.dart';
import '../services/analytics_service.dart';
import '../models/analytics_models.dart';
import '../widgets/pipeline_hint_widget.dart';
import '../widgets/pipeline_sheet.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                    backgroundColor: const Color(0xFF111111),
                    child: SingleChildScrollView(
                      physics:
                          const AlwaysScrollableScrollPhysics(), // Important for RefreshIndicator
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
                      child: Column(
                        children: const [
                          _ConsistencyCard(),
                          SizedBox(height: 16),
                          _ThemesCard(),
                          SizedBox(height: 16),
                          _LoopsCard(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Pipeline hint tab (always visible, left edge) ────────────
            PipelineHintWidget(onTap: () => showPipelineSheet(context)),
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

  const _Card({required this.title, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
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
      child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 1.5),
    ),
  ),
);

Widget _errorCard(String title, String msg) => _Card(
  title: title,
  child: Text(msg, style: const TextStyle(color: Colors.white38, fontSize: 13)),
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
      loading: () => _loadingCard('🔥 Consistency'),
      error: (e, _) =>
          _errorCard('🔥 Consistency', 'Could not load consistency data'),
      data: (data) => _ConsistencyContent(data: data),
    );
  }
}

class _ConsistencyContent extends StatelessWidget {
  final ConsistencyData data;
  const _ConsistencyContent({required this.data});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: '🔥 Consistency',
      subtitle: 'last 30 days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Big streak number
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${data.currentStreak}',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 52,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'days streak',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Best: ${data.longestStreak} days  ·  ${data.activeDaysLast30}/30 days active  ·  ${data.totalNotes} total notes',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 20),
          // Heatmap — 30 dots in a row
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
      spacing: 4,
      runSpacing: 4,
      children: heatmap.map((day) {
        final intensity = max == 0 ? 0.0 : day.count / max;
        final color = day.count == 0
            ? Colors.white.withValues(alpha: 0.07)
            : const Color.fromARGB(255, 61, 224, 36).withValues(alpha: 0.15 + intensity * 0.75);

        return Tooltip(
          message: '${day.date}: ${day.count} note${day.count == 1 ? '' : 's'}',
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
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
      loading: () => _loadingCard('🧠 What you think about'),
      error: (e, _) =>
          _errorCard('🧠 What you think about', 'Could not load theme data'),
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
        title: '🧠 What you think about',
        subtitle:
            'last ${data.windowDays} days — ${data.totalNotesAnalyzed} notes',
        child: const Text(
          'Not enough notes to identify themes yet.',
          style: TextStyle(color: Colors.white38, fontSize: 14),
        ),
      );
    }

    return _Card(
      title: '🧠 What you think about',
      subtitle:
          'last ${data.windowDays} days — ${data.totalNotesAnalyzed} notes',
      child: Column(
        children: data.themes.take(6).map((theme) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      theme.name,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${theme.pct}%',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Progress bar
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Container(
                          height: 4,
                          width: constraints.maxWidth,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Container(
                          height: 4,
                          width:
                              constraints.maxWidth *
                              (theme.pct / 100).clamp(0, 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(2),
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
// 3. LOOPS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _LoopsCard extends ConsumerWidget {
  const _LoopsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loopsProvider);
    return state.when(
      loading: () => _loadingCard('🔁 Recurring Loops'),
      error: (e, _) =>
          _errorCard('🔁 Recurring Loops', 'Could not scan for loops'),
      data: (data) => _LoopsContent(data: data),
    );
  }
}

class _LoopsContent extends StatelessWidget {
  final LoopsData data;
  const _LoopsContent({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.loops.isEmpty) {
      return _Card(
        title: '🔁 Recurring Loops',
        subtitle: 'scanned ${data.notesScanned} recent notes',
        child: const Text(
          'No recurring patterns found. Keep writing — loops surface over time.',
          style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.5),
        ),
      );
    }

    return _Card(
      title: '🔁 Recurring Loops',
      subtitle:
          '${data.loops.length} pattern${data.loops.length == 1 ? '' : 's'} found',
      child: Column(
        children: data.loops.map((loop) => _LoopTile(loop: loop)).toList(),
      ),
    );
  }
}

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
        return Colors.redAccent.withValues(alpha: 0.8);
      case 'medium':
        return Colors.orange.withValues(alpha: 0.8);
      default:
        return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loop = widget.loop;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _severityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _severityColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${loop.occurrences}×',
                    style: TextStyle(
                      color: _severityColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loop.themeGuess,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white24,
                  size: 18,
                ),
              ],
            ),
          ),

          // Date range
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 44),
            child: Text(
              '${loop.firstSeen} → ${loop.lastSeen}',
              style: const TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ),

          // Expanded: note previews + path forward
          if (_expanded) ...[
            const SizedBox(height: 12),
            // Note previews
            ...loop.notes.map(
              (n) => Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${n.date}  ',
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 11,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        n.preview,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Path forward
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _severityColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _severityColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '→  ',
                    style: TextStyle(color: _severityColor, fontSize: 13),
                  ),
                  Expanded(
                    child: Text(
                      loop.pathForward,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.45,
                      ),
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
