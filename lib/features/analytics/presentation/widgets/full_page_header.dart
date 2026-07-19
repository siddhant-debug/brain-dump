import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/app_theme.dart';

class FullPageHeader extends ConsumerWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final Widget? trailing;

  const FullPageHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeProvider.select((t) => t.colors));
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(icon, color: accent, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: AppTextStyles.greeting(colors.text).copyWith(
              fontSize: 24,
              fontStyle: FontStyle.normal,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}
