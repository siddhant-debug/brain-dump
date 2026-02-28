---
**Tags:** #flutter #riverpod #architecture #backend #fastapi #braindump #RAG #SSE #minimialism
**Updated:** 2026-03-01
---

# 🧠 Project: Brain Dump (Context-Aware Knowledge Graph)

## 1. Abstract
"Brain Dump" is a minimalist, mobile-first application designed to solve the "Fragmented Attention" problem. The system utilizes a **Client-Server Architecture** with a modular **FastAPI** backend and a feature-first **Flutter** frontend. It features a sophisticated **Two-Stage RAG Pipeline** (Retrieval-Augmented Generation) with **Contextual Re-ranking** and **Streaming Responses** to provide near-instant, highly accurate cognitive assistance.

---

## 2. High-Level System Architecture
The system follows a modern **Three-Tier Architecture** upgraded for AI workloads:
1.  **Presentation Layer (Client):** Minimalist Flutter App handling caching, markdown rendering, and local streaming.
2.  **Application Layer (Server):** Modular FastAPI backend handling streaming (SSE), asynchronous RAG ingestion, and analytics orchestration.
3.  **Data Layer (Persistence):** PostgreSQL (metadata, histories) & ChromaDB Vector Store (`BAAI/bge-base-en-v1.5` embeddings) for semantic search.

### 🏛️ Master System Diagram

```mermaid
graph TD
    %% --- STYLING ---
    classDef client fill:#E3F2FD,stroke:#1565C0,stroke-width:2px,color:#0D47A1;
    classDef server fill:#E8F5E9,stroke:#2E7D32,stroke-width:2px,color:#1B5E20;
    classDef data fill:#FFF3E0,stroke:#EF6C00,stroke-width:2px,color:#E65100;
    classDef ext fill:#F3E5F5,stroke:#7B1FA2,stroke-width:2px,color:#4A148C,stroke-dasharray: 5 5;

    %% --- TIER 1: CLIENT (FLUTTER) ---
    subgraph Client_Layer ["📱 Presentation Layer (Flutter)"]
        direction TB
        UI_Input["Black Canvas <br> (Minimalist Input)"]:::client
        UI_Vault["Integrated Vault <br> (File Manager)"]:::client
        UI_Stream["Streaming Chat <br> (Real-time AI)"]:::client
        State_Mgmt["Riverpod State <br> (Streaming Notifier)"]:::client
        UI_Input & UI_Vault & UI_Stream --> State_Mgmt
    end

    %% --- TIER 2: SERVER (FASTAPI) ---
    subgraph Server_Layer ["⚡ Application Layer (FastAPI)"]
        direction TB
        API_Gateway["API Routers <br> (Auth, RAG, Analytics)"]:::server
        
        subgraph Core_Services
            Brain_Svc["RAG Engine <br> (Orchestrator)"]:::server
            Bkg_Tasks["Background Tasks <br> (Async Ingestion)"]:::server
        end
        
        subgraph AI_Services ["🧠 Intelligence Layer"]
            Retriever["Vector + BM25 <br> (Hybrid Search)"]:::server
            Reranker["Cross-Encoder <br> (Accurate Top-5)"]:::server
            LLM_Eng["Gemini Service <br> (Streaming Gen)"]:::server
        end
        
        API_Gateway --> Brain_Svc
        Brain_Svc --> Retriever --> Reranker --> LLM_Eng
        Brain_Svc --> Bkg_Tasks
    end

    %% --- TIER 3: DATA (PERSISTENCE) ---
    subgraph Data_Layer ["💾 Persistence Layer"]
        direction TB
        DB_Meta[("PostgreSQL <br> (Metadata, Analytics)")]:::data
        DB_Vector[("ChromaDB <br> (Embeddings)")]:::data
    end

    %% --- TIER 4: EXTERNAL (WORLD) ---
    subgraph External_Layer ["🌍 External APIs"]
        GMModels["Gemini API <br> (Streaming LLM)"]:::ext
    end

    %% --- DATA FLOWS ---
    State_Mgmt == "SSE / REST" ==> API_Gateway
    Bkg_Tasks -.-> DB_Vector
    Retriever -.->|"Query Vector"| DB_Vector
    LLM_Eng -.->|"Stream"| GMModels
```

---

## 3. Component Breakdown

### A. The Client (Flutter `lib/features/`)
- **Philosophy:** The "Black Canvas." A distraction-free surface for immediate thought capture.
- **Architecture:** Feature-first modular design (`feature_name/screens`, `feature_name/services`, `feature_name/providers`).
- **Core Features:**
    - **Streaming UI:** Uses `StreamBuilder` and `StateNotifier` to render AI responses chunk-by-chunk.
    - **Analytical Dashboard:** Synchronizes with backend `/analytics` endpoints to visualize cognitive loops and themes.
    - **Integrated Vault:** Embedded UI handling PDFs and markdown rendering seamlessly.

### B. The Server (FastAPI `backend/app/`)
- **Structure:** Modularized into `routers/` (controllers), `services/` (business logic), and `models/` (DB definitions).
- **Core Advantages:** High-concurrency async processing, separated thread pools (`ThreadPoolExecutor`) for heavy AI models, preventing event-loop blocking.
- **Gemini Singleton:** A centralized singleton service guarding system prompts, stripping prompt injection attempts, and handling SSE generator states safely.

### C. The Intelligence Pipeline (RAG)
1. **Stage 1 (Hybrid Retrieval):** Fuses BM25 (sparse keyword match) and Dense Vector search (`bge-base-en-v1.5`) via Reciprocal Rank Fusion (RRF).
2. **Context Layers:** Injects Temporal context, location heuristics, emotional tone, and associative memories.
3. **Stage 2 (Re-ranking):** Precise scoring via `ms-marco-MiniLM-L-6-v2` cross-encoder.
4. **Generation:** Streams response directly to frontend via SSE.

---

## 4. Current File Structure Map

```text
brain-dump/
├── backend/app/
│   ├── api/routers/        # Modular API (auth.py, rag.py, analytics.py)
│   ├── core/               # Setup (database config, rate limiter config)
│   ├── models/             # SQLAlchemy schemas (models.py)
│   ├── schemas/            # Pydantic validation (schemas.py)
│   └── services/           # Business logic (rag_engine.py, gemini_service.py)
│
└── frontend/lib/
    ├── core/               # Shared constants, theme, utility widgets
    ├── features/           # Modularized feature domains
    │   ├── analytics/      # Dashboard and charts
    │   ├── auth/           # Login/Registration
    │   ├── brain_dump/     # Core streaming & note capture
    │   ├── dock/           # Bottom navigation pill
    │   └── vault/          # Document management
    └── screens/            # Top-level coordinator pages
```

---

## 5. API Flow: The Streaming Query
> _Goal: Interaction Start < 500ms_
1. **User** types a question (e.g., "What did I note about Python?").
2. **Flutter (`BrainService`)** opens an SSE connection to `/chat/chat`.
3. **FastAPI (`routers/rag.py`)** persists message and delegates to `rag_engine`.
4. **RAG Engine** executes BM25 + Vector search, runs RRF fusion, and hydrates context.
5. **GeminiService** wraps query in secure XML tags and requests LLM generation.
6. **FastAPI** `yields` JSON chunks immediately back over the SSE connection.
7. **Flutter** updates UI in real-time.

---

## 6. Official Documentation References
- **Backend Infrastructure & API:** `documentation/backend/BACKEND.md`
- **Frontend Architecture:** `documentation/frontedn/FRONTEND.md`
- **Deep RAG Analytics & Systems:** `documentation/backend/rag/RAG_SYSTEM.md`
