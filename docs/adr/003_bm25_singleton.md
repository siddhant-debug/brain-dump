# ADR 003: BM25 Singleton Management

## Status
Accepted

## Context
The BM25 index is essentially a term-frequency map. Recomputing it on every query for every user is prohibitively slow once the data grows beyond a few notes.

## Decision
Implement the BM25 store as a **Singleton** with the following properties:
1. **Per-User Isolation**: Indices are partitioned by `user_id`.
2. **Lazy Invalidation**: The index is only fully rebuilt when new data is successfully indexed into the RAG system.
3. **Persistence**: The index state is serialized to disk to survive server restarts.

## Consequences
- **Pros**: Sub-50ms retrieval latency for sparse search.
- **Cons**: Risk of cache inconsistency if invalidation logic fails; memory usage scale-out needs to be monitored per user.
