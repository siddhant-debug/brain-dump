import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../controllers/music_sync_controller.dart';
import '../../services/music_service.dart';

/// A live-reactive bottom sheet: uses ConsumerWidget so it watches
/// musicSyncControllerProvider directly and re-renders on every state change.
class MusicVibeBottomSheet extends ConsumerWidget {
  const MusicVibeBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // LIVE watch — re-renders automatically when music state changes.
    // This fixes the auth dot and recent songs not updating inside the modal.
    final musicState = ref.watch(musicSyncControllerProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Music Vibe',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      (musicState.isAuthorized
                              ? AppColors.success
                              : AppColors.error)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: musicState.isAuthorized
                            ? AppColors.success
                            : AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      musicState.isAuthorized ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        color: musicState.isAuthorized
                            ? AppColors.success
                            : AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Manual refresh button for triggering state update
              IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                tooltip: 'Refresh',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: musicState.isAnalyzing
                    ? null
                    : () => ref
                          .read(musicSyncControllerProvider.notifier)
                          .refreshMusicContext(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _buildContent(musicState),
        ],
      ),
    );
  }

  Widget _buildContent(MusicContextState musicState) {
    if (musicState.isAnalyzing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Analyzing your current vibe...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (!musicState.isAuthorized) {
      return Text(
        'Apple Music is not connected. Connect in the settings or play a song to start tracking your music vibe.',
        style: TextStyle(color: AppColors.textSecondary, height: 1.5),
      );
    }

    // Show "play a song" message only if there are also no recent songs to fall back on
    if (!musicState.isPlaying || musicState.currentSong == null) {
      // If we have recent songs + a vibe from history, show that instead
      if (musicState.recentSongs.isNotEmpty ||
          musicState.analyzedVibe != null) {
        // Fall through to the main content below — render vibe from recent history
        return _buildVibeContent(null, musicState);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Play a song on Apple Music to see your current vibe analysis.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          if (musicState.error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'DEBUG:\n${musicState.error}',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      );
    }

    return _buildVibeContent(musicState.currentSong, musicState);
  }

  Widget _buildVibeContent(MusicItem? song, MusicContextState musicState) {
    final vibe = musicState.analyzedVibe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Now Playing (only when a song is actively playing)
        if (song != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.album_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Now Playing',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.title ?? 'Unknown Song',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        song.artistName ?? 'Unknown Artist',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Animated bars icon
                Icon(Icons.graphic_eq_rounded, color: AppColors.accent),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ] else if (musicState.recentSongs.isNotEmpty) ...[
          Text(
            'Based on your recent listening',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Vibe Analysis
        if (vibe != null) ...[
          Text(
            'Current Mood',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.subtleCardGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFA5B4FC), // Indigo-200
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      vibe.primaryTone,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  vibe.shortDescription,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          if (musicState.recentSongs.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Recent Context',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...musicState.recentSongs.take(5).map((recentSong) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        color: AppColors.textSecondary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recentSong.title ?? 'Unknown Song',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            recentSong.artistName ?? 'Unknown Artist',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ] else if (musicState.error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    musicState.error!,
                    style: TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
