import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

/// The state containing authorization status, current song, and analyzed vibe.
class MusicContextState {
  final bool isAuthorized;
  final bool isPlaying;
  final MusicItem? currentSong;
  final MusicVibe? analyzedVibe;
  final bool isAnalyzing;
  final String? error;

  MusicContextState({
    this.isAuthorized = false,
    this.isPlaying = false,
    this.currentSong,
    this.analyzedVibe,
    this.isAnalyzing = false,
    this.error,
  });

  MusicContextState copyWith({
    bool? isAuthorized,
    bool? isPlaying,
    MusicItem? currentSong,
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
    final authStatus = await _musicService.checkAuthorization();
    state = state.copyWith(isAuthorized: authStatus);
    if (authStatus) {
      await refreshMusicContext();
    }
  }

  Future<void> requestPermission() async {
    final granted = await _musicService.requestAuthorization();
    state = state.copyWith(isAuthorized: granted);
    if (granted) {
      await refreshMusicContext();
    }
  }

  Future<void> refreshMusicContext() async {
    if (!state.isAuthorized) return;

    try {
      final isPlaying = await _musicService.isPlaying();
      final currentSong = await _musicService.getCurrentSong();

      state = state.copyWith(
        isPlaying: isPlaying,
        currentSong: currentSong,
        clearSong: currentSong == null,
      );

      // Analyze the vibe if we have a song
      if (isPlaying && currentSong != null) {
        await _analyzeVibeOnBackend(currentSong);
      } else {
        state = state.copyWith(clearVibe: true);
      }
    } catch (e) {
      debugPrint('[MusicSync] Error refreshing context: $e');
      state = state.copyWith(error: 'Failed to refresh music state');
    }
  }

  Future<void> _analyzeVibeOnBackend(MusicItem song) async {
    state = state.copyWith(isAnalyzing: true, error: null);

    try {
      final token = await _storage.read(key: 'jwt');
      if (token == null) {
        state = state.copyWith(isAnalyzing: false, error: 'Not authenticated');
        return;
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/api/music/context');

      final payload = {
        "is_playing_now": true,
        "current_song": {
          "title": song.title ?? "Unknown",
          "artist": song.artistName ?? "Unknown",
        },
        // We aren't doing recent songs here just yet as MusicKit
        // doesn't expose heavily historical history without a raw catalog request.
        "recent_songs": [],
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
