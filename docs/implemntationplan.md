```markdown
# Implementation Plan: Analytics Loop Detection Improvements

## Overview
Four targeted changes to the `get_loops` function in `analytics.py`:
fix a critical query bug, improve cluster sensitivity, scale neighbor
detection, and persist results to avoid recomputation.

---

## Change 1: Fix Non-Indexed User Filter [CRITICAL]
**File:** `analytics.py`
**Type:** Bug Fix — one line change, immediate performance impact.

### What
Replace the JSON string lookup with the indexed integer column:
```python
# Before (slow — JSON string scan, no index)
.filter(BrainEmbedding.metadata_.op("->>")("user_id") == str(uid))

# After (fast — uses indexed integer column)
.filter(BrainEmbedding.user_id == uid)
```

### Verification
Run `EXPLAIN ANALYZE` on the query before and after.
- **FAIL**: `Seq Scan` on `brain_embeddings`
- **PASS**: `Index Scan` using `idx_brain_embeddings_user_id` (or similar)

---

## Change 2: Threshold Calibration [HIGH]
**File:** `analytics.py`
**Type:** Tuning — requires ground truth validation before shipping.

### Ground Truth Set (define before changing anything)
Use User 5's existing data:

| Notes | Expected Result |
|---|---|
| "too high on weed", "want to leave cigarettes", "smoked again today" | LOOP (smoking/habits) |
| "need to hit the gym", "daily workout done", "missed gym today" | LOOP (fitness) |
| "what should I eat", "checked the weather" | NOT A LOOP |

### What
Test L2 threshold at `0.65` (current) and `0.70` (proposed) against
the ground truth set. Pick the threshold that correctly clusters all
LOOP rows without pulling in NOT A LOOP rows.

```python
# Make threshold configurable so it can be tuned without code changes
LOOP_L2_THRESHOLD = float(os.getenv("LOOP_L2_THRESHOLD", "0.65"))
```

Expose it as an env var so you can tune it on the server without
rebuilding the container.

### Verification
- All 3 smoking/habit notes cluster together at chosen threshold
- Gym notes remain clustered
- Unrelated notes do not appear in any loop

---

## Change 3: Dynamic Neighbor Limit [MEDIUM]
**File:** `analytics.py`
**Type:** Enhancement — scales detection with corpus size.

### What
Replace the hardcoded `.limit(5)` with a corpus-proportional limit:

```python
# Before
.limit(5)

# After
neighbor_limit = max(5, len(user_docs) // 100)  # 1% of corpus, min 5
.limit(neighbor_limit)
```

### Why
With 2148 documents for User 5, a limit of 5 neighbors breaks large
clusters into disconnected fragments. At 1% of corpus:
- 2148 docs → limit of 21
- 500 docs → limit of 5 (floor kicks in)
- 10000 docs → limit of 100

### Verification
Re-run loop detection for User 5 and confirm the smoking/habits cluster
(currently missed) now surfaces as a single loop rather than fragments.

---

## Change 4: Loop Persistence & Caching [MEDIUM]
**File:** `analytics.py`, `models.py`, new Alembic migration
**Type:** Architecture — prevents expensive recomputation on every request.

### What
Store detected loops in a `detected_loops` table and recompute only
when the user's note corpus has changed since the last run.

#### [NEW] Model — `models.py`
```python
class DetectedLoop(Base):
    __tablename__ = "detected_loops"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"),
                     index=True, nullable=False)
    theme = Column(String, nullable=False)
    severity = Column(String)           # "high" | "low"
    occurrence_count = Column(Integer)
    note_ids = Column(ARRAY(Integer))   # IDs of clustered notes
    computed_at = Column(DateTime, default=datetime.utcnow)
```

#### [NEW] Migration
```sql
CREATE TABLE detected_loops (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    theme TEXT NOT NULL,
    severity TEXT,
    occurrence_count INTEGER,
    note_ids INTEGER[],
    computed_at TIMESTAMP DEFAULT now()
);
CREATE INDEX ON detected_loops (user_id);
```

#### [MODIFY] `get_loops` endpoint logic
```python
# Check if loops are fresh (recompute only if new notes since last run)
last_computed = db.query(func.max(DetectedLoop.computed_at))\
    .filter(DetectedLoop.user_id == uid).scalar()

last_note = db.query(func.max(BrainEmbedding.created_at))\
    .filter(BrainEmbedding.user_id == uid).scalar()

if last_computed and last_note and last_computed > last_note:
    # Cache is fresh — return stored loops
    return db.query(DetectedLoop)\
        .filter(DetectedLoop.user_id == uid).all()

# Otherwise recompute, store, and return
```

### Verification
1. Hit `/analytics/loops` twice back-to-back
2. First call: recomputes and stores — check `detected_loops` table has rows
3. Second call: returns cached result — response time should drop from
   ~2s to ~10ms
4. Add a new note, hit endpoint again — confirm it recomputes

---

## Deferred (Out of Scope for This Plan)

### Chat Message Inclusion
Including chat messages in loop clustering requires:
- Minimum message length filter (exclude short conversational turns)
- Excluding assistant turns (only cluster user messages)
- Separate severity weighting (chat loops weighted lower than note loops)

Deferred until loop persistence (Change 4) is stable — adding a new
corpus source before caching is in place will make every request
even more expensive.

### Loop Resolution Detection
Note 117 ("after lot of time apple music worked") signals a resolved
loop. Detecting resolution requires classifying notes as
"closing" a prior cluster. Deferred as a separate feature.

---

## Execution Order
1. Change 1 — fix the query bug (5 mins, immediate impact)
2. Change 2 — calibrate threshold against ground truth (before any
   other changes so you have a clean baseline)
3. Change 3 — dynamic neighbor limit
4. Change 4 — persistence layer (last, depends on stable detection logic)

---

## Rollback
- Changes 1-3 are stateless — revert by restoring the original lines
- Change 4 introduces a new table — rollback via:
  ```bash
  docker exec -it braindump-backend alembic downgrade -1
  ```
```