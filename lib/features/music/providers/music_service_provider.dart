import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/music_service_interface.dart';
import '../services/music_service.dart';
import '../services/mock_music_service.dart';

/// Compile-time flag. Enable with:
///   flutter run --dart-define=MOCK_MUSIC=true
///
/// When true, [MockMusicService] is used instead of the real [MusicService].
/// This allows full music flow testing on the iOS Simulator (which has no MusicKit).
const bool kUseMockMusic = bool.fromEnvironment(
  'MOCK_MUSIC',
  defaultValue: false,
);

/// Single source of truth for the music service.
/// The controller and widgets should consume this — never instantiate directly.
final musicServiceInterfaceProvider = Provider<MusicServiceInterface>((ref) {
  if (kUseMockMusic) {
    return MockMusicService();
  }
  final kit = ref.watch(musicKitProvider);
  return MusicService(kit);
});
