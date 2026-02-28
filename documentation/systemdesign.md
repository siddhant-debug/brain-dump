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
1.  **Presentation Layer (Client):** Minimalist Flutter App handling state (Riverpod), Markdown rendering, and SSE streaming.
2.  **Application Layer (Server):** Modular FastAPI backend handling Auth, background RAG ingestion, and analytics orchestration.
3.  **Data Layer (Persistence):** PostgreSQL (metadata, analytics) & pgvector database (`BAAI/bge-base-en-v1.5` embeddings) for semantic search.

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
        UI_Vault["Integrated Vault <br> (Secure PDF/Views)"]:::client
        UI_Stream["Streaming Chat <br> (Real-time AI)"]:::client
        State_Mgmt["Riverpod State <br> (Providers)"]:::client
        UI_Input & UI_Vault & UI_Stream --> State_Mgmt
    end

    %% --- TIER 2: SERVER (FASTAPI) ---
    subgraph Server_Layer ["⚡ Application Layer (FastAPI)"]
        direction TB
        API_Gateway["API Routers <br> (Auth, RAG, Analytics, Vault)"]:::server
        
        subgraph Core_Services
            Brain_Svc["RAG Engine <br> (Orchestrator)"]:::server
            Bkg_Tasks["Background Tasks <br> (Async Ingestion)"]:::server
        end
        
        subgraph AI_Services ["🧠 Intelligence Layer"]
            Retriever["Vector + BM25 <br> (pgvector Hybrid)"]:::server
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
        DB_Meta[("PostgreSQL <br> (General Storage)")]:::data
        DB_Vector[("pgvector <br> (Embeddings)")]:::data
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
- **Architecture:** Organized strictly by feature (`lib/features/...`).
- **Core Active Features:**
    - **`brain_dump/`**: Core streaming Chat UI and transparent note capturing.
    - **`analytics/`**: Syncs with `/analytics` to visualize Dashboard loops, themes, and streaks.
    - **`vault/`**: Secure document management (view vectors, PDFs via syncfusion + token headers).
    - **`dock/`**: Main navigation cluster (Glassmorphism Pill).
    - **`music/`**: Spotify contextual data logic.
    - **`auth/` & `onboarding/`**: Core identity flow and JWT storage.

### B. The Server (FastAPI `backend/app/`)
- **Structure:** Modularized strictly by responsibility:
    - **`routers/`**: The endpoints (`auth.py`, `rag.py`, `analytics.py`, `files.py`, etc.).
    - **`services/`**: The abstracted logic (`rag_engine.py`, `gemini_service.py`).
    - **`models/` & `schemas/`**: Segregated DB models (SQLAlchemy) and Validation definitions (Pydantic).
- **Architecture Highlights:** Uses `ThreadPoolExecutor` to offload blocking tasks like Cross-Encoding and RRF logic, ensuring high-concurrency for the main FastAPI async loop.

### C. The Intelligence Pipeline (RAG Engine)
1. **Stage 1 (Hybrid Retrieval):** Fuses BM25 (sparse keyword) and Dense Vector search (Postgres L2 distance) via Reciprocal Rank Fusion (RRF).
2. **Context Layers:** Injects Temporal data, physical Location boundaries, emotional tone (via keyword analysis), and associative themes.
3. **Stage 2 (Re-ranking):** Precise semantic scoring via `ms-marco-MiniLM-L-6-v2` cross-encoder.
4. **Generation:** Securely streams via `GeminiService` directly back through the SSE pipeline.

---

## 4. Current File Structure Map

```text
brain-dump/
├── backend/app/
│   ├── api/routers/        # Modular API controllers
│   ├── core/               # Setup (database config, rate limiter config)
│   ├── models/             # SQLAlchemy schemas (models.py)
│   ├── schemas/            # Pydantic validation (schemas.py)
│   └── services/           # Business logic (rag_engine.py, gemini_service.py)
│
└── frontend/lib/
    ├── core/               # Shared constants, theme, utility widgets
    ├── features/           # Modularized feature domains
    │   ├── analytics/      # Dashboard and charts
    │   ├── auth/ & onboarding/ # Login/Registration
    │   ├── brain_dump/     # Core streaming & note capture
    │   ├── dock/           # Bottom navigation pill
    │   ├── music/          # Spotify contextual injection providers
    │   └── vault/          # Secure document management
    └── screens/            # Top-level coordinator pages (e.g. brain_dump_screen.dart)
```

---

## 5. Official Documentation References
To delve deeper into any isolated system, refer to the source documentation below:
- **Backend Documentation:** `documentation/backend/BACKEND.md`
- **Frontend Documentation:** `documentation/frontedn/FRONTEND.md`
- **RAG Architecture & Tuning:** `documentation/backend/rag/RAG_SYSTEM.md`
