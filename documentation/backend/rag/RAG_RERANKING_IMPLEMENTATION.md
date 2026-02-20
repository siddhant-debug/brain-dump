# RAG System Optimization: Contextual Re-ranking

## Goal Description

Enhance the RAG (Retrieval-Augmented Generation) system's accuracy by implementing **contextual re-ranking** using cross-encoder models. This will improve the relevance of retrieved documents by 15-25%, making the AI agent respond more accurately as if mirroring the user's subconscious mind.

### Problem Statement
The current system uses bi-encoder embeddings (`all-MiniLM-L6-v2`) which encode queries and documents separately. This approach is fast but less accurate because it doesn't understand the relationship between the query and document when they're viewed together.

### Solution
Implement a two-stage retrieval pipeline:
1. **Stage 1 (Fast)**: Bi-encoder retrieves top-10 candidates (~50ms)
2. **Stage 2 (Accurate)**: Cross-encoder re-ranks candidates and selects top-3 (~150ms)

Total latency: ~200ms (acceptable for streaming responses)

---

## User Review Required

> [!IMPORTANT]
> **No Breaking Changes**: This optimization is backward-compatible. The API interface remains unchanged.

> [!NOTE]
> **Performance Trade-off**: Adds ~150ms latency per query. This is acceptable because:
> - Responses are streamed (user sees first chunk quickly)
> - Accuracy improvement (15-25%) justifies the cost
> - Still well under 500ms threshold for good UX

---

## Proposed Changes

### Backend RAG Engine

#### [MODIFY] [rag_engine.py](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/rag_engine.py)

**Changes:**
1. Add cross-encoder model initialization at module level
2. Create new `search_brain_with_reranking()` function
3. Update existing [search_brain()](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/rag_engine.py#143-178) to use re-ranking
4. Add configuration constants for re-ranking parameters

**Key additions:**
- Import `sentence-transformers` library
- Initialize `CrossEncoder('cross-encoder/ms-marco-MiniLM-L-6-v2')` globally
- Implement re-ranking logic with top-10 → top-3 pipeline
- Add debug logging for re-ranking scores

---

#### [MODIFY] [rag_router.py](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/rag_router.py)

**Changes:**
1. Update streaming chat endpoint to use new re-ranking function
2. Add re-ranking score logging for debugging

**Minimal changes** - the router will automatically benefit from the improved [search_brain()](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/rag_engine.py#143-178) function.

---

### Dependencies

#### [NEW] [requirements.txt](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/requirements.txt)

Add new dependency:
```txt
sentence-transformers>=2.2.0
```

This library provides the cross-encoder model for re-ranking.

---

## Technical Concepts Documentation

### What is Bi-Encoder vs Cross-Encoder?

#### Bi-Encoder (Current System)
```
Query: "How to fix memory leaks?"
         ↓
    [Encoder] → Vector [0.2, 0.8, ...]
    
Document: "Use valgrind to detect leaks"
         ↓
    [Encoder] → Vector [0.3, 0.7, ...]
    
Similarity = Cosine(query_vector, doc_vector)
```

**Pros**: Fast (can pre-compute document vectors)  
**Cons**: Query and document never "see" each other

#### Cross-Encoder (New Addition)
```
Query + Document together:
"How to fix memory leaks? [SEP] Use valgrind to detect leaks"
         ↓
    [Encoder] → Relevance Score: 0.95
```

**Pros**: More accurate (sees full context)  
**Cons**: Slower (must compute for each query-doc pair)

### Why Two-Stage Pipeline?

We combine both approaches:
1. **Bi-encoder**: Fast filtering (10,000 docs → 10 candidates)
2. **Cross-encoder**: Accurate ranking (10 candidates → 3 best)

This gives us **speed + accuracy**!

---

## Implementation Details

### Re-ranking Algorithm

```python
# Step 1: Get candidates with bi-encoder
candidates = vector_db.query(query, n_results=10)

# Step 2: Score each candidate with cross-encoder
scores = []
for doc in candidates:
    score = cross_encoder.predict([(query, doc)])
    scores.append(score)

# Step 3: Sort by score and take top-3
top_3_indices = argsort(scores)[::-1][:3]
best_docs = [candidates[i] for i in top_3_indices]
```

### Configuration Parameters

| Parameter | Value | Reasoning |
|-----------|-------|-----------|
| `n_candidates` | 10 | Balance between coverage and speed |
| `n_final_results` | 3 | Optimal context window for Gemini |
| `cross_encoder_model` | `ms-marco-MiniLM-L-6-v2` | Best accuracy/speed trade-off |
| `temperature` | 0.3 | Low for factual responses |

---

## Verification Plan

### Automated Tests

1. **Unit Test: Re-ranking Function**
   ```bash
   # Test that re-ranking returns top-3 results
   pytest backend/test_rag_reranking.py
   ```

2. **Integration Test: Full Pipeline**
   ```bash
   # Test upload → query → re-ranked response
   python backend/test_endpoints.py
   ```

3. **Performance Benchmark**
   ```bash
   # Measure latency before/after
   python backend/benchmark_reranking.py
   ```

### Manual Verification

1. **Upload test documents** with known content
2. **Query with ambiguous questions** (e.g., "What did I say about Python?")
3. **Compare results** before/after re-ranking
4. **Verify streaming** still works smoothly

### Success Criteria

- ✅ Re-ranking completes in <200ms
- ✅ Streaming response starts within 500ms
- ✅ Subjective accuracy improvement on test queries
- ✅ No errors in logs
- ✅ All existing tests pass

---

## Performance Expectations

### Latency Breakdown

| Stage | Time | Cumulative |
|-------|------|------------|
| Vector search (top-10) | ~50ms | 50ms |
| Cross-encoder re-ranking | ~150ms | 200ms |
| Gemini first chunk | ~300ms | 500ms |
| **Total to first visible response** | | **~500ms** |

### Accuracy Improvement

Based on benchmarks from similar systems:
- **Bi-encoder only**: 65-70% retrieval accuracy
- **+ Cross-encoder**: 80-90% retrieval accuracy
- **Expected gain**: +15-25 percentage points

---

## Rollback Plan

If re-ranking causes issues:

1. **Quick rollback**: Comment out re-ranking, revert to direct bi-encoder search
2. **Fallback mode**: Add feature flag to toggle re-ranking on/off
3. **No data migration needed**: Vector DB remains unchanged

---

## Future Enhancements

After this implementation, we can consider:

1. **Hybrid Search** (Technique 1): Add BM25 keyword matching
2. **Query Expansion** (Technique 2): Generate query variations
3. **Personalized Prompts** (Technique 5): Analyze user writing style
4. **Conversational Memory** (Technique 8): Track dialogue history

These can be added incrementally without breaking changes.
