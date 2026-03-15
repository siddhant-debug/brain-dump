# BrainDump Backend Documentation

## 1. Architecture Overview
The BrainDump backend is a FastAPI application designed for high-concurrency RAG workloads and context-aware data processing.

### Tech Stack
- **Web Framework**: FastAPI
- **Database**: PostgreSQL with `pgvector`
- **ORM**: SQLAlchemy 2.0
- **Migrations**: Alembic
- **RAG**: Hybrid search (Dense Vector + rank_bm25)
- **AI Models**: 
  - Text Embedding: `BAAI/bge-base-en-v1.5` (BAAI/bge-small-en-v1.5 also used in some contexts)
  - Reranking: `cross-encoder/ms-marco-MiniLM-L-6-v2`
  - Generation: Gemini 1.5 Flash (via `google-genai`)
- **Authentication**: JWT (HS256) with 30-minute rotation.

## 2. Router Directory
Endpoints are modularized for clarity:
- `rag.py`: Chat interface, file uploads/indexing, and SSE management.
- `files.py`: Basic file management (listing, downloading) and secure vault access.
- `music.py`: Apple Music integration and emotional context analysis.
- `notes.py`: Lifecycle of raw captures and background analysis.
- `health.py`: Synchronizes HealthKit snapshots with backend-driven deduplication.
- `analytics.py`: Complex data processing for dashboards (strains, loops, themes).
- `auth.py`: Secure login/signup and JWT state management.

## 3. Database Schema
Managed via SQLAlchemy Models in `app/models/models.py`.

### Primary Tables:
- `users`: Core profile, identity, and global directives.
- `notes`: Raw thought captures with sentiment/category tagging.
- `stored_files`: Metadata for PDFs/documents uploaded to the Brain.
- `brain_embeddings`: Dense vector chunks (768d) for RAG.
- `health_snapshots`: Per-minute/cached biometric data (HRV, Steps, etc.).
- `chat_messages`: Full history of user-AI interactions with cited context.
- `detected_loops`: Clustered thought patterns identifying recurring psychological loops.

## 4. The RAG Pipeline
Optimized for retrieval accuracy and minimal rebuild overhead.

### Hybrid Retrieval
- **Step 1: Dense Retrieval**: ANN search on pgvector using L2 distance.
- **Step 2: Sparse Retrieval**: Keyword match using `BM25Store` (singleton management).
- **Step 3: Fusion**: Results combined via Reciprocal Rank Fusion (RRF).
- **Step 4: Reranking**: Top-N candidates scored by a Cross-Encoder.

### BM25 Persistence
The BM25 index is cached per user and rebuilt lazily only when significant new data is indexed, preventing expensive initialization on every request.

## 5. Sensory Context Signals
The backend enriches RAG prompts with non-textual data from the mobile client:
- **Temporal**: Awareness of time of day and proximity to capture events (e.g., "2:00 AM on a Tuesday").
- **Physiological (HealthKit)**: Latest Health snapshots are injected.
    - Includes: Readiness score, Steps, HRV (Heart Rate Variability), and Resting Heart Rate.
    - *Purpose*: Grounds responses in the user's physical state (e.g., suggesting rest if HRV is low).
- **Music (MusicKit)**: Derives "mood vibes" using VAD (Valence, Arousal, Dominance) vectors.
    - Translates raw music data into human-readable emotional signals (e.g., "Energized/Intense").
    - Includes current track title and artist if playback is active.
- **Location**: Metadata injection of city, location type (Office/Home), and coordinates.

## 6. Development & Operations
- **Environment**: Configuration via `.env`.
- **Background Tasks**: Uses `FastAPI.BackgroundTasks` for non-blocking indexing and analysis.
- **Rate Limiting**: `slowapi` protects authentication and RAG endpoints.
