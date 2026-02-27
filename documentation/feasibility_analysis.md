# HealthKit & MusicKit Integration: Feasibility Analysis & Plan

## 1. FRONTEND (Flutter)

### Packages & Libraries
- **Health Data**: The [health](https://pub.dev/packages/health) package (v13.3.1+) is the gold standard in Flutter. It abstracts both **Apple HealthKit** (iOS) and **Health Connect** (Android), providing a unified API.
- **Music Data**: The [music_kit](https://pub.dev/packages/music_kit) package (v1.3.0+) provides a Flutter bridge for the native Apple MusicKit SDK (iOS and macOS). 

### Cross-Platform Handling
- **Android Health**: The `health` package uses Google's Health Connect on Android. The user experience is nearly identical to HealthKit.
- **Android Music**: `music_kit` is iOS/macOS only. For Android, you would need to rely on the Spotify API or Apple Music REST API, which requires web-based OAuth. Alternatively, limit music context to iOS for V1.

### Data Availability
- **Health**: Steps, Heart Rate, HRV, Workouts, Sleep Analysis, Blood Oxygen, Active Energy Burned.
- **Music**: Recently played items, currently playing item, heavy rotation, and library playlists.

### Permissions & Entitlements
- **iOS (Xcode)**:
  - Add `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` in `Info.plist`.
  - Add HealthKit capability in Xcode entitlements.
  - Add `NSAppleMusicUsageDescription` in `Info.plist`.
  - Add MusicKit capability in Xcode entitlements.
- **Android**:
  - Add Health Connect read/write permissions in `AndroidManifest.xml`.

---

## 2. BACKEND (FastAPI & PostgreSQL)

### API Endpoints Needed
- `POST /api/health/sync`: Receives an array of health data points (type, value, start_time, end_time, source).
- `POST /api/music/sync`: Receives recently played tracks (title, artist, genre, played_at).

### Database Modeling (PostgreSQL)
We should create new regular telemetry tables to store raw data.
- **`health_metrics`**: `id`, `user_id`, `metric_type` (enum), `value` (float), `unit`, `start_time`, `end_time`.
- **`music_history`**: `id`, `user_id`, `track_name`, `artist`, `genre`, `played_at`.

### Sync Frequency
- **On-Open / Background**: Real-time sync is heavily restricted by iOS battery optimization. The app should trigger a sync immediately on `AppLifecycleState.resumed` (when the user opens the app). We can also schedule a background sync using `workmanager`, but it only runs when the OS allows it (approx. every 15-30 mins max).

### Apple API Rate Limits
- HealthKit data is fetched locally on the device, so avoiding API limits entirely. We only rate-limit our own backend's `/sync` endpoints.
- MusicKit fetching is done via the developer token and user token. Apple imposes reasonable rate limits for the Music API, but since the Flutter app makes the request client-side using native MusicKit, limits are handled gracefully per user device.

---

## 3. RAG INTEGRATION (pgvector Contextual Layer)

### Embedding Strategy
Raw time-series data is terrible for LLM context. We should NOT embed every individual heartbeat or step. Instead, we generate and embed **Time-Boxed Summaries**.
FastAPI can run a daily cron job (or an on-sync trigger) that summarizes the day:
> *"December 5: Walked 8,500 steps. Sleep was poor (5.5 hours). Rested heart rate was slightly elevated at 72 bpm. Listened heavily to melancholy indie folk (Bon Iver, Phoebe Bridgers)."*

### ChromaDB / pgvector Architecture
- **Collection Strategy**: Merge into the **existing `brain_storage` / main pgvector table**! Do not create a separate collection. The power of RAG comes from cross-referencing notes with context.
- **Metadata Schema**:
  ```json
  {
    "type": "daily_summary",
    "source": "health_music_pipeline",
    "date": "2026-12-05"
  }
  ```

### Retrieval (`rag_engine.py`)
Because the metadata includes `"type": "daily_summary"` and `"date"`, the RAG engine can do hybrid filtering. 
When the user asks: *"How have I been feeling this week?"*
1. LLM extracts the time filter (Last 7 days).
2. `rag_engine` queries pgvector for vectors relating to "feeling, mood, health" WHERE `date >= [7 days ago]`.
3. The LLM gets both journal notes AND health/music summaries from the context window, seamlessly fusing them for the answer.

---

## 4. FEASIBILITY & RISKS

### App Store Review Risks
Apple is notoriously strict with HealthKit and MusicKit usage.
- **Risk**: App rejected for not providing "health or fitness benefits".
- **Mitigation**: The app's privacy policy and App Store description MUST explicitly state that the AI uses health/music data to provide "holistic well-being insights and personalized journaling reflection". Do NOT use the data for anything else.

### Privacy / HIPAA
- Since you are storing HealthKit data on a remote Postgres server, you are handling highly sensitive PII.
- You are likely not a covered entity under HIPAA (unless working with doctors/insurance), but regardless, you **must** encrypt the data at rest, secure the API endpoints, and provide a permanent "Delete My Data" feature. 

---

## RECOMMENDED PHASED IMPLEMENTATION PLAN

### Phase 1: Infrastructure & Core Health Sync
1. Add `health` package to Flutter, configure iOS/Android permissions.
2. Build FastAPI `health_metrics` tables and the `POST /api/health/sync` endpoint.
3. Implement `AppLifecycleState.resumed` data push in Flutter.

### Phase 2: RAG Summarization Pipeline
1. Create a FastAPI background task that runs at EOD (or on first sync of a new day) to generate a text summary of the previous day's health metrics.
2. Embed this summary string into the pgvector brain using `rag_engine.py`.
3. Test retrieval with queries like *"How did I sleep yesterday?"*

### Phase 3: MusicKit Integration (iOS Only)
1. Add `music_kit` package to Flutter and configure Apple Developer portal keys.
2. Build FastAPI `music_history` table and sync endpoints.
3. Update the daily summarization task (Phase 2) to include music listening trends.

### Phase 4: Android Parity & Background Sync
1. Add Android Health Connect logic (handled mostly by the `health` package).
2. Look into Spotify API integration for Android users (optional).
3. Implement `workmanager` for silent background data syncs to keep the brain up-to-date even when the app is closed.
