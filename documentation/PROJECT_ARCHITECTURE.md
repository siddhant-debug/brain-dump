# Brain Dump - Project Architecture & Memory

> **System Identity**: A "Second Brain" application with a "Subconscious" persona.
> **Core Philosophy**: Minimalist "Black Canvas" UI + RAG-powered "Internal Monologue".

## 🏗 System Overview

| Component | Tech Stack | Key Responsibilities |
|-----------|------------|----------------------|
| **Frontend** | Flutter, Riverpod | UI, State Management, Streaming Chat, Local Cache |
| **Backend** | FastAPI, Python | API, RAG Pipeline, Auth, File Processing |
| **Vector DB** | ChromaDB | Embeddings (`BAAI/bge-base-en-v1.5`), Storage |
| **AI Model** | Gemini 1.5 Flash | Thinking, Synthesis, Persona Generation |

---

## 🧠 Backend Architecture (`backend/`)

### 1. The RAG Engine ([rag_engine.py](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/rag_engine.py))
The "Brain" uses a sophisticated hybrid search pipeline:
*   **Indexing**: 
    *   **Markdown**: Semantic splitting by headers (#, ##, ###) to preserve context.
    *   **Other**: Recursive character splitting (500 chars, 50 overlap).
    *   **Embeddings**: `BAAI/bge-base-en-v1.5` (State-of-the-art for size).
*   **Retrieval Pipeline**: 
    1.  **Vector Search**: Dense retrieval (top 20).
    2.  **Keyword Search**: BM25 Sparse retrieval (top 20).
    3.  **Hybrid Fusion**: Reciprocal Rank Fusion (RRF) to combine results.
    4.  **Re-Ranking**: `cross-encoder/ms-marco-MiniLM-L-6-v2` re-ranks top candidates for semantic relevance.
*   **"Subconscious" Logic**:
    *   **Associative Memory**: Proactively searches for themes (Ambition, Anxiety, Health) even if not explicitly asked.
    *   **Temporal Context**: Injects time-of-day and closeness to important dates (e.g., Birthday Feb 23).
    *   **Emotional Analysis**: Detects sentiment (TextBlob) to adjust response tone (Gentle vs. Energetic).

### 2. The API Router ([rag_router.py](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/rag_router.py))
*   `POST /chat/upload-to-brain`: 
    *   Accepts PDF/Text/Code.
    *   Extracts text (OCR or read).
    *   Indexes into ChromaDB.
    *   Stores metadata in SQLite (`StoredFile`).
*   `POST /chat/chat`: 
    *   **Streaming SSE** endpoint.
    *   Pipeline: History Save -> Async Search -> Stream AI -> History Save.
    *   Returns chunks + final sources list.

### 3. File Handling
*   **PDF**: Processed with `PyPDF2`.
*   **Text/Code**: Native read.
*   **Storage**: Text content stored in DB (`content_text`), Binary files stored in `backend/uploads`.

---

## 📱 Frontend Architecture (`lib/`)

### 1. Core Services
*   **BrainService** (`brain_service.dart`):
    *   `askBrain(query)`: Manages SSE connection, parses `data: {json}` chunks, handles timeouts.
    *   `saveNote(content)`: Multipart upload.
*   **BrainDumpNotifier** (`brain_dump_provider.dart`):
    *   **State Machine**: Manages `messages`, `isProcessing`, `error`.
    *   **Smart Input**: 
        *   Ends with `?` -> **Query Mode** (Streams AI response).
        *   No `?` -> **Note Mode** (Save silently or with "Memorized ✓" feedback).

### 2. UI / UX Philosophy
*   **Screen**: `BrainDumpScreen` ("Black Canvas").
*   **Aesthetics**: Pure black (`#000000`), minimalistic, terminal-like but modern.
*   **Components**:
    *   **Collapsible Sources**: Option B (Default) - "↓ sources" expands to chips.
    *   **Animated Hint**: Breathing "start typing..." text.
    *   **Message Row**: No bubbles, avatar-based, markdown support.

---

## 🔑 Key Workflows

### The "Subconscious" Interaction
1.  **User Query**: "Why am I tired?"
2.  **Backend Retrieval**:
    *   Finds notes on "sleep", "gym", "work stress".
    *   *Associative*: Finds notes on "anxiety" (conceptually related).
    *   *Context*: "It is late night."
3.  **Persona Generation**:
    *   System Prompt: "You are his subconscious. Be direct. No AI fluff."
    *   Tone: "Late night, reflective."
4.  **Response**: "You haven't slept before 1am in a week. And that anxiety about the launch is draining you more than the gym."
5.  **Frontend**: Streams token-by-token for "thought" effect.

### The "Memory" Interaction
1.  **User Input**: "Meeting with Sarah at 2pm." (No `?`)
2.  **Frontend**:
    *   Shows "Memorizing..." placeholder.
    *   Sends to `saveNote`.
3.  **Backend**:
    *   Indexes text.
4.  **Frontend**:
    *   Updates to "Memorized ✓".
    *   Fades out after 1.5s (keeping canvas clean).

---

## 📁 File Structure Map
```
brain-dump/
├── backend/
│   ├── main.py             # Entry point
│   ├── rag_engine.py       # The Brain (Chroma + Logic)
│   ├── rag_router.py       # API Endpoints
│   └── brain_storage/      # Vector DB Data
├── lib/
│   ├── main.dart           # App Entry
│   ├── features/
│   │   └── brain_dump/
│   │       ├── services/   # API Layer
│   │       ├── providers/  # State Layer
│   │       └── models/     # Data Models
│   └── screens/
│       └── brain_dump_screen.dart # Main UI
```
