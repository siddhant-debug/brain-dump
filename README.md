# 🧠 BrainDump: The Context-Aware Second Brain

> **"Your thoughts don't happen in a vacuum. Neither should your notes."**

---

## 💡 The Vision

Most note-taking apps are **digital graveyards**. You dump ideas in, and they disappear forever — stripped of the context that made them meaningful in the first place.

**BrainDump** is an **Agentic Knowledge Graph** that doesn't just store your text; it captures your **full State of Mind** at the moment of creation. Where you were. What your body was doing. What you were listening to. What time it was. Then it uses all of that to surface the right thought at the right moment.

---

## ✨ Core Capabilities

| Capability | Description |
|---|---|
| 📍 **Location Context** | GPS metadata anchors every note to a place. Retrieve by location, trigger memories geographically. |
| ⏱️ **Temporal Awareness** | Timestamps aren't just metadata — they're a retrieval axis. Find what you were thinking at 2am vs. during your morning walk. |
| 🎵 **Music Context** *(In Progress)* | Logs the Apple Music track playing at capture time. Replay the exact sonic environment of a thought. |
| 🫀 **Body Context** *(In Progress)* | HealthKit data (HRV, sleep, activity) correlates physical state with note sentiment and creative output. |
| 🧠 **Active Recall** | A custom RAG engine connects past notes to current problems using hybrid semantic + keyword search across your docs and thoughts. |
| 🔮 **Clarity Engine** | Pattern recognition detects when your thinking is scattered or looping, and surfaces structural focus suggestions. |

---

## 🏗️ Technical Architecture

### Multimodal RAG Pipeline

BrainDump's retrieval engine ingests two classes of content and enriches both with contextual signals:

**Corpus**
- **User Thoughts** — raw brain dumps, quick captures, voice-to-text entries
- **User Documents** — uploaded PDFs, notes, Kindle highlights *(future)*

**Contextual Signals (indexed alongside every entry)**
- `location` → GPS coordinates + resolved place name
- `timestamp` → time-of-day, day-of-week, recency decay weighting
- `music_context` → Apple Music track + artist at time of capture *(in progress)*
- `health_context` → HRV, sleep score, activity ring data from HealthKit *(in progress)*

**Retrieval Stack**

```
Query
  │
  ├─ Dense Vector Search (pgvector)     ← semantic similarity
  ├─ Sparse Keyword Search (BM25)       ← exact terms & proper nouns
  │
  └─ Reciprocal Rank Fusion (RRF)       ← merge ranked lists
        │
        └─ Cross-Encoder Reranker       ← final contextual scoring
              │
              └─ LLM Response           ← grounded, low-hallucination output
```

Contextual filters (location radius, time window, music session, health state) can be applied at any stage to constrain or boost retrieval — enabling queries like:

> *"What was I thinking about last Tuesday around midnight?"*
> *"Show me ideas I had at the office when my HRV was low."*
> *"What was I writing when I was listening to this album?"*

### Asynchronous Infrastructure

- **Streaming UX:** Real-time generative feedback via **Server-Sent Events (SSE)** using FastAPI's `StreamingResponse`.
- **Background Tasks:** Embedding generation, BM25 index rebuilding, and document processing are offloaded via `FastAPI.BackgroundTasks` to ensure zero UI latency.

---

## 🛠️ Tech Stack

### Mobile (Flutter)

- **Framework:** Flutter (Dart) — iOS-first
- **State Management:** Riverpod, feature-first architecture
- **Native Integrations:**
  - `CoreLocation` — GPS context at capture time
  - `Apple HealthKit` — biometric correlation *(in progress)*
  - `Apple Music / MusicKit` — playback context at capture time *(in progress)*
- **Local Storage:** Hive + SQLite for offline-first capability

### Backend (FastAPI)

- **API:** FastAPI (Python, async)
- **Database:** PostgreSQL + `pgvector` for vector embeddings
- **Search:** BM25 (sparse) + pgvector (dense) + RRF fusion
- **Reranking:** Cross-Encoder model for final scoring
- **AI:** OpenAI GPT-4o-mini + Groq Llama-3
- **Streaming:** SSE via `StreamingResponse`

---

## ✅ Roadmap

### Phase 1 — The Foundation

- [x] **Neural Onboarding:** "Mad Libs" style calibration — Energy, Mood.
- [x] **Location Context:** GPS metadata attached to every note at capture time.
- [x] **Adaptive Dashboard:** Home screen UI adapts to current energy level.
- [x] **Hybrid RAG Engine:** `pgvector` + BM25 + RRF + Cross-Encoder reranker.
- [x] **Streaming API:** Real-time SSE responses, async background processing.
- [x] **Documentation:** Full technical and integration docs.

### Phase 2 — The Senses *(In Progress)*

- [x] **Apple Music Integration:** Log the track playing at capture time. Retrieve by music session.
- [x] **HealthKit Sync:** Correlate HRV, sleep, and activity data with note sentiment and output quality.
- [ ] **Temporal Query Engine:** Retrieve notes by time-of-day, day-of-week, or relative recency.
- [ ] **Vector Analytics:** Filter by location + mood state. *"Ideas I had at the office when my HRV was low."*

### Phase 3 — The Brain

- [ ] **Document Ingestion:** Upload PDFs and long-form docs into the knowledge graph alongside raw thoughts.
- [ ] **Graph View:** Visualize thoughts as an organic connected graph using Union-Find clustering.
- [ ] **Clarity Agent:** Nightly analysis to detect recurring conceptual loops and unresolved threads.
- [ ] **Kindle Sync:** Pull highlights directly into the knowledge graph.

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.x+
- Docker (Backend + DB)
- Python 3.10+

### 1. Clone the Repo

```bash
git clone https://github.com/YOUR_USERNAME/brain-dump.git
cd brain-dump
```

### 2. Start the Backend

```bash
cd backend
docker compose up --build
```

### 3. Run the App

```bash
cd mobile
flutter pub get
flutter run
```

---

## 🗺️ The Big Picture

BrainDump is built on a single conviction: **context is memory**. The goal isn't just smarter search — it's reconstructing the full mental and physical state you were in when you had a thought, so you can meet that version of yourself again when it matters.

Every signal — where you were, when it was, what your body was doing, what was playing — is a thread. The RAG engine is how you pull them.
