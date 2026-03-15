import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/theme_provider.dart';
import '../core/theme/app_theme.dart';
import '../features/life_path/models/life_path.dart';
import '../features/life_path/providers/life_path_provider.dart';

class LifePathWidget extends ConsumerWidget {
  const LifePathWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final colors = theme.colors;
    final lifePathAsync = ref.watch(lifePathProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "LIFE PATH",
                style: AppTextStyles.label(colors.textDim.withValues(alpha: 0.5)).copyWith(
                  letterSpacing: 1.2,
                ),
              ),
              lifePathAsync.when(
                data: (items) => Text(
                  "${_calculateAlignment(items)}% ALIGNED",
                  style: AppTextStyles.label(colors.accent).copyWith(
                    fontSize: 10,
                  ),
                ),
                loading: () => const _SkeletonText(width: 60),
                error: (e, _) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          lifePathAsync.when(
            data: (items) {
              if (items.isEmpty) return _buildEmpty(colors);
              return ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _buildTimelineItem(
                    context,
                    colors,
                    items[index],
                    index == 0,
                    index == items.length - 1,
                  );
                },
              );
            },
            loading: () => Column(
              children: List.generate(3, (i) => _buildSkeletonItem(colors, i == 0, i == 2)),
            ),
            error: (e, _) => _buildError(colors, e.toString()),
          ),
        ],
      ),
    );
  }

  int _calculateAlignment(List<LifePathItem> items) {
    if (items.isEmpty) return 0;
    final positive = items.where((i) => !i.isNegative).length;
    return ((positive / items.length) * 100).toInt();
  }

  Widget _buildEmpty(CircadianColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Text(
              "No path yet.",
              style: AppTextStyles.body(colors.textFaint),
            ),
            const SizedBox(height: 8),
            Text(
              "Dump a thought to start your journey.",
              style: AppTextStyles.micro(colors.textDim),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(CircadianColors colors, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          "Error: $error",
          style: AppTextStyles.micro(colors.red),
        ),
      ),
    );
  }

  Widget _buildSkeletonItem(CircadianColors colors, bool isFirst, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    color: colors.spine.withValues(alpha: 0.1),
                  ),
                ),
                Positioned(
                  top: 14,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.spine.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 80,
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.surfaceBorder.withValues(alpha: 0.5), width: 0.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors.textFaint.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 180,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors.textFaint.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, CircadianColors colors, LifePathItem item, bool isFirst, bool isLast) {
    // Determine the indicator color (left strip)
    final indicatorColor = item.isNegative ? colors.red : (item.isGoal ? colors.green : colors.accent);
    
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line and dots
          SizedBox(
            width: 24,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Vertical Line
                Positioned(
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: colors.spine.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                // Dot
                Positioned(
                  top: 14,
                  child: Container(
                    width: isFirst ? 14 : 10,
                    height: isFirst ? 14 : 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFirst ? colors.accent : (colors.bgTop.computeLuminance() > 0.5 ? colors.text : Colors.white24),
                      border: isFirst ? null : Border.all(color: colors.bgTop, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.surfaceBorder, width: 0.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      // Thick Left Indicator
                      Container(
                        width: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                        decoration: BoxDecoration(
                          color: indicatorColor,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: AppTextStyles.bodyMed(colors.text).copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: item.isDimmed ? colors.textDim.withValues(alpha: 0.5) : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle,
                                style: AppTextStyles.body(colors.textDim).copyWith(
                                  fontSize: 12,
                                  color: item.isDimmed ? colors.textFaint : null,
                                ),
                              ),
                              if (item.tags.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: item.tags.map((tag) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: tag.color.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      tag.label,
                                      style: AppTextStyles.label(tag.color).copyWith(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonText extends StatelessWidget {
  final double width;
  const _SkeletonText({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
