import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/now_playing_info.dart';

/*
1 : MusicState is a simple data class that holds the current playing information
for both Apple Music and Spotify features.
*/
class MusicState {
  final NowPlayingInfo? applePlaying;
  final NowPlayingInfo? spotifyPlaying;

  MusicState({this.applePlaying, this.spotifyPlaying});
}

/*
2 : MusicNotifier manages the music-related state.
It currently defaults to mock data (The Weeknd) for demonstration.
*/
class MusicNotifier extends StateNotifier<MusicState> {
  MusicNotifier()
    : super(
        MusicState(
          applePlaying: const NowPlayingInfo(
            title: 'Starboy',
            artist: 'The Weeknd',
            albumArt: '',
          ),
          spotifyPlaying: const NowPlayingInfo(
            title: 'Blinding Lights',
            artist: 'The Weeknd',
            albumArt: '',
          ),
        ),
      );

  // Future: Add methods to update music playback info from APIs
}

/*
3 : musicProvider exposes the MusicNotifier to the rest of the application.
*/
final musicProvider = StateNotifierProvider<MusicNotifier, MusicState>((ref) {
  return MusicNotifier();
});
