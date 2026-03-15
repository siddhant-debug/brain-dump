import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../health/controllers/health_sync_controller.dart';
import '../../../health/models/health_snapshot.dart';
import '../widgets/full_page_header.dart';
import '../widgets/health_widgets.dart';
import '../widgets/metric_card.dart';

class HealthPage extends ConsumerWidget {
  const HealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeProvider).colors;
    final healthState = ref.watch(healthSyncControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
      child: Column(
        children: [
          FullPageHeader(
            icon: Icons.health_and_safety_rounded,
            title: 'Health',
            accent: const Color(0xFF4ade80),
            trailing: HealthStatusChip(state: healthState),
          ),
          const SizedBox(height: 20),
          if (healthState.isFetching && healthState.latestSnapshot == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (healthState.isAuthorized) ...[
            if (healthState.latestSnapshot != null) ...[
              _buildAllMetrics(healthState.latestSnapshot!, colors),
              const SizedBox(height: 20),
              DebugPanel(snap: healthState.latestSnapshot!),
            ] else
              const EmptyState()
          ] else
            const NotConnectedHint(),
        ],
      ),
    );
  }

  Widget _buildAllMetrics(HealthSnapshot snap, CircadianColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetricCard(
          icon: Icons.monitor_heart_outlined,
          color: colors.red,
          title: 'Heart Rate',
          value: snap.heartRateCurrent?.toStringAsFixed(0) ?? '--',
          unit: 'bpm',
          subtitle: snap.heartRateCurrent != null ? 'Last reading' : 'No data',
        ),
        const SizedBox(height: 12),
        MetricCard(
          icon: Icons.favorite_border_rounded,
          color: colors.accent,
          title: 'Resting HR',
          value: snap.restingHeartRate?.toStringAsFixed(0) ?? '--',
          unit: 'bpm',
          subtitle: 'Daily average',
        ),
        const SizedBox(height: 20),
        HRVCard(snap: snap),
        const SizedBox(height: 12),
        SleepCard(sleep: snap.lastNightSleep),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Activity'),
        MetricCard(
          icon: Icons.local_fire_department_rounded,
          color: Colors.deepOrangeAccent,
          title: 'Active Energy',
          value: snap.activeEnergyToday?.toStringAsFixed(0) ?? '--',
          unit: 'kcal',
        ),
        const SizedBox(height: 12),
        MetricCard(
          icon: Icons.directions_run_rounded,
          color: Colors.blueAccent,
          title: 'Steps',
          value: snap.stepsToday?.toString() ?? '--',
          unit: 'steps',
          subtitle: 'Today',
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Last Workout'),
        if (snap.lastWorkout == null)
          const EmptyMetricCard(
            title: 'No Workouts',
            icon: Icons.fitness_center_rounded,
            color: Colors.orangeAccent,
          )
        else
          MetricCard(
            icon: Icons.fitness_center_rounded,
            color: Colors.orangeAccent,
            title: snap.lastWorkout!.type,
            value: snap.lastWorkout!.durationMinutes.toStringAsFixed(0),
            unit: 'min',
            subtitle: snap.lastWorkout!.calories != null 
                ? '${snap.lastWorkout!.calories!.toStringAsFixed(0)} kcal'
                : 'Last workout',
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class SectionHeader extends ConsumerWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeProvider).colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: colors.textDim,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
