import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.label(AppColors.textSecondary).copyWith(
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
