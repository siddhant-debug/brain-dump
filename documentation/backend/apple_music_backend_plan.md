# Apple Music Backend Implementation Plan

## 1. Overview
The goal is to seamlessly integrate the user's Apple Music listening habits into the Brain Dump context window. By observing the current song (or the last 10 played songs if nothing is currently playing), we can determine the user's emotional tone and mindset (e.g., happy, sad, romance, work, gym) and inject this contextual knowledge into the RAG input prompt. 

## 2. API Endpoints (`app/api/routers/music.py`)

We need a dedicated endpoint to receive the music state from the Flutter frontend. 

**`POST /api/music/context`**
- **Purpose**: Receives the current playing status and song data from the mobile client.
- **Trigger**: Called by the Flutter app right before a user creates a new journal note or queries the RAG chat. Alternatively, it can be called periodically when the app is resumed.
- **Payload Schema**:
  ```json
  {
    "is_playing_now": true,
    "current_song": {
      "title": "Blinding Lights",
      "artist": "The Weeknd"
    },
    "recent_songs": [] // Array of up to 10 songs if is_playing_now is false
  }
  ```
- **Response**: Returns the analyzed emotional tone, which the frontend can optionally cache or display.

## 3. Music Analysis Service (`app/services/music_analyzer.py`)

Apple Music API does not natively provide "audio features" (like energy/valence) the way Spotify does. Therefore, we will use the Gemini LLM to classify the emotional tone based on the song title and artist. 

### A. Frontend to Backend Switch Logic
The Flutter frontend determines whether to send a single track or a list of recent tracks based on the active MusicKit playback state.
1. **Current Song (`is_playing_now: true`)**: The app sends only the currently playing track. Gemini will classify the immediate vibe of this single track (e.g., "They are literally listening to Hans Zimmer right now, they are deep in focus.").
2. **Last 10 Songs (`is_playing_now: false`)**: The app fetches the 10 most recently played tracks from MusicKit. Gemini analyzes the entire list to deduce the *overarching* mindset of the past few hours (e.g., "The last 10 tracks were all melancholic indie folk. They are in a highly reflective state.").

### B. LLM Prompt Design
We will create an internal helper function `analyze_music_tone(songs: list)` that prompts Gemini:
> *"Analyze the following song(s): {song_list}. What is the emotional tone, nature, and likely mindset of the listener? Choose primary categories such as: Happy, Sad, Romance, Work/Focus, Gym/High-Energy, Chill/Relaxed. Return a short JSON containing 'primary_tone' and a 'short_description'."*

### C. Persistent Caching Strategy (Cost Optimization)
To prevent hitting the Gemini API repeatedly for the exact same songs/playlists, we will build a PostgreSQL caching layer.
- **Table**: `music_vibe_cache` (Columns: `id`, `cache_key`, `primary_tone`, `short_description`, `updated_at`).
- **Cache Key Generation**: 
  - For a single song: `hash("Single:" + title + artist)`
  - For a 10-song list: `hash("List:" + sorted_list_of_titles_and_artists)`
- **Flow**: Before calling Gemini, the `music_analyzer` queries `music_vibe_cache` using the generated hash. On a cache miss, it calls Gemini, stores the result, and returns it. On a cache hit, it returns the vibe instantly (0 LLM cost).

## 4. RAG Engine Integration (`app/services/rag_engine.py`)

Once the backend has the parsed `music_context` (e.g., `{"primary_tone": "Gym/High-Energy", "short_description": "Upbeat pop and hip-hop"}`), we inject this directly into the existing `gemini_service.async_stream` by appending it to the `tone_layer` or passing it as a new contextual parameter.

### System Prompt Injection (`gemini_service.py`)
Update the `async_stream` and `_build_system_instruction` functions to accept an optional `music_layer`.

```python
# In rag_engine.py, build the music layer before calling the LLM:
music_layer = ""
if music_context:
    if music_context.get("is_playing_now"):
        music_layer = f"MUSIC CONTEXT: They are CURRENTLY playing '{music_context['current_song']}'. Tone: {music_context['primary_tone']} ({music_context['short_description']})."
    else:
        music_layer = f"MUSIC CONTEXT: Their recently played tracks have a '{music_context['primary_tone']}' vibe ({music_context['short_description']})."

# In gemini_service.py, the _SYSTEM_PROMPT incorporates it:
_SYSTEM_PROMPT = """\
You are the user's subconscious — their most honest, deeply supportive, and grounding friend.

CURRENT TIME CONTEXT:
{temporal_context}
{location_layer}
{music_layer}  <-- NEW INJECTION POINT

EMOTIONAL CONTEXT: {emotional_state}

HOW YOU THINK:
- Point out how their music matches or contradicts what they are saying.
- If they are listening to high-energy music, match that forward momentum.
- If they are listening to sad/reflective music, hold space and be gentle.
"""
```

## 5. Database Schema Additions

If we decide to persist the music context alongside quick notes (so the AI remembers what the user was listening to *when* they wrote the note):

Alter the `NOTE` table to include:
- `music_track` (string, nullable): E.g., "Blinding Lights - The Weeknd"
- `music_tone` (string, nullable): E.g., "Gym/High-Energy"

When a note is created (Flow B), the `POST /notes/` endpoint should accept optional `music_track` and `music_tone` arguments, binding the sensory state permanently to that memory.

## 6. Execution Flow Summary
1. **Frontend**: User opens app to chat. Native iOS MusicKit detects "Blinding Lights". 
2. **Frontend**: Sends `/api/music/context` with `is_playing_now: true`.
3. **Backend (`music_analyzer`)**: Computes hash for "Single:Blinding LightsThe Weeknd" and checks PostgreSQL `music_vibe_cache`. 
4. **Backend**: Cache miss. Calls Gemini JSON mode to categorize. Returns "Gym/High-Energy". Stores in DB cache.
5. **Frontend**: User types "I need to finish this project today."
6. **Backend (`rag_engine`)**: Retrieves relevant notes. Passes the music string into `gemini_service.async_stream` as the `{music_layer}`. 
7. **Gemini AI**: *"Blinding lights on repeat. You're already in execution mode. Stop circling the plan and just start typing. That tension in your chest is just unspent energy."*
