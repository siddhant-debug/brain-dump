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
| 🎵 **Music Context** | Logs the Apple Music track playing at capture time. Replay the exact sonic environment of a thought. |
| 🫀 **Body Context** | HealthKit data (HRV, sleep, heart rate, steps, workouts) correlates physical state with note sentiment and creative output. |
| 🧠 **Active Recall** | A custom RAG engine connects past notes to current problems using hybrid semantic + keyword search across your docs and thoughts. |
| 🔮 **Smart Reminders** | Natural language reminder creation — just say "remind me to call mom tomorrow at 9am" and it's parsed by AI and added to native iOS Reminders. |
| 📂 **The Vault** | Upload PDFs, markdown, and text files into the knowledge graph. Built-in secure PDF viewer and markdown renderer. |

---

## 🏗️ Technical Architecture

### Multimodal RAG Pipeline

BrainDump's retrieval engine ingests two classes of content and enriches both with contextual signals:

**Corpus**
- **User Thoughts** — raw brain dumps, quick captures, voice-to-text entries
- **User Documents** — uploaded PDFs, markdown files, and text notes

**Contextual Signals (indexed alongside every entry)**
- `location` → GPS coordinates + resolved place name
- `timestamp` → time-of-day, day-of-week, recency decay weighting
- `music_context` → Apple Music track + artist at time of capture
- `health_context` → HRV, sleep score, heart rate, activity ring data from HealthKit
- `health_readiness` → AI-derived readiness label (HIGH / OPTIMAL / etc.) from biometric snapshot

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

### Smart Reminder Pipeline

```
User text input (natural language)
  │
  └─ Backend NLP endpoint (/api/nlp/parse-reminder)
        │  (Gemini-powered, timezone-aware parsing)
        └─ ReminderParseResult { action, triggerTime, recurrence }
              │
              └─ iOS EventKit (native MethodChannel)
                    └─ Reminder created in system Reminders app
```

### Asynchronous Infrastructure

- **Streaming UX:** Real-time generative feedback via **Server-Sent Events (SSE)** using FastAPI's `StreamingResponse`.
- **Background Tasks:** Embedding generation, BM25 index rebuilding, and document processing are offloaded via `FastAPI.BackgroundTasks` to ensure zero UI latency.
- **Upload Progress:** File uploads show a real-time progress bar with cancellation support.

---

## 🛠️ Tech Stack

### Mobile (Flutter)

- **Framework:** Flutter (Dart) — iOS-first
- **State Management:** Riverpod (`StateNotifierProvider`), feature-first architecture
- **Native Integrations:**
  - `CoreLocation` — GPS context at capture time
  - `Apple HealthKit` — biometric correlation (HRV, sleep, steps, HR, workouts)
  - `Apple Music / MusicKit` — playback context at capture time
  - `EventKit` — native iOS reminder creation via MethodChannel
- **Local Storage:** `flutter_secure_storage` for JWT tokens, `SharedPreferences` for app state flags
- **Networking:** Dio with SSE streaming support

### Backend (FastAPI)

- **API:** FastAPI (Python, async)
- **Database:** PostgreSQL + `pgvector` for vector embeddings
- **Search:** BM25 (sparse) + pgvector (dense) + RRF fusion
- **Reranking:** Cross-Encoder model for final scoring
- **AI:** OpenAI GPT-4o-mini + Groq Llama-3 + Gemini (NLP reminder parsing)
- **Streaming:** SSE via `StreamingResponse`
- **Deploy:** Docker Compose, self-hosted runner via GitHub Actions CI/CD

---

## 📱 How The App Works (For Real Users)

### 1. Home Screen — Your Live Dashboard

When you open BrainDump, you land on a **Circadian-aware home screen** that adapts to the time of day (dawn / day / dusk / night greetings). Here's what you see:

- **Live Context Pills** — a scrollable strip showing your real-time body data: steps walked today, current heart rate, active calories burned, and the music track currently playing (with a subtle pulse animation when it's live).
- **Readiness Row** — a derived readiness score calculated from your HealthKit biometrics (HRV, resting HR, sleep quality). Tells you whether to push hard or take it easy.
- **OmniBar** — a single input bar at the top. Type anything: a thought, a question, a reminder request, or a focus intention for the day.
- **Recent Notes** — your last 3 brain dumps shown in a vertical timeline with metadata tags (📍 location, 🎵 track, 🎯 focus mode, ⚡ readiness, 🕒 time).
- **Daily Gita Quote** — a daily philosophical prompt to anchor your morning.
- **Life Path Widget** — tracks your current life direction / focus area.
- **Dark/Light Theme Toggle** — switch between light and dark modes from the header.

### 2. Brain Tab — Dump & Retrieve

The **Brain tab** is your main interaction surface:

- **JOURNAL mode** (default) — captures a new thought. Every entry is auto-tagged with GPS location, current music track, and health readiness before being sent to the backend for embedding and storage.
- **CHAT mode** — tap the mode toggle to switch into RAG query mode. Ask anything — "What were my best ideas last month?", "Summarize what I've written about meditation" — and get a streaming AI answer grounded in your own notes and documents.

### 3. Insights Tab — Health & Music Telemetry

Swipeable two-page analytics dashboard:

- **Health Page** — shows HRV, resting heart rate, current heart rate, sleep breakdown (last night's sleep window, duration, quality), active energy burned, step count, and last workout. All data pulled live from HealthKit.
- **Music Page** — shows your MusicKit authorization state and current/recent track context logged at capture time.

### 4. Vault Tab — Your Knowledge Corpus

Upload documents into the knowledge graph:

- **Supported formats:** PDF, Markdown (`.md`), plain text (`.txt`)
- **PDF files** open in a full-screen secure PDF viewer.
- **Markdown files** render with a styled markdown viewer (code blocks, headers, etc.).
- **Search** your vault by filename.
- **Upload progress** is shown with a typewriter-style loading message and a cancellable progress bar.
- **Delete** any file with a confirmation dialog.
- Uploaded documents are embedded and indexed into the same RAG pipeline as your thoughts — so you can query across both.

### 5. Thoughts Tab — Browse All Notes

A full searchable list of every thought you've ever captured, with all context metadata visible. Tap any note to view its full detail screen.

### 6. Smart Reminders — Just Say It

From the Home OmniBar, type something like:

> *"Remind me to submit my report every Monday at 9am"*
> *"Remind me to drink water in 30 minutes"*

BrainDump sends this to a Gemini-powered NLP endpoint that extracts the action, time, and recurrence pattern. It then creates a **native iOS reminder** via EventKit — so it shows up in Apple Reminders and triggers a push notification at the right time.

---

## ✅ Roadmap

### Phase 1 — The Foundation

- [x] **Neural Onboarding:** \"Mad Libs\" style calibration — Energy, Mood.
- [x] **Location Context:** GPS metadata attached to every note at capture time.
- [x] **Adaptive Dashboard:** Home screen UI adapts to time of day (Circadian phases).
- [x] **Hybrid RAG Engine:** `pgvector` + BM25 + RRF + Cross-Encoder reranker.
- [x] **Streaming API:** Real-time SSE responses, async background processing.
- [x] **JWT Auth:** Secure login flow with `flutter_secure_storage` token caching.

### Phase 2 — The Senses

- [x] **Apple Music Integration:** Log the track playing at capture time. Live music pill on dashboard. Music page in Insights.
- [x] **HealthKit Sync:** HRV, sleep, heart rate, steps, active energy, workouts — all live on dashboard and Insights tab.
- [x] **Readiness Score:** Derived biometric readiness label shown on home screen and stored with every note.
- [x] **Document Vault:** Upload PDFs, markdown, and text into the knowledge graph. Secure PDF viewer + markdown renderer.
- [x] **Smart Reminders:** NLP-powered natural language → native iOS EventKit reminder creation, with recurrence support and timezone accuracy.
- [x] **Thoughts Screen:** Full browseable archive of all captured thoughts with context metadata.
- [x] **Dark / Light Theme:** Full Circadian color-system with smooth theme toggle.
- [x] **CI/CD Pipeline:** GitHub Actions with self-hosted runner, Docker deploy, and Flutter + backend test suites.
- [ ] **Temporal Query Engine:** Structured retrieval by time-of-day, day-of-week, or relative recency.
- [ ] **Vector Analytics:** Filter thoughts by location + mood state. *"Ideas I had at my desk when my HRV was low."*

### Phase 3 — The Brain

- [x] **Document Ingestion:** Upload PDFs and long-form docs into the knowledge graph alongside raw thoughts.
- [ ] **Graph View:** Visualize thoughts as an organic connected graph using Union-Find clustering.
- [ ] **Clarity Agent:** Nightly analysis to detect recurring conceptual loops and unresolved threads.
- [ ] **Kindle Sync:** Pull highlights directly into the knowledge graph.
- [ ] **Voice Input:** Tap a mic icon and speak your thought directly.
- [ ] **Widget / Live Activity:** iOS home screen widget for quick captures without unlocking.

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.x+
- Docker (Backend + DB)
- Python 3.10+
- iOS device (physical device recommended — HealthKit and MusicKit require real hardware)

### 1. Clone the Repo

```bash
git clone https://github.com/YOUR_USERNAME/brain-dump.git
cd brain-dump
```

### 2. Configure Environment

```bash
cd backend
cp .env.example .env
# Fill in: OPENAI_API_KEY, GROQ_API_KEY, GEMINI_API_KEY, DATABASE_URL, JWT_SECRET
```

### 3. Start the Backend

```bash
docker compose up --build
```

### 4. Run the App

```bash
cd mobile
flutter pub get
flutter run
```

> **Note:** On first launch, the app will request permissions for Location, HealthKit, Apple Music, and Reminders. Grant all for the full experience.

---

## 🗺️ The Big Picture

BrainDump is built on a single conviction: **context is memory**. The goal isn't just smarter search — it's reconstructing the full mental and physical state you were in when you had a thought, so you can meet that version of yourself again when it matters.

Every signal — where you were, when it was, what your body was doing, what was playing, what reminder you needed to set — is a thread. The RAG engine is how you pull them.
