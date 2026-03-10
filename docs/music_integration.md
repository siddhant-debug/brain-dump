# BrainDump — Apple Music Integration

Complete technical reference: architecture, data flow, and all changes made.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Backend Changes](#backend-changes)
   - [schemas.py](#schemaspy)
   - [models.py](#modelspy)
   - [music_analyzer.py](#music_analyzerpy)
   - [music.py (API Router)](#musicpy-api-router)
   - [rag.py (RAG Chat)](#ragpy-rag-chat)
4. [Frontend Changes](#frontend-changes)
   - [music_service.dart](#music_servicedart)
   - [music_sync_controller.dart](#music_sync_controllerdart)
   - [music_vibe_bottom_sheet.dart](#music_vibe_bottom_sheetdart)
   - [analytics_screen.dart](#analytics_screendart)
5. [Complete Code Flow](#complete-code-flow)
6. [VAD Mood Vector](#vad-mood-vector)
7. [Bugs Fixed](#bugs-fixed)
8. [Alembic Migration](#alembic-migration)
9. [TestFlight Testing Guide](#testflight-testing-guide)

---

## Overview

BrainDump connects to Apple Music to analyze the user's listening mood using a 3-dimensional **VAD (Valence-Arousal-Dominance)** vector. This mood is used as contextual signal in the RAG (Retrieval-Augmented Generation) chat to shape how the AI surfaces and frames the user's memories.

**Stack:**
- Flutter (iOS, TestFlight)
- FastAPI + PostgreSQL/pgvector (HP Pavilion Unix server)
- MusicKit (Flutter plugin: `music_kit ^1.3.0`)
- Google Gemini (mood analysis LLM)
- Apple Music API (`https://api.music.apple.com/v1`)

---

## Architecture Diagram

```
iPhone (Flutter App)
│
├── MusicService          ← wraps MusicKit plugin
│     ├── checkAuthorization()
│     ├── isPlaying()
│     ├── getCurrentSong()
│     └── getMusicUserToken()  ← requestDeveloperToken() → requestUserToken()
│
├── MusicSyncController   ← Riverpod StateNotifier
│     ├── Timer (5s poll) ← replaces unreliable stream
│     ├── AppLifecycleObserver ← auth dot fix
│     ├── refreshMusicContext()
│     └── _analyzeVibeOnBackend()
│
└── MusicVibeBottomSheet  ← ConsumerWidget (live Riverpod watch)
      └── ref.watch(musicSyncControllerProvider)

          │ HTTP
          ▼

FastAPI Backend (Unix Server)
│
├── GET  /api/music/recent/played
│     ├── Accepts: Music-User-Token header
│     ├── Reads:   APPLE_MUSIC_JWT from .env
│     └── Calls:   Apple Music API → returns last 10 songs
│
├── POST /api/music/context
│     └── MusicAnalyzerService.analyze_tone()
│           ├── Check MusicVibeCache (PostgreSQL)
│           ├── Cache HIT  → return cached VAD
│           └── Cache MISS → Gemini API → parse VAD → save cache → return
│
└── POST /chat/chat
      └── event_generator()
            ├── retrieve_context() — pgvector + BM25 + cross-encoder
            └── ask_gemini_stream_async(..., music_layer=...)
                  └── VAD Mood Vector → natural language → injected into prompt
```

---

## Backend Changes

### `schemas.py`

**File:** `backend/app/schemas/schemas.py`

```python
# BEFORE
class MusicContextRequest(BaseModel):
    is_playing_now: bool
    current_song: Optional[SongInfo]
    recent_songs: Optional[List[SongInfo]]

class MusicContextResponse(BaseModel):
    primary_tone: str
    short_description: str

# AFTER — added music_user_token + VAD fields
class MusicContextRequest(BaseModel):
    is_playing_now: bool
    current_song: Optional[SongInfo]
    recent_songs: Optional[List[SongInfo]] = []
    music_user_token: Optional[str] = None   # ← NEW

class MusicContextResponse(BaseModel):
    primary_tone: str
    short_description: str
    valence: float = 0.0     # ← NEW: emotional positivity (-1 to 1)
    arousal: float = 0.0     # ← NEW: energy level (-1 to 1)
    dominance: float = 0.0   # ← NEW: sense of control (-1 to 1)
```

---

### `models.py`

**File:** `backend/app/models/models.py`

```python
# BEFORE
class MusicVibeCache(Base):
    __tablename__ = "music_vibe_cache"
    id = Column(Integer, primary_key=True)
    cache_key = Column(String, unique=True, nullable=False)
    primary_tone = Column(String)
    short_description = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)

# AFTER — added VAD columns
class MusicVibeCache(Base):
    __tablename__ = "music_vibe_cache"
    id = Column(Integer, primary_key=True)
    cache_key = Column(String, unique=True, nullable=False)
    primary_tone = Column(String)
    short_description = Column(String)
    valence = Column(JSON, nullable=True)     # ← NEW
    arousal = Column(JSON, nullable=True)     # ← NEW
    dominance = Column(JSON, nullable=True)   # ← NEW
    created_at = Column(DateTime, default=datetime.utcnow)
```

> **Migration required** — see [Alembic Migration](#alembic-migration)

---

### `music_analyzer.py`

**File:** `backend/app/services/music_analyzer.py`

Key changes:

1. **Gemini prompt** now requests a 5-key JSON including `valence`, `arousal`, `dominance`
2. **Cache** reads and writes all 3 VAD values
3. **Error fallback** returns `valence=0.0, arousal=0.0, dominance=0.0`

```python
prompt = f"""
Analyze the following song(s): 
{song_context}

Determine their current mood using a 3-dimensional vector (Valence, Arousal, Dominance)
where each is a float between -1.0 and 1.0.
Choose a 'primary_tone' from: Happy, Sad, Romance, Work/Focus, Gym/High-Energy, Chill/Relaxed.
Write a 'short_description' (1 short sentence).

Return EXACTLY this JSON:
{{"primary_tone": str, "short_description": str, "valence": float, "arousal": float, "dominance": float}}
"""

# System instruction
system_instruction = "You are a music analysis engine classifying emotional tone \
and listener mindset based purely on song titles and artists."
```

**Cache read:**
```python
if cached:
    return {
        "primary_tone": cached.primary_tone,
        "short_description": cached.short_description,
        "valence": cached.valence if cached.valence is not None else 0.0,
        "arousal": cached.arousal if cached.arousal is not None else 0.0,
        "dominance": cached.dominance if cached.dominance is not None else 0.0,
    }
```

---

### `music.py` (API Router)

**File:** `backend/app/api/routers/music.py`

Two endpoints:

#### `GET /api/music/recent/played`

```
Headers required:
  Authorization: Bearer <JWT>
  Music-User-Token: <from MusicKit>

Flow:
  1. Read APPLE_MUSIC_JWT from .env (developer token)
  2. Call Apple Music API:
       GET https://api.music.apple.com/v1/me/recent/played
       ?limit=10&types=songs
       Headers: Authorization: Bearer <dev_token>
                Music-User-Token: <user_token>
  3. Parse .data[].attributes.{name, artistName}
  4. Return: { "recent_songs": [{"title": ..., "artist": ...}] }

Error handling:
  401 → Music-User-Token expired
  403 → APPLE_MUSIC_JWT expired (check .env)
  502 → Apple Music API unreachable
```

#### `POST /api/music/context`

```
Body: MusicContextRequest (is_playing_now, current_song, recent_songs)

Flow:
  1. Validate input
  2. Call MusicAnalyzerService.analyze_tone(request, db)
  3. Return: MusicContextResponse (primary_tone, short_description, valence, arousal, dominance)
```

---

### `rag.py` (RAG Chat)

**File:** `backend/app/api/routers/rag.py`

The `music_layer` is built from the VAD vector and injected into the Gemini system prompt:

```python
# BEFORE
music_layer = f"MUSIC CONTEXT: They are CURRENTLY playing '{song_name}'. \
Tone: {mc.get('primary_tone')} ({mc.get('short_description')})."

# AFTER — VAD translated to natural language
def _vad_label(value, pos, neg):
    if value > 0.4:   return f"very {pos}"
    elif value > 0.1: return pos
    elif value < -0.4: return f"very {neg}"
    elif value < -0.1: return neg
    return "neutral"

val_label = _vad_label(valence, "positive/joyful", "negative/melancholic")
aro_label = _vad_label(arousal, "energized/intense", "calm/low-energy")
dom_label = _vad_label(dominance, "confident/in-control", "reflective/vulnerable")

vad_summary = f"Emotional state: {val_label} mood, {aro_label}, feeling {dom_label}."

music_layer = (
    f"MUSIC CONTEXT: Currently playing '{song_name}'. "
    f"Tone: {primary_tone} — {short_desc}. "
    f"{vad_summary} "
    f"Adjust your tone and retrieval weighting accordingly."
)
```

---

## Frontend Changes

### `music_service.dart`

**File:** `lib/features/music/services/music_service.dart`

Added `getMusicUserToken()` using the MusicKit two-step flow:

```dart
/// Step 1: Get Developer JWT from native SDK
/// Step 2: Exchange it for the per-user Music-User-Token
Future<String?> getMusicUserToken() async {
  try {
    final developerToken = await _musicKit.requestDeveloperToken();
    final userToken = await _musicKit.requestUserToken(developerToken);
    return userToken.isNotEmpty ? userToken : null;
  } catch (e) {
    debugPrint('[MusicService] Error fetching Music-User-Token: $e');
    return null;
  }
}
```

> ⚠️ `_musicKit.userToken` does NOT exist — the correct API is `requestDeveloperToken()` → `requestUserToken(devToken)`.

---

### `music_sync_controller.dart`

**File:** `lib/features/music/controllers/music_sync_controller.dart`

This is the core controller. Three major fixes:

#### Fix 1 — Auth Dot (WidgetsBindingObserver)

```dart
class MusicSyncController extends StateNotifier<MusicContextState>
    with WidgetsBindingObserver {

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckAuthorization(); // Re-checks auth on return from native popup
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel(); // Save battery when backgrounded
    }
  }
}
```

#### Fix 2 — Real Apple Music History

```dart
Future<List<MusicItem>> _fetchRecentSongsFromBackend() async {
  final jwt = await _storage.read(key: 'jwt');
  final musicUserToken = await _musicService.getMusicUserToken();

  final response = await http.get(
    Uri.parse('${ApiConstants.baseUrl}/api/music/recent/played'),
    headers: {
      'Authorization': 'Bearer $jwt',
      'Music-User-Token': musicUserToken!,
    },
  ).timeout(const Duration(seconds: 10));

  // Returns List<MusicItem> from real Apple Music history
}
```

#### Fix 3 — 5-Second Polling (replaces broken stream)

```dart
// PROBLEM: onMusicPlayerStateChanged stream ONLY fires for in-app playback.
// When user plays Apple Music externally, the stream is permanently silent.

// SOLUTION: Timer.periodic poll
void _startPolling() {
  _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
    _pollPlayerState();
  });
}

Future<void> _pollPlayerState() async {
  final isPlaying = await _musicService.isPlaying();
  final currentSong = await _musicService.getCurrentSong();

  // Only hit backend when song changes — avoids API spam
  if (currentSong?.title != _lastSeenSongTitle) {
    _lastSeenSongTitle = currentSong?.title;
    final recentSongs = await _fetchRecentSongsFromBackend();
    await _analyzeVibeOnBackend(currentSong, recentSongs);
  }
}
```

---

### `music_vibe_bottom_sheet.dart`

**File:** `lib/features/music/presentation/widgets/music_vibe_bottom_sheet.dart`

#### Fix — ConsumerWidget (live state)

```dart
// BEFORE — StatelessWidget with frozen snapshot
class MusicVibeBottomSheet extends StatelessWidget {
  final MusicContextState musicState; // ← never updates after modal opens
  const MusicVibeBottomSheet({required this.musicState});

  @override
  Widget build(BuildContext context) { ... }
}

// AFTER — ConsumerWidget watches provider live
class MusicVibeBottomSheet extends ConsumerWidget {
  const MusicVibeBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-renders automatically on every state change
    final musicState = ref.watch(musicSyncControllerProvider);
    ...
  }
}
```

#### Manual Refresh Button

```dart
IconButton(
  icon: Icon(Icons.refresh_rounded),
  onPressed: musicState.isAnalyzing
      ? null
      : () => ref.read(musicSyncControllerProvider.notifier).refreshMusicContext(),
)
```

#### Recent Songs Fallback

```dart
// BEFORE: Showed "Play a song..." even if recent history available
if (!musicState.isPlaying || musicState.currentSong == null) {
  return Text('Play a song...');
}

// AFTER: Shows vibe from recent history if song is not currently playing
if (!musicState.isPlaying || musicState.currentSong == null) {
  if (musicState.recentSongs.isNotEmpty || musicState.analyzedVibe != null) {
    return _buildVibeContent(null, musicState); // show history-based vibe
  }
  return Text('Play a song...');
}
```

---

### `analytics_screen.dart`

**File:** `lib/features/analytics/presentation/analytics_screen.dart`

```dart
// BEFORE — frozen snapshot passed to modal
builder: (context) => MusicVibeBottomSheet(musicState: musicState),

// AFTER — modal reads state itself
builder: (context) => const MusicVibeBottomSheet(),
```

---

## Complete Code Flow

### Flow A: App Opens (Authorized, Song Playing)

```
1. MusicSyncController._init()
      │
      ├── checkAuthorization() → true
      ├── _startPolling()  ← Timer.periodic(5s)
      └── refreshMusicContext()
              │
              ├── musicService.isPlaying()       → true
              ├── musicService.getCurrentSong()  → MusicItem("Song", "Artist")
              ├── _fetchRecentSongsFromBackend()
              │     ├── getMusicUserToken()
              │     │     ├── requestDeveloperToken()
              │     │     └── requestUserToken(devToken)
              │     └── GET /api/music/recent/played
              │           └── Apple Music API → 10 tracks
              │
              ├── state.update(isPlaying, currentSong, recentSongs)
              │
              └── _analyzeVibeOnBackend(song, recent)
                    └── POST /api/music/context
                          └── MusicAnalyzerService.analyze_tone()
                                ├── Check MusicVibeCache → MISS
                                ├── Gemini API → JSON {tone, desc, vad}
                                ├── Save to MusicVibeCache
                                └── state.update(analyzedVibe)
```

### Flow B: User Opens Music Bottom Sheet

```
User taps music icon
      │
      └── showModalBottomSheet → MusicVibeBottomSheet (ConsumerWidget)
              │
              └── ref.watch(musicSyncControllerProvider)
                    └── Renders current state immediately
                          + Re-renders automatically every time state changes
                          (poll fires every 5s and updates state)
```

### Flow C: User Starts Playing a New Song

```
Timer fires (every 5s) → _pollPlayerState()
      │
      ├── isPlaying() → true
      ├── getCurrentSong() → "New Song" ← title changed
      ├── _lastSeenSongTitle updated
      │
      ├── _fetchRecentSongsFromBackend() → 10 updated tracks
      └── _analyzeVibeOnBackend("New Song", recent)
              └── POST /api/music/context
                    ├── Cache MISS → Gemini call
                    └── state.update(newVibe)
                          └── MusicVibeBottomSheet re-renders ← live update
```

### Flow D: RAG Chat with Music Context

```
User sends chat message
      │
      └── POST /chat/chat
              │
              ├── async_retrieve_context(query, user_id)
              │     ├── pgvector similarity search
              │     ├── BM25 keyword search
              │     └── Cross-encoder re-ranking → top 5 docs
              │
              ├── build music_layer string:
              │     "MUSIC CONTEXT: Currently playing 'Song'.
              │      Tone: Happy — bright upbeat energy.
              │      Emotional state: very positive/joyful mood,
              │      energized/intense, feeling confident/in-control.
              │      Adjust your tone and retrieval weighting accordingly."
              │
              └── ask_gemini_stream_async(context, query, music_layer=...)
                    └── Gemini streams response shaped by music mood
```

---

## VAD Mood Vector

The Valence-Arousal-Dominance model maps emotional state to 3 floats in `[-1.0, 1.0]`:

| Dimension  | +1.0                  | 0.0     | -1.0               |
|------------|----------------------|---------|--------------------|
| Valence    | Joyful / Positive    | Neutral | Sad / Negative     |
| Arousal    | Energized / Intense  | Neutral | Calm / Low-energy  |
| Dominance  | Confident / Control  | Neutral | Reflective / Vulnerable |

**Natural language translation in `rag.py`:**

| Score        | Label            |
|--------------|-----------------|
| > 0.4        | `very {positive}` |
| 0.1 to 0.4   | `{positive}`      |
| -0.1 to 0.1  | `neutral`         |
| -0.4 to -0.1 | `{negative}`      |
| < -0.4       | `very {negative}` |

---

## Bugs Fixed

| # | Bug | Root Cause | Fix |
|---|-----|-----------|-----|
| 1 | Auth dot doesn't update after granting permission | Native Apple popup returns to app via `resumed` lifecycle, not a callback | Added `WidgetsBindingObserver` + `didChangeAppLifecycleState` to re-check auth |
| 2 | Modal shows "Play a song…" even when music is playing | `StatelessWidget` received a frozen `musicState` snapshot at open time | Converted to `ConsumerWidget` with `ref.watch(musicSyncControllerProvider)` |
| 3 | Modal never updates while open | `onMusicPlayerStateChanged` stream only fires for in-app playback | Replaced stream with `Timer.periodic(5s)` poll |
| 4 | Recent songs always empty | Tracked locally via `SharedPreferences` only while app was open | Fetch real history via `GET /api/music/recent/played` → Apple Music API |
| 5 | `getMusicUserToken()` used non-existent `_musicKit.userToken` getter | Wrong MusicKit API | Use `requestDeveloperToken()` → `requestUserToken(devToken)` |
| 6 | VAD scores missing | Gemini prompt didn't request them | Updated prompt to return 5-key JSON with `valence`, `arousal`, `dominance` |

---

## Alembic Migration

Required on the server to add VAD columns to `music_vibe_cache`:

```bash
# SSH into server
cd ~/application/projects/brain-dump/backend

# Activate venv
source venv/bin/activate

# Generate migration
python -m alembic revision --autogenerate -m "Add VAD to MusicVibeCache"

# Apply
python -m alembic upgrade head
```

> ⚠️ Use `python -m alembic`, NOT the system `alembic` binary from `apt`.

---

## TestFlight Testing Guide

### Test 1 — Auth Dot

1. Open app → Analytics tab → tap music icon
2. If **red**: tap Connect → approve Apple Music popup → dot turns **green instantly** (no reopen needed)

### Test 2 — Now Playing (live update)

1. Open bottom sheet
2. Start playing any song in Apple Music
3. Within **≤5 seconds** the sheet should show the "Now Playing" card + mood analysis
4. Tap `↺` to force-refresh immediately

### Test 3 — Recent History (not playing)

1. Play songs → stop music → open sheet
2. Sheet should show **"Based on your recent listening"** + vibe (not "Play a song…")

### Test 4 — Server logs to watch

```
GET /api/music/recent/played    → 200
POST /api/music/context          → 200
[MusicAnalyzer] Cache MISS       → Gemini call
[MusicAnalyzer] Cache HIT        → instant return
```

### Manual curl test (with real tokens from `debugPrint` logs):

```bash
curl -X GET "http://<server-ip>/api/music/recent/played" \
  -H "Authorization: Bearer <jwt>" \
  -H "Music-User-Token: <music-user-token>"
```

Expected:
```json
{
  "recent_songs": [
    {"title": "Blinding Lights", "artist": "The Weeknd"},
    ...
  ]
}
```
