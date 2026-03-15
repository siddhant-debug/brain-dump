# ADR 001: Hybrid Search Strategy (Vector + BM25)

## Status
Accepted

## Context
BrainDump requires a retrieval system that can handle both semantic queries ("how I felt last week") and exact keyword lookups ("Project X deployment steps"). Dense vector retrieval (Bi-Encoders) is excellent for semantic meaning but often fails to find specific technical terms or unique identifiers.

## Decision
We will implement a **Hybrid Search** strategy:
1. **Dense Retrieval**: Using `pgvector` with HNSW indexing for performance.
2. **Sparse Retrieval**: Using the `rank_bm25` library for keyword-based matches.
3. **Fusion**: Combine both results using **Reciprocal Rank Fusion (RRF)** before passing candidates to the reranker.

## Consequences
- **Pros**: Significant improvement in retrieval recall across both semantic and exact-match scenarios.
- **Cons**: Increased complexity in the retrieval pipeline; requires managing a persistent BM25 index alongside the vector database.
- **Mitigation**: Implemented a singleton `BM25Store` with lazy invalidation to minimize indexing overhead.
