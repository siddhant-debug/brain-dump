import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';
import '../services/music_service.dart';

/// Represents the analyzed Vibe returned from the backend
class MusicVibe {
  final String primaryTone;
  final String shortDescription;

  MusicVibe({required this.primaryTone, required this.shortDescription});

  factory MusicVibe.fromJson(Map<String, dynamic> json) {
    return MusicVibe(
      primaryTone: json['primary_tone'] as String? ?? 'Unknown',
      shortDescription: json['short_description'] as String? ?? '',
    );
  }
}

/// The state containing authorization status, current song, recent songs, and analyzed vibe.
class MusicContextState {
  final bool isAuthorized;
  final bool isPlaying;
  final MusicItem? currentSong;
  final List<MusicItem> recentSongs;
  final MusicVibe? analyzedVibe;
  final bool isAnalyzing;
  final String? error;

  MusicContextState({
    this.isAuthorized = false,
    this.isPlaying = false,
    this.currentSong,
    this.recentSongs = const [],
    this.analyzedVibe,
    this.isAnalyzing = false,
    this.error,
  });

  MusicContextState copyWith({
    bool? isAuthorized,
    bool? isPlaying,
    MusicItem? currentSong,
    List<MusicItem>? recentSongs,
    MusicVibe? analyzedVibe,
    bool? isAnalyzing,
    String? error,
    bool clearSong = false,
    bool clearVibe = false,
  }) {
    return MusicContextState(
      isAuthorized: isAuthorized ?? this.isAuthorized,
      isPlaying: isPlaying ?? this.isPlaying,
      currentSong: clearSong ? null : (currentSong ?? this.currentSong),
      recentSongs: recentSongs ?? this.recentSongs,
      analyzedVibe: clearVibe ? null : (analyzedVibe ?? this.analyzedVibe),
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      error: error,
    );
  }
}

class MusicSyncController extends StateNotifier<MusicContextState> {
  final MusicService _musicService;
  final FlutterSecureStorage _storage;

  MusicSyncController(this._musicService, this._storage)
    : super(MusicContextState()) {
    _init();
  }

  Future<void> _init() async {
    await _loadRecentSongs();

    final authStatus = await _musicService.checkAuthorization();
    state = state.copyWith(isAuthorized: authStatus);
    if (authStatus) {
      await refreshMusicContext();
    } else {
      await requestPermission();
    }

    if (state.isAuthorized) {
      _musicService.onPlayerStateChanged.listen((_) {
        refreshMusicContext();
      });
    }
  }

  Future<void> _loadRecentSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('recent_songs_history');
    if (jsonList != null && jsonList.isNotEmpty) {
      final songs = jsonList.map((str) {
        final Map<String, dynamic> data = jsonDecode(str);
        return MusicItem(title: data['title'], artistName: data['artistName']);
      }).toList();
      state = state.copyWith(recentSongs: songs);
    }
  }

  Future<void> _saveRecentSongs(List<MusicItem> songs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = songs
        .map((s) => jsonEncode({'title': s.title, 'artistName': s.artistName}))
        .toList();
    await prefs.setStringList('recent_songs_history', jsonList);
  }

  Future<void> requestPermission() async {
    final granted = await _musicService.requestAuthorization();
    state = state.copyWith(isAuthorized: granted);
    if (granted) {
      await refreshMusicContext();
      _musicService.onPlayerStateChanged.listen((_) {
        refreshMusicContext();
      });
    }
  }

  Future<void> refreshMusicContext() async {
    if (!state.isAuthorized) return;

    try {
      final isPlaying = await _musicService.isPlaying();
      final currentSong = await _musicService.getCurrentSong();

      // Track history if the song has changed
      List<MusicItem> currentRecent = List.from(state.recentSongs);
      if (currentSong != null &&
          (state.currentSong?.title != currentSong.title ||
              state.currentSong?.artistName != currentSong.artistName)) {
        // Only if we had a previous song, add it to history
        if (state.currentSong != null) {
          // Check if it's already the most recent to avoid double logging
          if (currentRecent.isEmpty ||
              (currentRecent.first.title != state.currentSong!.title)) {
            currentRecent.insert(0, state.currentSong!);
            if (currentRecent.length > 10) {
              currentRecent = currentRecent.take(10).toList();
            }
            await _saveRecentSongs(currentRecent);
          }
        }
      }

      final rawState = await _musicService.getRawPlayerState();

      state = state.copyWith(
        isPlaying: isPlaying,
        currentSong: currentSong,
        recentSongs: currentRecent,
        clearSong: currentSong == null,
        error: rawState, // Temporarily pipe raw state for TestFlight debug
      );

      // Analyze the vibe if we have a song OR we have history
      if ((isPlaying && currentSong != null) || currentRecent.isNotEmpty) {
        await _analyzeVibeOnBackend(currentSong, currentRecent);
      } else {
        state = state.copyWith(clearVibe: true);
      }
    } catch (e) {
      debugPrint('[MusicSync] Error refreshing context: $e');
      state = state.copyWith(error: 'Failed to refresh music state');
    }
  }

  Future<void> _analyzeVibeOnBackend(
    MusicItem? song,
    List<MusicItem> recent,
  ) async {
    state = state.copyWith(isAnalyzing: true, error: null);

    try {
      final token = await _storage.read(key: 'jwt');
      if (token == null) {
        state = state.copyWith(isAnalyzing: false, error: 'Not authenticated');
        return;
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/api/music/context');

      final payload = {
        "is_playing_now": song != null,
        "current_song": song != null
            ? {
                "title": song.title ?? "Unknown",
                "artist": song.artistName ?? "Unknown",
              }
            : null,
        "recent_songs": recent
            .map(
              (s) => {
                "title": s.title ?? "Unknown",
                "artist": s.artistName ?? "Unknown",
              },
            )
            .toList(),
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final vibe = MusicVibe.fromJson(data);
        state = state.copyWith(isAnalyzing: false, analyzedVibe: vibe);
      } else {
        state = state.copyWith(
          isAnalyzing: false,
          error: 'Backend error: ${response.statusCode}',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isAnalyzing: false,
        error: 'Network error analyzing music vibe.',
      );
    }
  }
}

// Provider for secure storage
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

// Provider for the controller
final musicSyncControllerProvider =
    StateNotifierProvider<MusicSyncController, MusicContextState>((ref) {
      final musicService = ref.watch(musicServiceProvider);
      final storage = ref.watch(secureStorageProvider);
      return MusicSyncController(musicService, storage);
    });
