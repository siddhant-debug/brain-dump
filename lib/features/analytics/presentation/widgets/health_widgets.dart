import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../health/controllers/health_sync_controller.dart';
import '../../../health/models/health_snapshot.dart';
import 'metric_card.dart';

class HealthStatusChip extends StatelessWidget {
  final HealthContextState state;
  const HealthStatusChip({super.key, required this.state});

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

class ErrorBanner extends StatelessWidget {
  final String error;
  const ErrorBanner({super.key, required this.error});

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

class HRVCard extends StatelessWidget {
  final HealthSnapshot snap;
  const HRVCard({super.key, required this.snap});

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

class SleepCard extends StatelessWidget {
  final SleepSummary? sleep;
  const SleepCard({super.key, this.sleep});

  @override
  Widget build(BuildContext context) {
    if (sleep == null) {
      return const EmptyMetricCard(
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
              SleepStage(
                label: 'Deep',
                hours: sleep!.deepHours,
                color: Colors.indigoAccent,
              ),
              const SizedBox(width: 12),
              SleepStage(
                label: 'REM',
                hours: sleep!.remHours,
                color: Colors.purpleAccent,
              ),
              const SizedBox(width: 12),
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

class SleepStage extends StatelessWidget {
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
      title: 'Last Workout',
      value: workout!.durationMinutes.toStringAsFixed(0),
      unit: 'min',
      subtitle: workout!.calories != null
          ? '${workout!.type} · ${workout!.calories!.toStringAsFixed(0)} kcal'
          : workout!.type,
    );
  }
}

class EmptyMetricCard extends StatelessWidget {
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

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'No health data yet — try refreshing.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class NotConnectedHint extends ConsumerWidget {
  const NotConnectedHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
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

class DebugPanel extends StatefulWidget {
  final HealthSnapshot snap;
  const DebugPanel({super.key, required this.snap});

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
