# Principal Backend Engineer Audit: BrainDump API

## 🚨 High Priority (Critical Security & Performance)

### 1. Concurrency Bottleneck: Event Loop Starvation
**Problem:** Most API routes (e.g., [chat_endpoint](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/api/routers/rag.py#284-476) in [rag.py](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/api/routers/rag.py)) are defined as `async def`, but they consume a synchronous SQLAlchemy `Session` (`Depends(database.get_db)`). Every call to `db.query(...).all()` or `db.commit()` blocks the single-threaded event loop. Under heavy load, this will cause the entire API to hang.
**Fix:** Define routes without the [async](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/services/rag_engine.py#903-917) keyword if they must use synchronous DB drivers (FastAPI will run them in a thread pool), or migrate to an asynchronous driver like `asyncpg` with `ExtAsyncSession`.

**Snippet for immediate mitigation (rag.py):**
```python
# Before
@router.post("/chat")
async def chat_endpoint(...):
    history = db.query(models.ChatMessage)...all() # BLOCKS

# After
@router.post("/chat")
def chat_endpoint(...): # FastAPI runs this synchronously in a thread
    history = db.query(models.ChatMessage)...all() # Safe for thread pool
```

### 2. Blocking I/O in Async Context ([rag.py](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/api/routers/rag.py))
**Problem:** [upload_to_brain](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/api/routers/rag.py#72-207) is `async def`, but it calls `rag_engine.index_text(..., db)` directly. This function performs heavy Markdown parsing and embedding generation (`SentenceTransformer.encode`), which completely chokes the event loop for several seconds per upload.
**Fix:** Use the existing `await rag_engine.async_index_text(...)` wrapper which offloads the work to the `ThreadPoolExecutor`.

### 3. Missing Vector Indexing ([main.py](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/main.py) / migrations)
**Problem:** `pgvector` is enabled, but no index (HNSW or IVFFlat) is created. Document retrieval performs a sequential scan (O(N)), which is unsustainable as the `brain_embeddings` table grows.
**Fix:** Add an HNSW index migration. HNSW is preferred for high-dimensional embeddings (768) due to its superior recall/latency trade-off in RAG pipelines.

**SQL Snippet:**
```sql
CREATE INDEX ON brain_embeddings USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);
```

---

## ⚠️ Low Priority (Optimizations & Hardening)

### 1. Security: Data Integrity & RLS
**Problem:** Models like [StoredFile](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/models/models.py#26-37) and [Note](file:///Users/siddhanttomar/development/flutter_projects/brain_dump/brain-dump/backend/app/models/models.py#39-49) lack explicit `ForeignKey` constraints at the DB level. While the app filters by `user_id`, the database doesn't guarantee isolation or handle cascades.
**Fix:** Add `ForeignKey("users.id", ondelete="CASCADE")` to all user-owned models and implement Postgres Row-Level Security (RLS) to prevent accidental data leaks even if an app-level filter is missed.

**Model Snippet:**
```python
user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
```

### 2. Caching Strategy: Redis Integration
**Problem:** Endpoints like `/chat/history` and `/chat/files` hit the database on every refresh. These are high-read, low-write datasets.
**Fix:** Implement a "Cache-Aside" pattern using Redis.

**Code Snippet (Redis implementation):**
```python
import redis
import json

redis_client = redis.Redis(host='localhost', port=6379, db=0)

@router.get("/history")
def get_chat_history(current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(database.get_db)):
    cache_key = f"chat_history:{current_user.id}"
    cached_data = redis_client.get(cache_key)
    
    if cached_data:
        return json.loads(cached_data)
    
    messages = db.query(models.ChatMessage).filter(models.ChatMessage.user_id == current_user.id).all()
    # Serialize and cache for 5 minutes
    redis_client.setex(cache_key, 300, json.dumps([msg.to_dict() for msg in messages]))
    return messages
```

### 3. JWT Strategy Hardening
**Problem:** `ACCESS_TOKEN_EXPIRE_MINUTES` is set to 24 hours. Given the sensitivity of the data (Health, Location), a shorter access token (15-30m) paired with a secure Refresh Token stored in `HttpOnly` cookies would be more resilient.
