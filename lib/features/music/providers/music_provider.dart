import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/now_playing_info.dart';

class MusicState {
  final NowPlayingInfo? applePlaying;
  final NowPlayingInfo? spotifyPlaying;

  MusicState({this.applePlaying, this.spotifyPlaying});
}

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

final musicProvider = StateNotifierProvider<MusicNotifier, MusicState>((ref) {
  return MusicNotifier();
});
