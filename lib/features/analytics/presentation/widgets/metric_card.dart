import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/app_theme.dart';

class MetricCard extends ConsumerWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String unit;
  final String? subtitle;
  final double? progress; // 0.0 to 1.0

  const MetricCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.unit,
    this.subtitle,
    this.progress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeProvider.select((t) => t.colors));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: AppTextStyles.label(colors.textDim).copyWith(
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: AppTextStyles.bodyMed(colors.text).copyWith(
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: AppTextStyles.caption(colors.textDim),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (progress != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: AppTextStyles.caption(colors.textDim).copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
