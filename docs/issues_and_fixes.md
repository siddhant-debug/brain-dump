# BrainDump: Issues & Resolved Fixes

## Critical Fix Log (Q1 2026)

### 1. BM25 Cache Invalidation (Fixed March 10)
- **Problem**: The sparse retrieval index was being rebuilt on every request, causing 500ms+ delays in chat responses.
- **Fix**: Implemented `BM25Store` singleton with a dirty-set tracker. Rebuild now only occurs if `user_id` is in the `_bm25_dirty` set.
- **Lesson**: Ensure `user_id` types (int vs string) match exactly in cache keys to avoid "not found" misses.

### 2. HealthKit Redundancy (Fixed March 13)
- **Problem**: Rapid polling (every 5 mins) created thousands of near-duplicate `health_snapshots` with identical values, bloating the PostgreSQL database.
- **Fix**: 
  1. Added a **30-minute time floor** in the backend handler.
  2. Implemented **Significant Delta Guards**: Rows are only written if values change beyond thresholds (e.g., ΔSteps > 500, ΔHRV > 5ms).
  3. Added an **Immutable Unique Index** (`idx_health_snapshot_dedup`) to block race conditions.

### 3. RAG Response Truncation (Fixed March 1)
- **Problem**: Streaming responses sometimes cut off in the middle of a sentence due to Dio receive timeouts or LLM output limits.
- **Fix**: Adjusted `ReceiveTimeout` to 120s and implemented a recursive chunk-joining logic in the frontend to handle partial SSE frames.

### 4. Apple Music externally controlled playback (Fixed Feb 28)
- **Problem**: `playbackStatus` would often return `stopped` when the user controlled music via lock screen or watch.
- **Fix**: Derived `isPlaying` state from whether `queue.currentEntry` is not null, providing more reliable state tracking for context injection.

### 5. pgvector "functions in index expression must be marked IMMUTABLE" (Fixed March 13)
- **Problem**: Alembic migrations failed when creating unique indexes using `date_trunc` on timestamps without explicit timezone casting.
- **Fix**: Used `date_trunc('minute', fetched_at AT TIME ZONE 'UTC')` to satisfy PostgreSQL's deterministic index requirements.
