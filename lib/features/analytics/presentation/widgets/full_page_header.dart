import 'package:flutter/material.dart';

class FullPageHeader extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row( 
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 12),
        Divider(color: accent.withValues(alpha: 0.3), height: 1, thickness: 1),
      ],
    );
  }
}
