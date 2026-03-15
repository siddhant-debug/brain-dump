# BrainDump API Reference

## 1. Authentication (`/auth`)
All authenticated endpoints require a `Bearer <JWT>` token in the `Authorization` header.

### `POST /auth/signup`
- **Body**: `email`, `password`, `full_name`
- **Response**: User object metadata.

### `POST /auth/login`
- **Body**: `email`, `password`
- **Response**: `access_token`, `token_type` (bearer).

---

## 2. Brain & RAG (`/chat`)

### `POST /chat/chat` (Streaming)
The core endpoint for subconscious queries.
- **Body**: `{ "query": "string", "location": { "lat": float, "lng": float }, "music": { "playing": bool, "track": "..." } }`
- **Response**: SSE stream of chunks with final `sources` block.

### `POST /chat/upload-to-brain`
Uploads and indexes a file into the RAG system.
- **Form-Data**: `file` (multipart)
- **Response**: Processing status check.

---

## 3. File Management (`/files`)

### `GET /files/`
Lists all user files stored in the DB (metadata only).

### `GET /files/{file_id}`
Retrieves file content or binary response for download.

### `GET /files/vault/documents/{doc_id}`
Securely retrieves a document from the vault via `vault_service`.

---

## 4. Notes Lifecycle (`/notes`)

### `POST /notes/`
Creates a raw note capture. Triggers background analysis for sentiment and category.
- **Body**: `{ "content": "string" }`

### `GET /notes/`
Lists user notes with automatic pagination support.

---

## 5. Music Context (`/api/music`)

### `GET /api/music/recent/played`
Fetches user's 10 most recently played tracks from Apple Music.
- **Header**: `Music-User-Token` (required).

### `POST /api/music/context`
Analyzes current music for emotional tone and VAD mood vectors.
- **Body**: `MusicContextRequest`.

---

## 6. Sensory Sync (`/api/health`)

### `POST /api/health/context`
Syncs HealthKit snapshots from the mobile client.
- **Guards**: Backend-driven deduplication ensures writes only happen for significant changes or >30 min intervals.
- **Metrics**: Heart Rate, HRV, Steps, Active Energy.

### `GET /api/health/latest`
Returns the most recent health snapshot for the user.

---

## 7. Analytics & Insights (`/analytics`)

### `GET /analytics/consistency`
Returns streak data and a 30-day activity heatmap.

### `GET /analytics/loops`
Identifies recurring similar thoughts using vector clustering.
- **Insight**: Highlights "Negative Spirals" or "Obsessive Loops".

### `GET /analytics/themes`
Categorical distribution of thoughts (e.g., 40% Work, 20% Health).

---

## 8. Error Reference
- **401 Unauthorized**: Token expired or invalid. Client must re-authenticate.
- **429 Too Many Requests**: Rate limit reached (configured per-user).
- **500 Internal Server Error**: Usually related to LLM connectivity or VDB timeouts.
