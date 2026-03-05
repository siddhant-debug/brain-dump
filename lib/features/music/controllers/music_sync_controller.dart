import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/api_constants.dart';
import '../services/music_service_interface.dart';
import '../services/music_service.dart'; // for MusicItem + musicKitProvider
import '../providers/music_service_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

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

  factory MusicVibe.fromJson(Map<String, dynamic> json) => MusicVibe(
    primaryTone: json['primary_tone'] as String? ?? 'Unknown',
    shortDescription: json['short_description'] as String? ?? '',
    valence: (json['valence'] as num?)?.toDouble() ?? 0.0,
    arousal: (json['arousal'] as num?)?.toDouble() ?? 0.0,
    dominance: (json['dominance'] as num?)?.toDouble() ?? 0.0,
  );

  Map<String, dynamic> toContextMap({
    bool isPlayingNow = false,
    Map<String, String>? currentSong,
  }) => {
    'primary_tone': primaryTone,
    'short_description': shortDescription,
    'valence': valence,
    'arousal': arousal,
    'dominance': dominance,
    'is_playing_now': isPlayingNow,
    if (currentSong != null) 'current_song': currentSong,
  };
}

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
  }) => MusicContextState(
    isAuthorized: isAuthorized ?? this.isAuthorized,
    isPlaying: isPlaying ?? this.isPlaying,
    currentSong: clearSong ? null : (currentSong ?? this.currentSong),
    recentSongs: recentSongs ?? this.recentSongs,
    analyzedVibe: clearVibe ? null : (analyzedVibe ?? this.analyzedVibe),
    isAnalyzing: isAnalyzing ?? this.isAnalyzing,
    error: error,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Controller
// ─────────────────────────────────────────────────────────────────────────────

class MusicSyncController extends StateNotifier<MusicContextState>
    with WidgetsBindingObserver {
  // Step 5: accepts MusicServiceInterface, not the concrete MusicService
  final MusicServiceInterface _musicService;
  final FlutterSecureStorage _storage;

  /// FIX 3: Cache the Music-User-Token so we don't re-fetch on every poll.
  /// Invalidated on 401 responses so it refreshes automatically.
  String? _cachedMusicUserToken;

  /// FIX 4: Guard flag — prevents concurrent backend calls during a single poll cycle.
  bool _isAnalyzing = false;

  Timer? _pollTimer;
  String? _lastSeenSongTitle;

  MusicSyncController(this._musicService, this._storage)
    : super(MusicContextState()) {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── Fix 1: Auth Dot — AppLifecycleObserver ───────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      debugPrint('[MusicSync] Resumed — re-checking auth + music state...');
      _recheckAuthorization();
    } else if (lifecycle == AppLifecycleState.paused) {
      _pollTimer?.cancel(); // Save battery when backgrounded
    }
  }

  Future<void> _recheckAuthorization() async {
    final authStatus = await _musicService.checkAuthorization();
    if (authStatus != state.isAuthorized) {
      state = state.copyWith(isAuthorized: authStatus);
    }
    if (authStatus) {
      _startPolling();
      await refreshMusicContext();
    }
  }

  Future<void> _init() async {
    final authStatus = await _musicService.checkAuthorization();
    state = state.copyWith(isAuthorized: authStatus);
    if (authStatus) {
      _startPolling();
      await refreshMusicContext();
    } else {
      await requestPermission();
    }
  }

  // ── Fix 3: Stream replaced by timer poll ─────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollPlayerState();
    });
    debugPrint('[MusicSync] Polling started (5s interval).');
  }

  Future<void> _pollPlayerState() async {
    if (!state.isAuthorized) return;

    // FIX 4: Prevent overlapping backend calls from concurrent poll ticks
    if (_isAnalyzing) return;

    try {
      final isPlaying = await _musicService.isPlaying();
      final currentSong = await _musicService.getCurrentSong();
      final newTitle = currentSong?.title;

      final playStateChanged = isPlaying != state.isPlaying;
      final songChanged = newTitle != _lastSeenSongTitle;

      if (playStateChanged || songChanged) {
        debugPrint(
          '[MusicSync] Poll detected change: playing=$isPlaying, song=$newTitle',
        );
        state = state.copyWith(
          isPlaying: isPlaying,
          currentSong: currentSong,
          clearSong: currentSong == null,
        );
        _lastSeenSongTitle = newTitle;

        if (songChanged) {
          // FIX 4: Set guard before backend work
          _isAnalyzing = true;
          try {
            final recentSongs = await _fetchRecentSongsFromBackend();
            state = state.copyWith(recentSongs: recentSongs);
            if ((isPlaying && currentSong != null) || recentSongs.isNotEmpty) {
              await _analyzeVibeOnBackend(currentSong, recentSongs);
            }
          } finally {
            _isAnalyzing = false;
          }
        }
      }
    } catch (e) {
      debugPrint('[MusicSync] Poll error: $e');
    }
  }

  Future<void> requestPermission() async {
    final granted = await _musicService.requestAuthorization();
    state = state.copyWith(isAuthorized: granted);
    if (granted) {
      _startPolling();
      await refreshMusicContext();
    }
  }

  /// Manual full refresh — also called by the ↺ button in the bottom sheet.
  Future<void> refreshMusicContext() async {
    if (!state.isAuthorized) return;
    try {
      final isPlaying = await _musicService.isPlaying();
      final currentSong = await _musicService.getCurrentSong();
      final rawState = await _musicService.getRawPlayerState();

      debugPrint(
        '[MusicSync] refresh: isPlaying=$isPlaying, song=${currentSong?.title}',
      );

      final recentSongs = await _fetchRecentSongsFromBackend();
      _lastSeenSongTitle = currentSong?.title;

      state = state.copyWith(
        isPlaying: isPlaying,
        currentSong: currentSong,
        recentSongs: recentSongs,
        clearSong: currentSong == null,
        error: rawState,
      );

      if ((isPlaying && currentSong != null) || recentSongs.isNotEmpty) {
        await _analyzeVibeOnBackend(currentSong, recentSongs);
      } else {
        state = state.copyWith(clearVibe: true);
      }
    } catch (e) {
      debugPrint('[MusicSync] Error refreshing context: $e');
      state = state.copyWith(error: 'Failed to refresh: $e');
    }
  }

  // ── FIX 3: Cached Music-User-Token ──────────────────────────────────────

  Future<String?> _getMusicUserTokenCached() async {
    if (_cachedMusicUserToken != null) return _cachedMusicUserToken;
    _cachedMusicUserToken = await _musicService.getMusicUserToken();
    return _cachedMusicUserToken;
  }

  // ── Fix 2: Fetch real Apple Music recent songs via backend ───────────────

  Future<List<MusicItem>> _fetchRecentSongsFromBackend() async {
    try {
      final jwt = await _storage.read(key: 'jwt');
      if (jwt == null) return [];

      // FIX 3: use cached token
      final musicUserToken = await _getMusicUserTokenCached();
      if (musicUserToken == null) {
        debugPrint('[MusicSync] No Music-User-Token, skipping recent songs.');
        return [];
      }

      final response = await http
          .get(
            Uri.parse('${ApiConstants.baseUrl}/api/music/recent/played'),
            headers: {
              'Authorization': 'Bearer $jwt',
              'Music-User-Token': musicUserToken,
            },
          )
          // FIX 5: increased timeout from 10s to 15s
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final songList = (data['recent_songs'] as List<dynamic>?) ?? [];
        return songList.map((s) {
          final m = s as Map<String, dynamic>;
          return MusicItem(
            title: m['title'] as String? ?? 'Unknown',
            artistName: m['artist'] as String? ?? 'Unknown',
          );
        }).toList();
      } else if (response.statusCode == 401) {
        // FIX 3: Invalidate cached token on 401 so it refreshes next call
        debugPrint(
          '[MusicSync] 401 on recent/played — invalidating token cache.',
        );
        _cachedMusicUserToken = null;
        state = state.copyWith(
          error: 'Apple Music token expired. Will retry automatically.',
        );
        return [];
      } else {
        debugPrint(
          '[MusicSync] Backend ${response.statusCode} for recent/played.',
        );
        return [];
      }
    } on TimeoutException {
      debugPrint('[MusicSync] Timeout fetching recent songs (15s).');
      return [];
    } catch (e) {
      debugPrint('[MusicSync] Error fetching recent songs: $e');
      return [];
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

      final payload = {
        'is_playing_now': song != null,
        'current_song': song != null
            ? {
                'title': song.title ?? 'Unknown',
                'artist': song.artistName ?? 'Unknown',
              }
            : null,
        'recent_songs': recent
            .map(
              (s) => {
                'title': s.title ?? 'Unknown',
                'artist': s.artistName ?? 'Unknown',
              },
            )
            .toList(),
      };

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/music/context'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final vibe = MusicVibe.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        state = state.copyWith(isAnalyzing: false, analyzedVibe: vibe);
      } else {
        state = state.copyWith(
          isAnalyzing: false,
          error: 'Backend error: ${response.statusCode}',
        );
      }
    } catch (e) {
      state = state.copyWith(isAnalyzing: false, error: 'Network error: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

/// Step 5: Controller now reads [musicServiceInterfaceProvider] which returns
/// either [MusicService] or [MockMusicService] depending on --dart-define=MOCK_MUSIC.
final musicSyncControllerProvider =
    StateNotifierProvider<MusicSyncController, MusicContextState>((ref) {
      final musicService = ref.watch(musicServiceInterfaceProvider);
      final storage = ref.watch(secureStorageProvider);
      return MusicSyncController(musicService, storage);
    });
