import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/health_service_interface.dart';
import '../providers/health_service_provider.dart';
import '../models/health_snapshot.dart';
import '../../../core/providers/dio_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State Model
// ─────────────────────────────────────────────────────────────────────────────

class HealthContextState {
  final bool isAuthorized;
  final bool isPartiallyAuthorized;
  final bool isFetching;
  final HealthSnapshot? latestSnapshot;
  final String? error;

  HealthContextState({
    this.isAuthorized = false,
    this.isPartiallyAuthorized = false,
    this.isFetching = false,
    this.latestSnapshot,
    this.error,
  });

  HealthContextState copyWith({
    bool? isAuthorized,
    bool? isPartiallyAuthorized,
    bool? isFetching,
    HealthSnapshot? latestSnapshot,
    String? error,
    bool clearSnapshot = false,
    bool clearError = false,
  }) {
    return HealthContextState(
      isAuthorized: isAuthorized ?? this.isAuthorized,
      isPartiallyAuthorized:
          isPartiallyAuthorized ?? this.isPartiallyAuthorized,
      isFetching: isFetching ?? this.isFetching,
      latestSnapshot: clearSnapshot
          ? null
          : (latestSnapshot ?? this.latestSnapshot),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Controller
// ─────────────────────────────────────────────────────────────────────────────

class HealthSyncController extends StateNotifier<HealthContextState>
    with WidgetsBindingObserver {
  final HealthServiceInterface _healthService;
  final FlutterSecureStorage _storage;
  final Dio _dio;

  Timer? _pollTimer;

  HealthSyncController(this._healthService, this._storage, this._dio)
    : super(HealthContextState()) {
    WidgetsBinding.instance.addObserver(this);
    // Rule 6: Proactive fetch on init
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── Rule 5: AppLifecycleObserver ───────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[HealthSync] Resumed — re-checking auth + health state...');
      _recheckAuthorization();
    } else if (state == AppLifecycleState.paused) {
      debugPrint('[HealthSync] Paused — cancelling poll timer.');
      _pollTimer?.cancel(); // Save battery when backgrounded
    }
  }

  Future<void> _init() async {
    await _recheckAuthorization();
  }

  Future<void> _recheckAuthorization() async {
    final types = await _healthService.getAuthorizedTypes();
    // Any authorized types = we can show data. Don't use a hardcoded count threshold
    // because the Swift readTypes set size may change independently of this file.
    final isAuthorized = types.isNotEmpty;

    state = state.copyWith(
      isAuthorized: isAuthorized,
      isPartiallyAuthorized:
          false, // HealthKit doesn't expose per-type read denial
      clearError: true,
    );

    if (isAuthorized) {
      _startPolling();
      // Rule 6: Proactive fetch immediately, don't wait for poll tick
      await refreshHealthContext();
    }
  }

  // ── Rule 4: 5 Minute Poll Interval ──────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _pollHealthState();
    });
    debugPrint('[HealthSync] Polling started (5 min interval).');
  }

  Future<void> _pollHealthState() async {
    // Rule 7: Gate every fetch
    if (!state.isAuthorized) return;

    // Rule 3: `_isFetching` bool guard
    if (state.isFetching) return;

    try {
      await refreshHealthContext();
    } catch (e) {
      debugPrint('[HealthSync] Poll error: $e');
    }
  }

  // ── Auth Flow ──────────────────────────────────────────────────────────────

  Future<void> requestPermission() async {
    try {
      await _healthService.requestAuthorization();
    } catch (e) {
      debugPrint('[HealthSync] 💥 requestAuthorization failed: $e');
      state = state.copyWith(error: e.toString().replaceAll('Exception: ', ''));
      return;
    }

    // Re-check actual granted types (partial auth support)
    final types = await _healthService.getAuthorizedTypes();
    final isAuthorized = types.isNotEmpty;

    state = state.copyWith(
      isAuthorized: isAuthorized,
      isPartiallyAuthorized: false,
      clearError: true,
    );

    if (isAuthorized) {
      // Set to fetching early to block double taps
      state = state.copyWith(isFetching: true);

      // Rule 1: reinitAfterAuthorization immediately after permission granted
      await _healthService.reinitAfterAuthorization();

      // Rule 2: 500ms delay after reinit
      await Future.delayed(const Duration(milliseconds: 500));

      state = state.copyWith(isFetching: false);

      _startPolling();
      await refreshHealthContext();
    } else {
      // types is empty — the prompt flag wasn't set, meaning requestAuthorization
      // threw an error before we could set it, or something went wrong on the Swift side.
      state = state.copyWith(
        error:
            'HealthKit access not granted. You can enable it in Settings > Privacy > Health.',
      );
    }
  }

  // ── Data Fetching & Sync ───────────────────────────────────────────────────

  Future<void> refreshHealthContext() async {
    // Rule 7: Gate fetch — only proceed if authorized
    if (!state.isAuthorized) return;

    // Rule 3: Guard overlapping fetches
    if (state.isFetching) return;

    state = state.copyWith(isFetching: true, clearError: true);
    try {
      final snapshot = await _healthService.getLatestSnapshot();

      if (snapshot != null) {
        state = state.copyWith(latestSnapshot: snapshot);

        // Post to backend RAG
        await _postToBackend(snapshot);
      } else {
        debugPrint('[HealthSync] Snapshot is null (no data available).');
      }
    } catch (e) {
      debugPrint('[HealthSync] Error refreshing health context: $e');
      // Rule 8: If it's a permission/401 error, clear state, else just keep old data
      if (e.toString().contains('permission') || e.toString().contains('401')) {
        state = state.copyWith(
          isAuthorized: false,
          isPartiallyAuthorized: false,
          clearSnapshot: true,
          error: 'Authorization error. Please reconnect.',
        );
        _pollTimer?.cancel();
      } else {
        state = state.copyWith(error: 'Failed to refresh: $e');
      }
    } finally {
      state = state.copyWith(isFetching: false);
    }
  }

  Future<void> _postToBackend(HealthSnapshot snapshot) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        state = state.copyWith(error: 'Not authenticated for backend sync');
        return;
      }

      final payload = snapshot.toJson();

      try {
        await _dio.post(
          '/api/health/context',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
          data: payload,
        );
        debugPrint('[HealthSync] Successfully synced health data to backend.');
      } on DioException catch (e) {
        // Rule 8 on backend 401
        if (e.response?.statusCode == 401) {
          debugPrint('[HealthSync] 401 sending health context.');
          state = state.copyWith(error: 'Session expired (401)');
        } else {
          debugPrint(
            '[HealthSync] Backend error: ${e.response?.statusCode ?? e.message}',
          );
          state = state.copyWith(
            error: 'Backend error: ${e.response?.statusCode ?? e.message}',
          );
        }
      }
    } catch (e) {
      debugPrint('[HealthSync] Network error posting to backend: $e');
      state = state.copyWith(error: 'Network error: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final secureStorageProvider = Provider<FlutterSecureStorage>((_) {
  return const FlutterSecureStorage();
});

final healthSyncControllerProvider =
    StateNotifierProvider<HealthSyncController, HealthContextState>((ref) {
      final healthService = ref.watch(healthServiceProvider);
      // Using the same instance as music to avoid multiple secure storage instances
      // if possible, but recreating is cheap enough here.
      final storage = ref.watch(secureStorageProvider);
      final dio = ref.watch(dioProvider);

      return HealthSyncController(healthService, storage, dio);
    });
