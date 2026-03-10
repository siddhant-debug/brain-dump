import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../music/controllers/music_sync_controller.dart';

class MusicStatusChip extends StatelessWidget {
  final MusicContextState state;
  const MusicStatusChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final status = state.isAuthorized ? 'Connected' : 'Disconnected';
    final color = state.isAuthorized ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
