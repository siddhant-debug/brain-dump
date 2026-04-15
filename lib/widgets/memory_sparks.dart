import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/theme_provider.dart';

class MemorySparks extends ConsumerWidget {
  final int count;
  final List<String> domains;
  final List<Color> customColors;
  final String? labelOverride;

  const MemorySparks({
    super.key,
    required this.count,
    this.domains = const [],
    this.customColors = const [],
    this.labelOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final colors = themeState.colors;
    if (count == 0) return const SizedBox.shrink();

    // Map domains to colors or use default sequence
    final List<Color> sparkColors = [];
    if (customColors.isNotEmpty) {
      sparkColors.addAll(customColors);
    } else if (domains.isNotEmpty) {
      for (final domain in domains) {
        if (domain.toLowerCase().contains('health')) {
          sparkColors.add(colors.green);
        } else if (domain.toLowerCase().contains('music')) {
          sparkColors.add(colors.music);
        } else if (domain.toLowerCase().contains('location')) {
          sparkColors.add(colors.location);
        } else {
          sparkColors.add(colors.accent);
        }
      }
    }
    
    // Fill remaining if needed
    while (sparkColors.length < (count > 4 ? 4 : count)) {
      sparkColors.add(colors.accent);
    }

    // Varied widths sequence for premium feel
    const widths = [12.0, 20.0, 16.0, 24.0];

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          // Sparks
          ...List.generate(
            (count > 4 ? 4 : count),
            (index) {
              final color = sparkColors[index % sparkColors.length];
              final width = widths[index % widths.length];
              return Container(
                width: width,
                height: 3,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          Text(
            labelOverride ?? "$count memories connected",
            style: AppTextStyles.label(colors.textDim.withValues(alpha: 0.7)).copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
