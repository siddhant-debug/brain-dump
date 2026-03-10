import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../health/controllers/health_sync_controller.dart';
import '../../../health/models/health_snapshot.dart';
import '../widgets/full_page_header.dart';
import '../widgets/health_widgets.dart';
import '../widgets/metric_card.dart';
import '../widgets/section_label.dart';

class HealthPage extends ConsumerWidget {
  const HealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          const SizedBox(height: 16),
          if (healthState.error != null) ErrorBanner(error: healthState.error!),
          if (healthState.isFetching && healthState.latestSnapshot == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (healthState.isAuthorized) ...[
            if (healthState.latestSnapshot != null) ...[
              _buildAllMetrics(healthState.latestSnapshot!),
              const SizedBox(height: 20),
              DebugPanel(snap: healthState.latestSnapshot!),
            ] else
              const EmptyState(),
          ] else
            const NotConnectedHint(),
        ],
      ),
    );
  }

  Widget _buildAllMetrics(HealthSnapshot snap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Heart'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MetricCard(
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
              child: MetricCard(
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
        HRVCard(snap: snap),
        const SizedBox(height: 20),
        const SectionLabel('Sleep'),
        const SizedBox(height: 10),
        SleepCard(sleep: snap.lastNightSleep),
        const SizedBox(height: 20),
        const SectionLabel('Activity'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                icon: Icons.directions_walk_rounded,
                color: Colors.orangeAccent,
                title: 'Steps Today',
                value: snap.stepsToday?.toString() ?? '--',
                unit: 'steps',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
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
          const SectionLabel('Body'),
          const SizedBox(height: 10),
          Row(
            children: [
              if (snap.weightKg != null)
                Expanded(
                  child: MetricCard(
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
                  child: MetricCard(
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
        WorkoutCard(workout: snap.lastWorkout),
      ],
    );
  }
}
