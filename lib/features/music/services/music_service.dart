import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_kit/music_kit.dart';
import 'package:flutter/foundation.dart';
import 'music_service_interface.dart';

class MusicItem {
  final String? title;
  final String? artistName;
  MusicItem({this.title, this.artistName});
}

/// Real implementation of [MusicServiceInterface] backed by the MusicKit plugin.
///
/// Key facts about music_kit 1.3.0 (discovered from source):
///   • [MusicPlayerState] has NO song data — only playbackStatus/rate/mode.
///   • [MusicPlayerQueue.currentEntry] has title + subtitle (artist).
///   • playbackStatus always returns `stopped` for externally-controlled
///     Apple Music playback — so we derive isPlaying from currentEntry != null.
///   • The queue is pushed via the [onPlayerQueueChanged] stream;
///     we cache the last value so getCurrentSong() can be called at any time.
class MusicService implements MusicServiceInterface {
  static const _channel = MethodChannel('com.braindump.music');

  final MusicKit _musicKit;

  MusicService(this._musicKit);

  @override
  Future<bool> requestAuthorization() async {
    try {
      final status = await _musicKit.requestAuthorizationStatus();
      return status is MusicAuthorizationStatusAuthorized;
    } catch (e) {
      debugPrint('[MusicService] Error requesting authorization: $e');
      return false;
    }
  }

  @override
  Future<bool> checkAuthorization() async {
    try {
      final status = await _musicKit.authorizationStatus;
      return status is MusicAuthorizationStatusAuthorized;
    } catch (e) {
      debugPrint('[MusicService] Error checking authorization: $e');
      return false;
    }
  }

  @override
  Future<bool> isPlaying() async {
    try {
      final state = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getSystemMusicPlayerState',
      );
      final playing = state?['isPlaying'] == true;
      debugPrint('[MusicService] isPlaying (from SystemMusicPlayer): $playing');
      return playing;
    } catch (e) {
      debugPrint('[MusicService] Error in isPlaying: $e');
      return false;
    }
  }

  @override
  Future<MusicItem?> getCurrentSong() async {
    try {
      final state = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getSystemMusicPlayerState',
      );
      if (state != null && state['title'] != null) {
        final title = state['title'] as String;
        final artist = state['artist'] as String?;
        debugPrint(
          '[MusicService] getCurrentSong from SystemMusicPlayer: $title',
        );
        return MusicItem(title: title, artistName: artist);
      }
      debugPrint(
        '[MusicService] getCurrentSong: no current entry in SystemMusicPlayer queue',
      );
      return null;
    } catch (e) {
      debugPrint('[MusicService] Error getting current song: $e');
      return null;
    }
  }

  @override
  Future<String> getRawPlayerState() async {
    try {
      final state = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getSystemMusicPlayerState',
      );
      if (state != null) {
        return 'Status: ${state['rawStatus']}\nQueueEntry: ${state['title']} — ${state['artist']}';
      }
      return 'Status: unknown';
    } catch (e) {
      return 'Raw State Error: $e';
    }
  }

  /// Two-step MusicKit flow:
  ///   1. requestDeveloperToken() → signed JWT
  ///   2. requestUserToken(devToken) → per-user Music-User-Token
  @override
  Future<String?> getMusicUserToken() async {
    try {
      final developerToken = await _musicKit.requestDeveloperToken();
      debugPrint('[MusicService] Developer token obtained.');
      final userToken = await _musicKit.requestUserToken(developerToken);
      debugPrint(
        '[MusicService] Music-User-Token: '
        '${userToken.isNotEmpty ? "obtained (${userToken.length} chars)" : "empty"}',
      );
      return userToken.isNotEmpty ? userToken : null;
    } catch (e) {
      debugPrint('[MusicService] Error fetching Music-User-Token: $e');
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers (kept here so music_service_provider.dart can import musicKitProvider)
// ─────────────────────────────────────────────────────────────────────────────

final musicKitProvider = Provider<MusicKit>((_) => MusicKit());

/// Legacy provider — prefer [musicServiceInterfaceProvider] from
/// `providers/music_service_provider.dart` which respects the MOCK_MUSIC flag.
final musicServiceProvider = Provider<MusicService>((ref) {
  final kit = ref.watch(musicKitProvider);
  return MusicService(kit);
});
