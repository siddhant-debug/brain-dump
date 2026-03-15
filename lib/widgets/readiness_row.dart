import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/theme_provider.dart';
import '../features/health/models/health_snapshot.dart';

class ReadinessRow extends ConsumerWidget {
  final HealthSnapshot? snapshot;

  const ReadinessRow({super.key, this.snapshot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final colors = themeState.colors;
    if (snapshot == null) {
      return _buildSyncingState(colors);
    }

    final label = snapshot!.readinessLabel;
    
    // Calculate score ratio
    // Based on HealthSnapshot.readinessLabel logic: ratio = score / (factors * 2)
    final scoreData = _calculateScore(snapshot!);
    final score = (scoreData.ratio * 100).toInt();

    final color = switch (label) {
      'HIGH' => colors.green,
      'MODERATE' => colors.accent,
      'LOW' => colors.red,
      _ => colors.textDim,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Score Block
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    "$score",
                    style: AppTextStyles.greeting(colors.text).copyWith(
                      fontSize: 48,
                      fontWeight: FontWeight.w200,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "%",
                    style: AppTextStyles.label(colors.textDim).copyWith(
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Text(
                label,
                style: AppTextStyles.label(color).copyWith(
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 48),
          // Bars Block
          Expanded(
            child: Column(
              children: [
                _buildBar("SLEEP", _getSleepLevel(snapshot!), colors),
                const SizedBox(height: 12),
                _buildBar("HRV", _getHRVLevel(snapshot!), colors),
                const SizedBox(height: 12),
                _buildBar("RECOVERY", scoreData.ratio, colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncingState(CircadianColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              "--",
              style: AppTextStyles.greeting(colors.textDim).copyWith(
                fontSize: 48,
                fontWeight: FontWeight.w200,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SYNCING QUALITY DATA",
                  style: AppTextStyles.label(colors.textDim).copyWith(
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  backgroundColor: colors.surfaceBorder.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(colors.accent.withValues(alpha: 0.3)),
                  minHeight: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String label, double level, CircadianColors colors) {
    final color = level > 0.7 
        ? colors.green 
        : level > 0.4 
            ? colors.accent 
            : colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.label(colors.textDim.withValues(alpha: 0.5)).copyWith(
                fontSize: 8,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              "${(level * 100).toInt()}%",
              style: AppTextStyles.label(colors.textDim).copyWith(
                fontSize: 8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.surfaceBorder.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            FractionallySizedBox(
              widthFactor: level.clamp(0.01, 1.0),
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  double _getSleepLevel(HealthSnapshot snap) {
    if (snap.lastNightSleep == null) return 0.0;
    return (snap.lastNightSleep!.totalHours / 8.0).clamp(0.0, 1.0);
  }

  double _getHRVLevel(HealthSnapshot snap) {
    if (snap.hrvCurrent == null || snap.hrvAvg7d == null || snap.hrvAvg7d == 0) return 0.0;
    // Normalized around 1.0 being "on average"
    return (snap.hrvCurrent! / snap.hrvAvg7d!).clamp(0.0, 1.2) / 1.2;
  }

  _ScoreData _calculateScore(HealthSnapshot snap) {
    int score = 0;
    int factors = 0;

    if (snap.restingHeartRate != null) {
      factors++;
      if (snap.restingHeartRate! < 65) {
        score += 2;
      } else if (snap.restingHeartRate! < 75) {
        score += 1;
      }
    }
    if (snap.stepsToday != null) {
      factors++;
      if (snap.stepsToday! >= 8000) {
        score += 2;
      } else if (snap.stepsToday! >= 4000) {
        score += 1;
      }
    }
    if (snap.activeEnergyToday != null) {
      factors++;
      if (snap.activeEnergyToday! >= 500) {
        score += 2;
      } else if (snap.activeEnergyToday! >= 250) {
        score += 1;
      }
    }
    if (snap.lastNightSleep != null) {
      factors++;
      if (snap.lastNightSleep!.totalHours >= 7.5) {
        score += 2;
      } else if (snap.lastNightSleep!.totalHours >= 6.0) {
        score += 1;
      }
    }
    if (snap.hrvCurrent != null && snap.hrvAvg7d != null) {
      factors++;
      if (snap.hrvCurrent! >= snap.hrvAvg7d!) {
        score += 2;
      } else if (snap.hrvCurrent! >= snap.hrvAvg7d! * 0.85) {
        score += 1;
      }
    }

    if (factors == 0) return const _ScoreData(0.0);
    return _ScoreData(score / (factors * 2));
  }
}

class _ScoreData {
  final double ratio;
  const _ScoreData(this.ratio);
}
