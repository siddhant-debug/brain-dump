import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_kit/music_kit.dart';
import 'package:flutter/foundation.dart';
import 'music_service_interface.dart';

class MusicItem {
  final String? title;
  final String? artistName;
  MusicItem({this.title, this.artistName});
}

class MusicService implements MusicServiceInterface {
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
      debugPrint('[MusicService] Raw playerState: $playerState');

      // Depending on the version of music_kit, playerState may contain playbackState or currentEntry
      // Let's use dynamic to extract safely
      final dynamic stateDynamic = playerState;
      final currentEntry = stateDynamic.currentEntry;

      debugPrint('[MusicService] currentEntry: $currentEntry');

      if (currentEntry != null && currentEntry.item != null) {
        final attributes = currentEntry.item.attributes;
        debugPrint('[MusicService] attributes: $attributes');
        return MusicItem(
          title: attributes?['name']?.toString() ?? 'Unknown',
          artistName: attributes?['artistName']?.toString() ?? 'Unknown',
        );
      } else {
        debugPrint('[MusicService] currentEntry or currentEntry.item is null');
      }
      return null;
    } catch (e) {
      debugPrint('[MusicService] Error getting current song: $e');
      return null;
    }
  }

  /// Temporary debug helper to fetch raw state
  Future<String> getRawPlayerState() async {
    try {
      final playerState = await _musicKit.musicPlayerState;
      final dynamic stateDynamic = playerState;
      final currentEntry = stateDynamic.currentEntry;
      return "Status: ${playerState.playbackStatus}\nEntry: $currentEntry\nAttrs: ${currentEntry?.item?.attributes}";
    } catch (e) {
      return "Raw State Error: $e";
    }
  }

  /// Check if music is currently playing
  Future<bool> isPlaying() async {
    try {
      final playerState = await _musicKit.musicPlayerState;
      final status = playerState.playbackStatus.toString().toLowerCase();
      debugPrint('[MusicService] isPlaying status: $status');
      return status.contains('playing');
    } catch (e) {
      debugPrint('[MusicService] Error in isPlaying: $e');
      return false;
    }
  }

  /// Stream of player state changes to trigger UI updates
  Stream<dynamic> get onPlayerStateChanged {
    debugPrint('[MusicService] Setting up onPlayerStateChanged listener');
    return _musicKit.onMusicPlayerStateChanged;
  }

  /// Fetches the user-specific Music-User-Token via MusicKit's two-step flow:
  ///   1. Get the Developer Token (signed JWT) from the native SDK.
  ///   2. Exchange it for the per-user Music-User-Token.
  /// Call this after authorization has been granted.
  Future<String?> getMusicUserToken() async {
    try {
      final developerToken = await _musicKit.requestDeveloperToken();
      debugPrint(
        '[MusicService] Developer token obtained, fetching user token...',
      );
      final userToken = await _musicKit.requestUserToken(developerToken);
      debugPrint(
        '[MusicService] Music-User-Token: ${userToken.isNotEmpty ? "obtained (${userToken.length} chars)" : "empty"}',
      );
      return userToken.isNotEmpty ? userToken : null;
    } catch (e) {
      debugPrint('[MusicService] Error fetching Music-User-Token: $e');
      return null;
    }
  }
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
