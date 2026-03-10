---
trigger: always_on
---

# BrainDumps Agent Rules

## Stack
- Flutter + Dart, Riverpod (StateNotifier), Swift MethodChannels
- iOS only, physical device testing (no simulator)
- Backend: Python RAG, JWT auth via flutter_secure_storage

## Architecture rules
- Always use StateNotifierProvider, never ChangeNotifier
- Service layer must have an abstract interface + real implementation
- All native calls go through MethodChannel with a Swift handler
- Never call ref.read() inside build() — always ref.watch()
- Every StateNotifier must implement WidgetsBindingObserver for lifecycle

## Async rules — learned from MusicKit/HealthKit bugs
- Never fetch data immediately after authorization — always await Future.delayed(500ms) first
- Always call reinitAfterAuthorization() before any data fetch post-permission
- Always guard concurrent async calls with a _isFetching bool flag
- Stream subscriptions made before authorization may not receive events — reinit after auth
- Never rely solely on streams for initial state — always proactive snapshot on init

## HealthKit specific
- checkAuthorizationStatus() cannot read true read permission from iOS
- Use UserDefaults flag (healthkit_auth_requested) to track if prompt has fired
- Bump healthkit_read_types_version in init() when readTypes expands to force re-prompt
- Sleep queries must use 6pm-yesterday → noon-today window, not last 24h
- HRV only available if Apple Watch worn during sleep or rest

## MusicKit specific  
- playbackStatus always returns stopped for externally controlled playback
- Derive isPlaying from queue.currentEntry != null, not playbackStatus
- onPlayerQueueChanged only fires on change — snapshot initial queue on init
- JWT developer token → Music-User-Token two step flow, cache the user token

## State management rules
- copyWith must never silently drop fields — review every copyWith call
- Auth state thresholds must not be hardcoded counts — use isEmpty/isNotEmpty
- Always gate data fetches: if (!state.isAuthorized) return
- On 401 response — invalidate cached tokens, update auth state

## UI rules
- All health/music widgets are ConsumerWidget using ref.watch
- Readiness label needs minimum 2 data points — return SYNCING if fewer
- Never show LOW/error state when data is simply missing (null) — show SYNCING
- Bottom sheets use showModalBottomSheet with backgroundColor: Colors.transparent
- Match AppColors from core/theme/app_theme.dart — never hardcode colors that exist there

## Swift rules
- All HealthKit queries must have date predicates — no unbounded queries
- Always dispatch results back on DispatchQueue.main
- Use DispatchGroup for concurrent queries that must complete together
- Register all MethodChannels in AppDelegate before GeneratedPluginRegistrant.register()

## Code review checklist — run before every PR
- dart analyze shows zero errors
- Every new MethodChannel case has a corresponding Swift handler
- Every new field in a model is also added to toJson() and fromMap()
- Every new Swift query method is registered in the switch in setupChannel()
- dispose() cancels all timers and removes all observers
- No hardcoded strings that should be in constants