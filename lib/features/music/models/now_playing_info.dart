/*
1 : NowPlayingInfo is a model representing the track details currently playing.
It includes the song title, artist name, and a URL or path to the album artwork.
*/
class NowPlayingInfo {
  final String title;
  final String artist;
  final String albumArt;

  const NowPlayingInfo({
    required this.title,
    required this.artist,
    required this.albumArt,
  });
}
