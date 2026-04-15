# RAG Deep Dive: The Brain Engine

## 1. Overview
The "Brain Engine" is the heart of BrainDump, a Two-Stage Hybrid RAG pipeline designed for precision and low-latency interaction. It blends sparse keyword search with dense semantic retrieval, followed by a cross-encoder reranking stage.

## 2. Hybrid Retrieval Architecture

### Stage 1: Parallel Candidates
- **Dense Retrieval (Semantic)**: Uses `BAAI/bge-base-en-v1.5` embeddings stored in `pgvector`. It captures semantic meaning (e.g., "how to deploy" matches "installation steps").
- **Sparse Retrieval (Keyword)**: Uses `rank_bm25` with a custom persistent index. It captures exact terms (e.g., specific library names or technical IDs).

### Stage 2: Fusion (RRF)
We use **Reciprocal Rank Fusion (RRF)** to combine the ranked lists from both sources. This ensures the engine doesn't bias strictly towards semantic or keyword results, but rather finds the intersection.

```python
# RRF Logic Simplified
score = (1 / (rank_vector + K)) + (1 / (rank_bm25 + K))
```

### Stage 3: Contextual Reranking
The top 10 fuzed candidates are passed to a **Cross-Encoder** (`ms-marco-MiniLM-L-6-v2`). Unlike Bi-Encoders, the Cross-Encoder processes the (Query, Document) pair simultaneously, providing a much higher accuracy score for final selection.

## 3. Persistent BM25 Caching
One of the core optimizations is the `BM25Store`. 
- **The Problem**: Pre-computing a BM25 index for every request is expensive for many documents.
- **The Solution**: A per-user persistent index stored on disk that is lazily invalidated ONLY when new notes/files are added. The index is stored in RAM via an LRU cache for the current session.

## 4. Chunking & Ingestion
- **Splitting**: `RecursiveCharacterTextSplitter` from LangChain.
- **Size**: 500 characters with a 100-character overlap to maintain context across boundaries.
- **Cleaning**: Automated removal of binary artifacts and excessive whitespace before indexing.

## 5. Sensory Injection
Before sending the context to Gemini, we inject "Sensory Markers":
- **Time**: "It's 2 AM on a Tuesday." (Injected as `{datetime.now().strftime('%B %d, %Y')}`).
- **Music (VAD Vector)**: Translates raw Valence, Arousal, and Dominance scores into human-readable states.
    - Example: "Emotional state: very positive/joyful mood, energized/intense, feeling confident/in-control."
    - Includes `current_song` or "recent vibe" if playback is stopped.
- **Health (Biometrics)**: Pulls the latest per-minute or cached snapshot.
    - Includes `readiness` score, `steps_today`, `active_energy_kcal`, `Resting HR`, and `HRV`.
- **Location**: Injects `city`, `location_type` (e.g., "Office", "Home"), and coordinates.

This metadata allows Gemini to make connections like: "You're at the office late again—your HRV is low and you've been listening to melancholic tracks. Last time this happened, you were stuck on the RAG optimization notes."

## 6. Response Generation
- **Source Attributions**: The engine returns source citations in the SSE trail so the user can verify the information in "The Vault".
- **Streaming**: Implemented via FastAPI's `StreamingResponse` using Server-Sent Events (SSE).
