import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/analytics_models.dart';
import '../../services/analytics_service.dart';
import 'card_shell.dart';

class ConsistencyCard extends ConsumerWidget {
  const ConsistencyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(consistencyProvider);
    return state.when(
      loading: () => loadingCard('Consistency'),
      error: (e, _) =>
          errorCard('Consistency', 'Could not load consistency data'),
      data: (data) => ConsistencyContent(data: data),
    );
  }
}

class ConsistencyContent extends StatelessWidget {
  final ConsistencyData data;
  const ConsistencyContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return CardShell(
      title: 'Consistency',
      subtitle: 'last 30 days',
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
          HeatmapRow(heatmap: data.heatmap),
        ],
      ),
    );
  }
}

class HeatmapRow extends StatelessWidget {
  final List<HeatmapDay> heatmap;
  const HeatmapRow({super.key, required this.heatmap});

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
