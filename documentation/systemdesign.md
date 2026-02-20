
---
**Tags:** #flutter #riverpod #architecture #state-management #backend #fastapi #braindump #RAG #SSE #minimialism
**Related:** [[RAG_RERANKING_IMPLEMENTATION.md]][[FRONTEND.md]][[Brain Dump Backend Documentation]]
**Updated:** 2026-02-16
---

#  🧠 Project: Brain Dump (Context-Aware Knowledge Graph)

## 1. Abstract
"Brain Dump" is a minimalist, mobile-first application designed to solve the "Fragmented Attention" problem. The system utilizes a **Client-Server Architecture** with a high-performance **FastAPI** backend and a **Flutter** frontend. It features a sophisticated **Two-Stage RAG Pipeline** (Retrival-Augmented Generation) with **Contextual Re-ranking** and **Streaming Responses** to provide near-instant, highly accurate cognitive assistance.

---

## 2. Problem Statement
* **The Issue:** Human thoughts are non-linear and context-dependent. Traditional tools (Notion, Notes) force linear structure, causing friction during the "capture" phase.
* **The Consequence:** "Blank Page Paralysis" and lost ideas because the context is lost.
* **The Solution:** A "Black Canvas" interface that reduces capture friction to zero, supports streaming AI dialogue, and utilizes advanced RAG to surface relevant context precisely when needed.

---

## 3. High-Level System Architecture
The system follows a modern **Three-Tier Architecture** upgraded for AI workloads:
1.  **Presentation Layer (Client):** Minimalist Flutter App using a "Black Canvas" design.
2.  **Application Layer (Server):** FastAPI handling streaming (SSE) and background ingestion.
3.  **Data Layer (Persistence):** PostgreSQL for structured data & Vector Store for semantic search.

### 🏛️ Master System Diagram
*Visualizing the flow from Raw Thought to Ranked Context.*

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
        
        subgraph UI_Components
            UI_Input["Black Canvas <br> (Minimalist Input)"]:::client
            UI_Vault["Integrated Vault <br> (File Manager)"]:::client
            UI_Stream["Streaming Chat <br> (Real-time AI)"]:::client
            UI_Dock["Pill Dock <br> (Navigation)"]:::client
        end
        
        State_Mgmt["Riverpod State <br> (Streaming Notifier)"]:::client
        
        UI_Input --> State_Mgmt
        UI_Vault --> State_Mgmt
        UI_Stream --> State_Mgmt
        UI_Dock -.-> UI_Input
        UI_Dock -.-> UI_Vault
    end

    %% --- TIER 2: SERVER (FASTAPI) ---
    subgraph Server_Layer ["⚡ Application Layer (FastAPI)"]
        direction TB
        API_Gateway["API Gateway <br> (Streaming SSE)"]:::server
        
        subgraph Core_Services
            Auth_Svc["Auth Service <br> (JWT)"]:::server
            Brain_Svc["Brain Service <br> (Orchestrator)"]:::server
            Bkg_Tasks["Background Tasks <br> (Async Ingestion)"]:::server
        end
        
        subgraph AI_Services ["🧠 Intelligence Layer"]
            Retriever["Bi-Encoder Retriever <br> (Fast Top-10)"]:::server
            Reranker["Cross-Encoder Reranker <br> (Accurate Top-3)"]:::server
            LLM_Eng["Gemini Engine <br> (Streaming Gen)"]:::server
        end
        
        API_Gateway --> Auth_Svc
        API_Gateway --> Brain_Svc
        Brain_Svc --> Retriever
        Retriever --> Reranker
        Reranker --> LLM_Eng
        Brain_Svc --> Bkg_Tasks
    end

    %% --- TIER 3: DATA (PERSISTENCE) ---
    subgraph Data_Layer ["💾 Persistence Layer"]
        direction TB
        DB_Meta[("PostgreSQL <br> (Metadata)")]:::data
        DB_Vector[("Chroma/pgvector <br> (Embeddings)")]:::data
        DB_Blob["Local Storage <br> (/uploads)"]:::data
    end

    %% --- TIER 4: EXTERNAL (WORLD) ---
    subgraph External_Layer ["🌍 External APIs"]
        GMModels["Gemini API <br> (Streaming LLM)"]:::ext
        HFModels["HuggingFace <br> (Cross-Encoder)"]:::ext
    end

    %% --- DATA FLOWS ---
    State_Mgmt == "SSE / Text Stream" ==> API_Gateway
    Brain_Svc -.->|"Async Write"| Bkg_Tasks
    Bkg_Tasks -.-> DB_Blob
    Retriever -.->|"Query Vector"| DB_Vector
    LLM_Eng -.->|"Stream"| GMModels
````

---

## 4. Component Breakdown

### A. The Client (Flutter)
- **Role:** The "Black Canvas." A distraction-free surface for immediate thought capture.
- **Key Features:**
    - **Streaming UI:** Uses `StreamBuilder` and `StateNotifier` to render AI responses word-by-word.
    - **Integrated Vault:** Embedded within `IndexedStack` for seamless context switching without navigation overhead.
    - **Pill Dock:** A blurring glassmorphism UI for high-level navigation (Home, Vault, Settings).

### B. The Server (FastAPI)
- **Role:** The "Cognitive Orchestrator."
- **Why FastAPI?** Native support for `StreamingResponse` and `BackgroundTasks` allows for high-concurrency file processing and low-latency AI response starts (<500ms).
- **Two-Stage RAG Pipeline:**
    1.  **Stage 1 (Retrieval):** Uses bi-encoders to quickly find the top 10 relevant documents.
    2.  **Stage 2 (Re-ranking):** Uses a Cross-Encoder to precisely rank the top 3 items to provide as context to the LLM.

### C. The Intelligence Layer (AI Services)
- **Bi-Encoder (`all-MiniLM-L6-v2`):** Fast vector search for initial candidates.
- **Cross-Encoder (`ms-marco-MiniLM-L-6-v2`):** Deep relevance analysis.
- **SSE Streamer:** Pushes JSON chunks to the client as they are generated by Gemini.

---

## 5. Critical Data Flows

### Flow 1: The "Streaming Query" (AI Dialogue)
> _Goal: Interaction Start < 500ms_
1. **User** types a question (e.g., "What did I note about Python?").
2. **Flutter** opens an SSE connection to `/chat`.
3. **FastAPI** performs Two-Stage RAG (Retrieve -> Re-rank).
4. **Gemini** generates response while **FastAPI** `yields` chunks immediately.
5. **Flutter** updates the UI in real-time.

### Flow 2: The "Background Ingestion" (File Upload)
> _Goal: Zero UI Blocking_
1. **User** uploads a PDF/Note.
2. **FastAPI** saves the file and immediately returns a `202 Accepted`.
3. **BackgroundTasks** triggers the processing: text extraction, chunking, and vector embedding.
4. **Result:** The UI remains responsive while the "Brain" grows in the background.

---

## 6. Future Roadmap (Updated)

- **Phase 1 (Complete):** Basic CRUD Capture & File Storage.
- **Phase 2 (Current):** **Contextual Optimization**. Implementing Two-Stage RAG, Streaming Responses, and "Black Canvas" UI.
- **Phase 3 (Next):** **Neural Visualization**. Transforming ranked vectors into an interactive knowledge graph using force-directed graphs.
- **Phase 4 (Future):** **Multi-Modal Context**. Integrating voice and spatial data for 360-degree memory rebuilding.

---

**References:**
- [[RAG_RERANKING_IMPLEMENTATION.md]]
- [[FRONTEND.md]]
- [[BACKEND.md]]
