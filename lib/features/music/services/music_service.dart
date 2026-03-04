import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_kit/music_kit.dart';
import 'package:flutter/foundation.dart';

class MusicItem {
  final String? title;
  final String? artistName;
  MusicItem({this.title, this.artistName});
}

class MusicService {
  final MusicKit _musicKit;

  MusicService(this._musicKit);

  /// Requests permission to access the user's Apple Music data.
  Future<bool> requestAuthorization() async {
    try {
      final status = await _musicKit.requestAuthorizationStatus();
      return status.toString().toLowerCase().contains('authorized');
    } catch (e) {
      debugPrint('[MusicService] Error requesting authorization: $e');
      return false;
    }
  }

  /// Checks if we already have authorization
  Future<bool> checkAuthorization() async {
    try {
      final status = await _musicKit.authorizationStatus;
      return status.toString().toLowerCase().contains('authorized');
    } catch (e) {
      debugPrint('[MusicService] Error checking authorization: $e');
      return false;
    }
  }

  /// Gets the currently playing song, if any.
  Future<MusicItem?> getCurrentSong() async {
    try {
      final playerState = await _musicKit.musicPlayerState;
      // Depending on the version of music_kit, playerState may contain playbackState or currentEntry
      // Let's use dynamic to extract safely
      final dynamic stateDynamic = playerState;
      final currentEntry = stateDynamic.currentEntry;

      if (currentEntry != null && currentEntry.item != null) {
        final attributes = currentEntry.item.attributes;
        return MusicItem(
          title: attributes?['name']?.toString() ?? 'Unknown',
          artistName: attributes?['artistName']?.toString() ?? 'Unknown',
        );
      }
      return null;
    } catch (e) {
      debugPrint('[MusicService] Error getting current song: $e');
      return null;
    }
  }

  /// Check if music is currently playing
  Future<bool> isPlaying() async {
    try {
      final playerState = await _musicKit.musicPlayerState;
      return playerState.playbackStatus.toString().toLowerCase().contains(
        'playing',
      );
    } catch (e) {
      return false;
    }
  }

  /// Stream of player state changes to trigger UI updates
  Stream<dynamic> get onPlayerStateChanged =>
      _musicKit.onMusicPlayerStateChanged;
}

// Global provider for the underlying MusicKit plugin instance
final musicKitProvider = Provider<MusicKit>((ref) {
  return MusicKit();
});

// Provider for our abstraction service
final musicServiceProvider = Provider<MusicService>((ref) {
  final kit = ref.watch(musicKitProvider);
  return MusicService(kit);
});
