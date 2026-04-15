import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';
import '../features/health/controllers/health_sync_controller.dart';
import '../features/music/controllers/music_sync_controller.dart';
import '../features/vault/services/file_service.dart';
import '../features/brain_dump/providers/brain_dump_provider.dart';
import '../features/brain_dump/services/location_service.dart';

final locationNameProvider = FutureProvider<String?>((ref) async {
  final service = ref.read(locationServiceProvider);
  try {
    final ctx = await service.getCurrentLocationContext();
    if (ctx != null) {
      return ctx['city'] as String? ?? ctx['location_type'] as String?;
    }
  } catch (_) {
    // Ignore errors to not break ContextBar
  }
  return null;
});

class ContextBar extends ConsumerWidget {
  const ContextBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final colors = themeState.colors;
    final healthState = ref.watch(healthSyncControllerProvider);
    final musicState = ref.watch(musicSyncControllerProvider);
    final filesAsync = ref.watch(filesProvider);
    final brainDumpState = ref.watch(brainDumpProvider);

    final readiness = healthState.latestSnapshot;
    final isMusicPlaying =
        musicState.isPlaying && musicState.currentSong != null;
    final memoryCount = filesAsync.value?.length ?? 0;
    final isReflecting = brainDumpState.isReflecting;
    final locationAsync = ref.watch(locationNameProvider);
    final locationName = locationAsync.value;
    
    String timeAgo(DateTime? dt) {
      if (dt == null) return "never";
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return "just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      return "${diff.inHours}h ago";
    }

    final lastSyncedAt = healthState.latestSnapshot?.fetchedAt;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.surfaceBorder.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "CONTEXT",
                  style: AppTextStyles.label(
                    colors.textDim.withValues(alpha: 0.5),
                  ).copyWith(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                if (readiness != null)
                  _ContextItem(
                    label: "${readiness.readinessLabel} readiness",
                    dotColor: _getReadinessColor(readiness, colors),
                    colors: colors,
                  ),
                if (isMusicPlaying) ...[
                  _divider(colors),
                  _ContextItem(
                    label: "${musicState.currentSong?.title} playing",
                    dotColor: const Color(0xFFA78BFA),
                    colors: colors,
                  ),
                ],
                if (locationName != null) ...[
                  _divider(colors),
                  _ContextItem(
                    label: locationName,
                    dotColor: const Color(0xFF60A5FA),
                    colors: colors,
                  ),
                ],
                if (memoryCount > 0) ...[
                  _divider(colors),
                  _ContextItem(
                    label: "$memoryCount memories",
                    dotColor: const Color(0xFF6EE7B7),
                    colors: colors,
                  ),
                ],
                if (isReflecting) ...[
                  _divider(colors),
                  _ContextItem(
                    label: "reflecting",
                    dotColor: colors.accent,
                    colors: colors,
                  ),
                ],
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    "synced ${timeAgo(lastSyncedAt)}",
                    style: AppTextStyles.micro(colors.textFaint),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider(CircadianColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        "·",
        style: TextStyle(
          color: colors.textDim.withValues(alpha: 0.3),
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getReadinessColor(dynamic snapshot, CircadianColors colors) {
    final label = snapshot.readinessLabel;
    return switch (label) {
      'HIGH' => colors.green,
      'MODERATE' => colors.accent,
      'LOW' => colors.red,
      _ => colors.textDim,
    };
  }
}

class _ContextItem extends StatelessWidget {
  final String label;
  final Color dotColor;
  final CircadianColors colors;

  const _ContextItem({
    required this.label,
    required this.dotColor,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: dotColor.withValues(alpha: 0.3),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.label(
            colors.textDim,
          ).copyWith(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
