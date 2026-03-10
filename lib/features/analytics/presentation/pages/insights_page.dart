//import 'package:brain_dump/features/analytics/presentation/widgets/full_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../services/analytics_service.dart';
import '../widgets/consistency_card.dart';
import '../widgets/themes_card.dart';

class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(consistencyProvider);
        ref.invalidate(themesProvider);
        ref.invalidate(loopsProvider);
        ref.invalidate(pipelineProvider);
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: Colors.white,
      backgroundColor: AppColors.surfaceHigh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
        child: Column(
          children: [
            // FullPageHeader(
            //   icon: Icons.insights,
            //   title: 'Insights',
            //   accent: AppColors.accent,
            // ),
            const SizedBox(height: 16),
            const ConsistencyCard(),
            const SizedBox(height: 16),
            const ThemesCard(),
          ],
        ),
      ),
    );
  }
}
