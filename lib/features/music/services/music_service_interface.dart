import 'music_service.dart'; // brings MusicItem into scope

/// Abstract interface for the Apple Music service layer.
///
/// Two implementations:
///   • [MusicService]     — real MusicKit calls on device (TestFlight / App Store)
///   • [MockMusicService] — deterministic fake for iOS Simulator testing
abstract class MusicServiceInterface {
  /// Returns true if the user has granted Apple Music access.
  Future<bool> checkAuthorization();

  /// Prompts the user with the system permission dialog and returns true if granted.
  Future<bool> requestAuthorization();

  /// Returns true if music is currently playing.
  Future<bool> isPlaying();

  /// Returns the currently playing [MusicItem], or null if nothing is playing.
  Future<MusicItem?> getCurrentSong();

  /// Returns a raw player-state debug string (used in the error/debug overlay).
  Future<String> getRawPlayerState();

  /// Returns the per-user Music-User-Token needed for Apple Music API calls.
  ///
  /// Real:  requestDeveloperToken() → requestUserToken(devToken)
  /// Mock:  returns constant stub string
  Future<String?> getMusicUserToken();
}
