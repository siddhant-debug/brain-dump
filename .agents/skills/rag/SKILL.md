# 🧠 Skill: RAG (Retrieval-Augmented Generation + pgvector)

Use this skill whenever you're working on embeddings, vector search, retrieval, or the AI pattern-recognition features of BrainDumps.

---

## Stack
- **Vector DB**: PostgreSQL + pgvector extension
- **Keyword DB**: BM25 (In-memory per-user isolated dicts)
- **Embeddings**: `BAAI/bge-base-en-v1.5` via `SentenceTransformer`
- **Re-ranking**: `cross-encoder/ms-marco-MiniLM-L-6-v2`
- **Retrieval**: Hybrid Search (Cosine similarity + BM25) with Reciprocal Rank Fusion (RRF)
- **LLM**: `gemini-3-flash-preview` (via `google-generativeai`)
- **RAG logic lives in**: `backend/app/services/rag_engine.py`

---

## Core Concepts

### How Documents Flow Through RAG


```
User uploads file/text (rag.py `/upload-to-brain`)
      ↓
Semantic Chunking splits by Markdown headers OR RecursiveCharacterTextSplitter
      ↓
`BAAI/bge-base-en-v1.5` generates vector for each chunk
      ↓
Stored in PostgreSQL (`brain_embeddings` table) alongside BM25 indexing
      ↓
On user query (rag.py `/chat`) → Hybrid Search (BM25 + pgvector)
      ↓
Reciprocal Rank Fusion combines results → Cross-Encoder Re-ranks Top N
      ↓
GenerativeModel (gemini-3-flash-preview) builds context & streams SSE response
```


> ⚠️ If you change the embedding model, the vector dimension may change.
> This requires dropping and recreating the index AND re-embedding all existing entries.

---

## Chunking Rules

Current strategy in `index_text()`:
- **Markdown (.md)**: Uses `MarkdownHeaderTextSplitter` (splits on `#`, `##`, `###`) first to preserve header context, then `RecursiveCharacterTextSplitter` (chunk_size=500, overlap=50).
- **Other text (.txt, .json, etc)**: Uses `RecursiveCharacterTextSplitter` (chunk_size=500, overlap=50, split by `\n\n`, `\n`, `.`).
- **Metadata**: Stores `source`, `user_id`, `type`, `timestamp`, and mapped `location_context` (city, type, lat, long).

**Never change chunking without:**
1. Updating this doc
2. Ensuring `BM25` cache invalidator (`invalidate_bm25_cache`) is called.
---

## Adding a New RAG Feature

Examples: new query type, new pattern detection, new prompt

1. Identify which file to modify (`embedder`, `chunker`, `retriever`, or `prompts`)
2. If changing retrieval logic → update `retriever.py` and test similarity scores
3. If changing prompts → update `prompts.py` and run manual eval on 5+ entries
4. If changing embeddings → see "Changing Embedding Model" section below
5. Write or update tests in `tests/rag/`

---

## Retrieval Pattern

`retrieve_context()` uses a 3-stage process:
1. **Vector Search (Dense)**: pgvector `l2_distance` for top 20 candidates.
2. **Keyword Search (Sparse)**: BM25 `get_scores` for top 20 candidates.
3. **Reciprocal Rank Fusion (RRF)** & **Top-N Filtering**: Combines vector and BM25 scores, then typically a Cross-Encoder evaluates the final candidates (though cross-encoder step is toggled by `RERANKING_ENABLED`).

---

## Prompt Design Rules

- **GenerativeModel System Instructions**: Define personality (The Subconscious), time-awareness (Morning/Night), and location context dynamically.
- **Layers**: 
  - *Layer 1*: Time (Morning/Night context)
  - *Layer 2*: Emotional State Heuristic (High Cognitive Load vs Builders High)
  - *Layer 3*: Tone Guidance
  - *Layer 4*: True Subconscious Mirror Persona
  - *Layer 5*: Location Awareness
- Never output generic "Based on your notes...", always echo their vocabulary.

---

## Changing the Embedding Model

This is a high-risk operation (`get_emb_fn()` in `rag_engine.py`):

1. ✅ Back up the `brain_embeddings` table
2. ✅ Update `get_emb_fn()` with the new model (e.g., from BGE-base)
3. ✅ Update the vector dimension in the DB schema (`models.py`) + alembic migration
4. ✅ Drop and recreate the pgvector index with the new dimension
5. ✅ Write a script to re-embed all `StoredFile` plain texts
6. ✅ Update this skill doc with the new model name and dimension

---

## Testing RAG

Tests live in `tests/rag/`. RAG tests check:
- Retrieval returns relevant chunks (semantic accuracy)
- Embeddings are generated without error
- Pipeline produces a coherent response
- Edge cases: empty journal, very short entries, non-English text

```bash
cd backend && pytest tests/rag/ -v
```

For accuracy tests, compare similarity scores against a labeled set of query/expected-chunk pairs.
