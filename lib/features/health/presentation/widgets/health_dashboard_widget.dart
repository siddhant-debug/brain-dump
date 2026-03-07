import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/theme/app_theme.dart';
import '../../controllers/health_sync_controller.dart';
import '../../models/health_snapshot.dart';

class HealthDashboardWidget extends ConsumerWidget {
  const HealthDashboardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthState = ref.watch(healthSyncControllerProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
            child: Row(
              children: [
                Icon(
                  Icons.health_and_safety_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Health Vibe',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                if (!healthState.isAuthorized)
                  _ConnectButton()
                else ...[
                  _ReadinessChip(healthState),
                  const SizedBox(width: 4),
                  _RefreshButton(healthState),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (healthState.error != null)
                    _ErrorBanner(healthState.error!),

                  if (healthState.isFetching &&
                      healthState.latestSnapshot == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllMetrics(HealthSnapshot snap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Heart & HRV row ──────────────────────────────────
        _SectionLabel('Heart'),
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

        // HRV full width — important for RAG readiness
        _HRVCard(snap),
        const SizedBox(height: 20),

        // ── Sleep ────────────────────────────────────────────
        _SectionLabel('Sleep'),
        const SizedBox(height: 10),
        _SleepCard(snap.lastNightSleep),
        const SizedBox(height: 20),

        // ── Activity row ─────────────────────────────────────
        _SectionLabel('Activity'),
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

        // ── Body ─────────────────────────────────────────────
        if (snap.weightKg != null || snap.heightCm != null) ...[
          _SectionLabel('Body'),
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

        // ── Activity ───────────────────────────────────────── (continued)
        _WorkoutCard(snap.lastWorkout),
      ],
    );
  }
}

// ── Section label ────────────────────────────────────────────────────────────

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

// ── Connect button ────────────────────────────────────────────────────────────

class _ConnectButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        backgroundColor: AppColors.accent.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      onPressed: () =>
          ref.read(healthSyncControllerProvider.notifier).requestPermission(),
      child: const Text(
        'Connect Apple Health',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

// ── Readiness chip ────────────────────────────────────────────────────────────

class _ReadinessChip extends StatelessWidget {
  final HealthContextState state;
  const _ReadinessChip(this.state);

  @override
  Widget build(BuildContext context) {
    final label = state.latestSnapshot?.readinessLabel ?? 'Syncing';
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Refresh button ────────────────────────────────────────────────────────────

class _RefreshButton extends ConsumerWidget {
  final HealthContextState state;
  const _RefreshButton(this.state);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: state.isFetching
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textSecondary,
              ),
            )
          : Icon(
              Icons.refresh_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
      onPressed: state.isFetching
          ? null
          : () => ref
                .read(healthSyncControllerProvider.notifier)
                .refreshHealthContext(),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      splashRadius: 20,
    );
  }
}

// ── HRV card (wide, important signal) ────────────────────────────────────────

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
          Icon(Icons.graphic_eq_rounded, color: Colors.purpleAccent, size: 22),
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

// ── Sleep card (wide, most important) ────────────────────────────────────────

class _SleepCard extends StatelessWidget {
  final SleepSummary? sleep;
  const _SleepCard(this.sleep);

  @override
  Widget build(BuildContext context) {
    if (sleep == null) {
      return _EmptyMetricCard(
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
              Icon(
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
              _SleepStage('Deep', sleep!.deepHours, Colors.indigoAccent),
              const SizedBox(width: 12),
              _SleepStage('REM', sleep!.remHours, Colors.purpleAccent),
              const SizedBox(width: 12),
              _SleepStage('Awake', sleep!.awakeHours, Colors.orangeAccent),
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
  const _SleepStage(this.label, this.hours, this.color);

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

// ── Workout card ──────────────────────────────────────────────────────────────

class _WorkoutCard extends StatelessWidget {
  final WorkoutSummary? workout;
  const _WorkoutCard(this.workout);

  @override
  Widget build(BuildContext context) {
    if (workout == null) {
      return _EmptyMetricCard(
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

// ── Generic metric card ───────────────────────────────────────────────────────

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

// ── Empty metric card (data not available) ────────────────────────────────────

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
          const SizedBox(height: 8),
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
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

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
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty / not connected states ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
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

class _NotConnectedHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'Tap "Connect Apple Health" to grant access\nand see your health data here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.6),
        ),
      ),
    );
  }
}

// ── Debug panel ───────────────────────────────────────────────────────────────

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
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(
                    Icons.bug_report_outlined,
                    size: 15,
                    color: Colors.white38,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'RAG Context (debug)',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Fetched ${timeago.format(widget.snap.fetchedAt)}',
                    style: const TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white24,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                widget.snap.toJson().toString(),
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'Courier',
                  fontSize: 9,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
