import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../services/analytics_service.dart';
import '../widgets/full_page_header.dart';
import '../widgets/full_page_error.dart';
import '../widgets/loop_tile.dart';

class LoopsPage extends ConsumerWidget {
  const LoopsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loopsProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const FullPageError(message: 'Could not load loops'),
      data: (data) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FullPageHeader(
              icon: Icons.all_inclusive_rounded,
              title: 'Recurring Loops',
              accent: const Color(0xFF60a5fa),
              trailing: Text(
                '${data.notesScanned} notes',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),
            if (data.loops.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Text(
                  'No recurring patterns found. Keep writing — loops surface over time.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...data.loops.map((loop) => LoopTile(loop: loop)),
          ],
        ),
      ),
    );
  }
}
