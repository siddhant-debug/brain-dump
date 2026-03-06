import 'package:flutter/foundation.dart';
import 'music_service_interface.dart';
import 'music_service.dart'; // for MusicItem

/// A deterministic fake [MusicServiceInterface] for iOS Simulator testing.
///
/// Since the iOS Simulator cannot access Apple Music or MusicKit,
/// this mock cycles through 5 hardcoded songs every 10 seconds,
/// simulating a real listening session without any native calls.
///
/// Activate via compile-time flag:
///   flutter run --dart-define=MOCK_MUSIC=true
class MockMusicService implements MusicServiceInterface {
  static const List<Map<String, String>> _songs = [
    {'title': 'Blinding Lights', 'artist': 'The Weeknd'},
    {'title': 'HUMBLE.', 'artist': 'Kendrick Lamar'},
    {'title': 'Shape of You', 'artist': 'Ed Sheeran'},
    {'title': 'Levitating', 'artist': 'Dua Lipa'},
    {'title': 'God\'s Plan', 'artist': 'Drake'},
  ];

  int _currentIndex = 0;
  DateTime _songStartTime = DateTime.now();

  /// Advance the song index if 10 seconds have passed since the current song started.
  void _maybeCycleSong() {
    final elapsed = DateTime.now().difference(_songStartTime);
    if (elapsed.inSeconds >= 10) {
      _currentIndex = (_currentIndex + 1) % _songs.length;
      _songStartTime = DateTime.now();
      debugPrint(
        '[MockMusicService] Song cycled → ${_songs[_currentIndex]['title']}',
      );
    }
  }

  bool _isAuthorized = false;

  @override
  Future<bool> checkAuthorization() async => _isAuthorized;

  @override
  Future<bool> requestAuthorization() async {
    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // Simulate UI delay
    _isAuthorized = true;
    return true;
  }

  @override
  Future<bool> isPlaying() async => _isAuthorized;

  @override
  Future<MusicItem?> getCurrentSong() async {
    if (!_isAuthorized) return null;
    _maybeCycleSong();
    final song = _songs[_currentIndex];
    debugPrint(
      '[MockMusicService] getCurrentSong → ${song['title']} by ${song['artist']}',
    );
    return MusicItem(title: song['title'], artistName: song['artist']);
  }

  @override
  Future<String> getRawPlayerState() async {
    if (!_isAuthorized) return 'MockStatus: unauthorized';
    _maybeCycleSong();
    final song = _songs[_currentIndex];
    return 'MockStatus: playing\nMockEntry: ${song['title']} by ${song['artist']}';
  }

  @override
  Future<String?> getMusicUserToken() async =>
      _isAuthorized ? 'mock-music-user-token' : null;
}
