import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../health/controllers/health_sync_controller.dart';
import '../../../health/models/health_snapshot.dart';
import 'metric_card.dart';

class HealthStatusChip extends ConsumerWidget {
  final HealthContextState state;
  const HealthStatusChip({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeProvider.select((t) => t.colors));
    if (!state.isAuthorized) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Disconnected',
          style: TextStyle(color: colors.red, fontSize: 11),
        ),
      );
    }
    final label = state.latestSnapshot?.readinessLabel ?? 'SYNCING';
    final color = switch (label) {
      'HIGH' => Colors.greenAccent,
      'MODERATE' => Colors.orangeAccent,
      'LOW' => colors.red,
      _ => colors.textDim,
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

class ErrorBanner extends ConsumerWidget {
  final String error;
  const ErrorBanner({super.key, required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeProvider.select((t) => t.colors));
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colors.red,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: colors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class HRVCard extends ConsumerWidget {
  final HealthSnapshot snap;
  const HRVCard({super.key, required this.snap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeProvider.select((t) => t.colors));
    final current = snap.hrvCurrent;
    final avg = snap.hrvAvg7d;
    final hasData = current != null;

    Color trendColor = colors.textDim;
    String trendLabel = '';
    if (current != null && avg != null) {
      if (current >= avg) {
        trendColor = Colors.greenAccent;
        trendLabel = '↑ Above 7d avg';
      } else if (current >= avg * 0.85) {
        trendColor = Colors.orangeAccent;
        trendLabel = '~ Near 7d avg';
      } else {
        trendColor = colors.red;
        trendLabel = '↓ Below 7d avg';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'HRV'.toUpperCase(),
                style: AppTextStyles.label(colors.textDim).copyWith(
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                hasData ? current.toStringAsFixed(1) : '--',
                style: AppTextStyles.bodyMed(colors.text).copyWith(
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'ms',
                style: AppTextStyles.caption(colors.textDim),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (avg != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: (current ?? 0) / (avg * 1.5).clamp(1, 200),
                backgroundColor: colors.accent.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                minHeight: 4,
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (avg != null)
                Text(
                  '7d avg: ${avg.toStringAsFixed(1)} ms',
                  style: AppTextStyles.caption(colors.textDim),
                ),
              const Spacer(),
              if (trendLabel.isNotEmpty)
                Text(
                  trendLabel,
                  style: AppTextStyles.caption(trendColor).copyWith(
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

class SleepCard extends ConsumerWidget {
  final SleepSummary? sleep;
  const SleepCard({super.key, this.sleep});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeProvider.select((t) => t.colors));
    if (sleep == null) {
      return const EmptyMetricCard(
        icon: Icons.nights_stay_rounded,
        color: Colors.indigoAccent,
        title: 'Sleep',
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SLEEP'.toUpperCase(),
                style: AppTextStyles.label(colors.textDim).copyWith(
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                sleep!.totalHours.toStringAsFixed(1),
                style: AppTextStyles.bodyMed(colors.text).copyWith(
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'hrs',
                style: AppTextStyles.caption(colors.textDim),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 4,
              child: Row(
                children: [
                  Expanded(
                    flex: (sleep!.deepHours * 10).toInt(),
                    child: Container(color: Colors.indigoAccent),
                  ),
                  Expanded(
                    flex: (sleep!.remHours * 10).toInt(),
                    child: Container(color: colors.accent),
                  ),
                  Expanded(
                    flex: (sleep!.awakeHours * 10).toInt(),
                    child: Container(color: Colors.orangeAccent),
                  ),
                  Expanded(
                    flex: ((sleep!.totalHours - sleep!.deepHours - sleep!.remHours - sleep!.awakeHours).clamp(0, 24) * 10).toInt(),
                    child: Container(color: colors.textDim.withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              SleepStage(
                label: 'Deep',
                hours: sleep!.deepHours,
                color: Colors.indigoAccent,
              ),
              SleepStage(
                label: 'REM',
                hours: sleep!.remHours,
                color: colors.accent,
              ),
              SleepStage(
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

class SleepStage extends ConsumerWidget {
  final String label;
  final double hours;
  final Color color;
  const SleepStage({
    super.key,
    required this.label,
    required this.hours,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeProvider.select((t) => t.colors));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ${hours.toStringAsFixed(1)}h',
          style: AppTextStyles.caption(colors.textDim),
        ),
      ],
    );
  }
}

class WorkoutCard extends StatelessWidget {
  final WorkoutSummary? workout;
  const WorkoutCard({super.key, this.workout});

  @override
  Widget build(BuildContext context) {
    if (workout == null) {
      return const EmptyMetricCard(
        icon: Icons.fitness_center_rounded,
        color: Colors.lightGreenAccent,
        title: 'Last Workout',
      );
    }
    return MetricCard(
      icon: Icons.fitness_center_rounded,
      color: Colors.lightGreenAccent,
      title: 'LAST WORKOUT',
      value: workout!.durationMinutes.toStringAsFixed(0),
      unit: 'min',
      subtitle: workout!.calories != null
          ? '${workout!.type} · ${workout!.calories!.toStringAsFixed(0)} kcal'
          : workout!.type,
    );
  }
}

class EmptyMetricCard extends ConsumerWidget {
  final IconData icon;
  final Color color;
  final String title;
  const EmptyMetricCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeProvider.select((t) => t.colors));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.surfaceBorder.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color.withValues(alpha: 0.3), size: 16),
              const SizedBox(width: 6),
              Text(
                'No data',
                style: TextStyle(
                  color: colors.textDim.withValues(alpha: 0.5),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: colors.textDim.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends ConsumerWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeProvider.select((t) => t.colors));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'No health data yet — try refreshing.',
          style: TextStyle(color: colors.textDim),
        ),
      ),
    );
  }
}

class NotConnectedHint extends ConsumerWidget {
  const NotConnectedHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeProvider.select((t) => t.colors));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Text(
              'Tap "Connect Apple Health" to grant access\nand see your health data here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textDim, height: 1.6),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref
                  .read(healthSyncControllerProvider.notifier)
                  .requestPermission(),
              icon: const Icon(Icons.health_and_safety_rounded),
              label: const Text('Connect Apple Health'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
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

class DebugPanel extends ConsumerStatefulWidget {
  final HealthSnapshot snap;
  const DebugPanel({super.key, required this.snap});

  @override
  ConsumerState<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends ConsumerState<DebugPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeProvider.select((t) => t.colors));
    return Container(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Text(
              'RAG Debug Data',
              style: TextStyle(color: colors.textDim, fontSize: 11),
            ),
            trailing: Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: colors.textDim,
              size: 16,
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                widget.snap.toRagContext(),
                style: TextStyle(
                  color: colors.textDim.withValues(alpha: 0.5),
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
