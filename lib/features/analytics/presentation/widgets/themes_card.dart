import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/analytics_models.dart';
import '../../services/analytics_service.dart';
import 'card_shell.dart';

class ThemesCard extends ConsumerWidget {
  const ThemesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(themesProvider);
    return state.when(
      loading: () => loadingCard('What you think about'),
      error: (e, _) =>
          errorCard('What you think about', 'Could not load theme data'),
      data: (data) => ThemesContent(data: data),
    );
  }
}

class ThemesContent extends StatelessWidget {
  final ThemesData data;
  const ThemesContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.themes.isEmpty) {
      return CardShell(
        title: 'What you think about',
        subtitle:
            'last ${data.windowDays} days — ${data.totalNotesAnalyzed} notes',
        child: Text(
          'Not enough notes to identify themes yet.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      );
    }

    return CardShell(
      title: 'What you think about',
      subtitle:
          'last ${data.windowDays} days — ${data.totalNotesAnalyzed} notes',
      child: Column(
        children: data.themes.take(6).map((theme) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      theme.name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${theme.pct}%',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Container(
                          height: 6,
                          width: constraints.maxWidth,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHighlight.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Container(
                          height: 6,
                          width:
                              constraints.maxWidth *
                              (theme.pct / 100).clamp(0, 1),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
