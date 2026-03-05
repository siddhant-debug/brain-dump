import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'; // for WidgetsBindingObserver
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/api_constants.dart';
import '../services/music_service.dart';

/// Represents the analyzed Vibe returned from the backend
class MusicVibe {
  final String primaryTone;
  final String shortDescription;
  final double valence;
  final double arousal;
  final double dominance;

  MusicVibe({
    required this.primaryTone,
    required this.shortDescription,
    this.valence = 0.0,
    this.arousal = 0.0,
    this.dominance = 0.0,
  });

  factory MusicVibe.fromJson(Map<String, dynamic> json) {
    return MusicVibe(
      primaryTone: json['primary_tone'] as String? ?? 'Unknown',
      shortDescription: json['short_description'] as String? ?? '',
      valence: (json['valence'] as num?)?.toDouble() ?? 0.0,
      arousal: (json['arousal'] as num?)?.toDouble() ?? 0.0,
      dominance: (json['dominance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Converts vibe to a payload dict to pass music_context to the RAG endpoint.
  Map<String, dynamic> toContextMap({
    bool isPlayingNow = false,
    Map<String, String>? currentSong,
  }) {
    return {
      'primary_tone': primaryTone,
      'short_description': shortDescription,
      'valence': valence,
      'arousal': arousal,
      'dominance': dominance,
      'is_playing_now': isPlayingNow,
      if (currentSong != null) 'current_song': currentSong,
    };
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

class MusicSyncController extends StateNotifier<MusicContextState>
    with WidgetsBindingObserver {
  final MusicService _musicService;
  final FlutterSecureStorage _storage;

  MusicSyncController(this._musicService, this._storage)
    : super(MusicContextState()) {
    // FIX 1: Register as lifecycle observer so the auth dot reacts
    // immediately when the user returns from the native Apple Music popup.
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// FIX 1 (Auth Dot): When the app resumes from background, re-check
  /// authorization. This covers the case where the user grants permission
  /// in the native Apple popup and returns to the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      debugPrint('[MusicSync] App resumed — re-checking auth status...');
      _recheckAuthorization();
    }
  }

  Future<void> _recheckAuthorization() async {
    final authStatus = await _musicService.checkAuthorization();
    if (authStatus != state.isAuthorized) {
      debugPrint('[MusicSync] Auth changed → isAuthorized: $authStatus');
      state = state.copyWith(isAuthorized: authStatus);
      if (authStatus) {
        _startPlayerStateListener();
        await refreshMusicContext();
      }
    }
  }

  Future<void> _init() async {
    final authStatus = await _musicService.checkAuthorization();
    state = state.copyWith(isAuthorized: authStatus);

    if (authStatus) {
      _startPlayerStateListener();
      await refreshMusicContext();
    } else {
      await requestPermission();
    }
  }

  void _startPlayerStateListener() {
    _musicService.onPlayerStateChanged.listen((_) {
      refreshMusicContext();
    });
  }

  Future<void> requestPermission() async {
    final granted = await _musicService.requestAuthorization();
    state = state.copyWith(isAuthorized: granted);
    if (granted) {
      _startPlayerStateListener();
      await refreshMusicContext();
    }
  }

  /// FIX 2 (Recent Songs): Fetch the real last 10 tracks from Apple Music API
  /// via the backend endpoint GET /api/music/recent/played.
  /// Falls back to an empty list if the Music-User-Token is unavailable.
  Future<List<MusicItem>> _fetchRecentSongsFromBackend() async {
    try {
      final jwt = await _storage.read(key: 'jwt');
      if (jwt == null) {
        debugPrint('[MusicSync] No JWT found, skipping recent songs fetch.');
        return [];
      }

      final musicUserToken = await _musicService.getMusicUserToken();
      if (musicUserToken == null) {
        debugPrint(
          '[MusicSync] No Music-User-Token, skipping recent songs fetch.',
        );
        return [];
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/api/music/recent/played');
      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $jwt',
              'Music-User-Token': musicUserToken,
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final songList = (data['recent_songs'] as List<dynamic>?) ?? [];
        final songs = songList.map((s) {
          final m = s as Map<String, dynamic>;
          return MusicItem(
            title: m['title'] as String? ?? 'Unknown',
            artistName: m['artist'] as String? ?? 'Unknown',
          );
        }).toList();
        debugPrint(
          '[MusicSync] Fetched ${songs.length} recent songs from backend.',
        );
        return songs;
      } else if (response.statusCode == 401) {
        debugPrint('[MusicSync] Music-User-Token expired or invalid (401).');
        state = state.copyWith(
          error: 'Apple Music token expired. Please re-authorize.',
        );
        return [];
      } else {
        debugPrint(
          '[MusicSync] Backend returned ${response.statusCode} for recent/played.',
        );
        return [];
      }
    } on TimeoutException {
      debugPrint('[MusicSync] Timeout fetching recent songs.');
      return [];
    } catch (e) {
      debugPrint('[MusicSync] Error fetching recent songs: $e');
      return [];
    }
  }

  Future<void> refreshMusicContext() async {
    if (!state.isAuthorized) return;

    try {
      final isPlaying = await _musicService.isPlaying();
      final currentSong = await _musicService.getCurrentSong();
      final rawState = await _musicService.getRawPlayerState();

      // FIX 2: Fetch real recent songs from Apple Music API via backend
      final recentSongs = await _fetchRecentSongsFromBackend();

      state = state.copyWith(
        isPlaying: isPlaying,
        currentSong: currentSong,
        recentSongs: recentSongs,
        clearSong: currentSong == null,
        error: rawState, // Keep raw state for TestFlight debug
      );

      // Analyze vibe if we have any context
      if ((isPlaying && currentSong != null) || recentSongs.isNotEmpty) {
        await _analyzeVibeOnBackend(currentSong, recentSongs);
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
