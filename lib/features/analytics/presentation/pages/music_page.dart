import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../music/controllers/music_sync_controller.dart';
import '../../../music/services/music_service.dart';
import '../widgets/full_page_header.dart';
import '../widgets/music_widgets.dart';

class MusicPage extends ConsumerWidget {
  const MusicPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeProvider.select((t) => t.colors));
    final musicState = ref.watch(musicSyncControllerProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(musicSyncControllerProvider);
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
        child: Column(
          children: [
            FullPageHeader(
              icon: Icons.music_note_rounded,
              title: 'Music Vibe',
              accent: const Color(0xFFf472b6),
              trailing: MusicStatusChip(state: musicState),
            ),
            const SizedBox(height: 16),
            _buildMusicContent(musicState, ref, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicContent(MusicContextState musicState, WidgetRef ref, CircadianColors colors) {
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
                style: TextStyle(color: colors.textDim),
              ),
            ],
          ),
        ),
      );
    }

    if (!musicState.isAuthorized) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Apple Music is not connected. Connect in the settings to start tracking your music vibe.',
            style: TextStyle(color: colors.textDim, height: 1.5),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref
                .read(musicSyncControllerProvider.notifier)
                .requestPermission(),
            icon: const Icon(Icons.music_note_rounded),
            label: const Text('Connect Apple Music'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      );
    }

    if (!musicState.isPlaying || musicState.currentSong == null) {
      if (musicState.recentSongs.isNotEmpty) {
        return _buildVibeContent(null, musicState, colors);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Play a song on Apple Music to see your current vibe analysis.',
            style: TextStyle(color: colors.textDim, height: 1.5),
          ),
        ],
      );
    }

    return _buildVibeContent(musicState.currentSong, musicState, colors);
  }

  Widget _buildVibeContent(MusicItem? song, MusicContextState musicState, CircadianColors colors) {
    final vibe = musicState.analyzedVibe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (song != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  child: Container(
                    width: 56,
                    height: 56,
                    color: colors.surface,
                    child: Icon(
                      Icons.album_rounded,
                      color: colors.textDim,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NOW PLAYING',
                        style: AppTextStyles.label(colors.accent).copyWith(
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.title ?? 'Unknown Song',
                        style: AppTextStyles.bodyMed(colors.text).copyWith(
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        song.artistName ?? 'Unknown Artist',
                        style: AppTextStyles.caption(colors.textDim),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.graphic_eq_rounded, color: colors.accent, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ] else if (musicState.recentSongs.isNotEmpty) ...[
          Text(
            'Based on your recent listening',
            style: TextStyle(
              color: colors.textDim,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (vibe != null) ...[
          Text(
            'CURRENT MOOD',
            style: AppTextStyles.label(colors.textDim).copyWith(
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: colors.accent.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: colors.accent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      vibe.primaryTone,
                      style: AppTextStyles.bodyMed(colors.text),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  vibe.shortDescription,
                  style: AppTextStyles.serifBody(colors.textDim).copyWith(
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (musicState.recentSongs.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text(
              'RECENT CONTEXT',
              style: AppTextStyles.label(colors.textDim).copyWith(
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            ...musicState.recentSongs.take(5).map((recentSong) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.icon),
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        color: colors.textDim,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recentSong.title ?? 'Unknown Song',
                            style: AppTextStyles.bodyMed(colors.text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            recentSong.artistName ?? 'Unknown Artist',
                            style: AppTextStyles.caption(colors.textDim),
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
              color: colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: colors.red,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    musicState.error!,
                    style: TextStyle(
                      color: colors.red,
                      fontSize: 13,
                    ),
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
