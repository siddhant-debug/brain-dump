# Implementation Plan: Backend Hardening & Optimization

This plan addresses the critical performance and security gaps identified during the backend code audit.

## Proposed Changes

### 1. Concurrency: Resolution of Event Loop Starvation
The current `async def` routes using synchronous SQLAlchemy sessions block the event loop. We will move these to synchronous `def` routes, which FastAPI automatically offloads to a thread pool.

#### [MODIFY] [rag.py](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/api/routers/rag.py)
- Convert [upload_to_brain](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/api/routers/rag.py#72-207) and [chat_endpoint](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/api/routers/rag.py#284-476) to `def` (instead of `async def`) or ensure all heavy I/O is awaited via `run_in_executor`.
- Explicitly use `rag_engine.async_index_text` in [upload_to_brain](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/api/routers/rag.py#72-207).

#### [MODIFY] [notes.py](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/api/routers/notes.py)
- Refactor routes to use standard `def` for sync database interactions.

### 2. RAG: Vector Indexing for Performance
We will add a migration to create an HNSW index on the `brain_embeddings` table.

#### [NEW] [migration_v1_hnsw.sql](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/alembic/versions/v1_add_hnsw_index.py)
- Create a migration to add `hnsw` index on `embedding` using `vector_cosine_ops`.

### 3. Security: Data Integrity & RLS
We will enforce foreign key constraints and prepare Postgres for Row-Level Security.

#### [MODIFY] [models.py](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/models/models.py)
- Add `ForeignKey` constraints to [StoredFile](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/models/models.py#26-37), [Note](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/models/models.py#39-49), and [ChatMessage](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/models/models.py#51-61).
- Add `ondelete="CASCADE"` to ensure cleanup.

## Verification Plan

### Automated Tests
- **Load Testing**: Run a script to simulate 10 concurrent chat requests and verify that the API remains responsive (latency stays stable).
- **Index Verification**: Run `EXPLAIN ANALYZE` on a vector search query to confirm the `hnsw` index is being used instead of a sequential scan.

### Manual Verification
- **Upload Flow**: Upload a 5MB Markdown file and verify that the UI doesn't hang and the file is indexed correctly in the background.
- **Isolation Check**: Attempt to fetch a file by ID using a different user's token and verify it returns a 404/403.
