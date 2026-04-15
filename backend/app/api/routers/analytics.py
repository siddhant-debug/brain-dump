"""
Analytics Router — Phase 1
Four read-only endpoints. Zero schema changes. Zero risk to existing routes.

GET /analytics/consistency  — streak + 30-day heatmap
GET /analytics/themes       — topic frequency/% over last 30 days
GET /analytics/loops        — recurring thought clusters via ChromaDB ANN
GET /analytics/pipeline     — thought pipeline graph (nodes + lane topology)
"""

import re
import os
import logging
from datetime import datetime, timedelta, date, timezone
from collections import Counter
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import case
from sqlalchemy.orm import Session

from app.core import database
from app.models import models
from app.core.limiter import limiter
from app.services import rag_engine
from . import auth

import logging
from collections import defaultdict
from itertools import combinations
import yake

router = APIRouter(prefix="/analytics", tags=["analytics"])
logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────


def _now_ist() -> datetime:
    """Timezone-aware IST now (Asia/Kolkata timezone)."""
    # IST is UTC +5:30
    tz = timezone(timedelta(hours=5, minutes=30))
    return datetime.now(tz)


def _notes_last_n_days(user_id: int, db: Session, days: int = 30):
    """Return all Notes for a user created in the last N days."""
    cutoff = _now_ist() - timedelta(days=days)
    return (
        db.query(models.Note)
        .filter(
            models.Note.user_id == user_id,
            models.Note.created_at >= cutoff,
        )
        .order_by(models.Note.created_at.asc())
        .all()
    )


def _tokenize(text: str) -> set[str]:
    """Split text into lowercase word tokens, stripping punctuation."""
    return set(re.split(r"\W+", text.lower())) - {""}


# ─────────────────────────────────────────────────────────────────────────────
# 1. CONSISTENCY STREAK
# ─────────────────────────────────────────────────────────────────────────────


@router.get("/consistency")
@limiter.limit("30/minute")
def get_consistency(
    request: Request,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db),
):
    #
    # COMMENT:- This seems like service-level code inside of view
    #
    """
    Returns:
    - current_streak: days in a row (from today backwards)
    - longest_streak: best ever streak
    - total_notes: total lifetime notes
    - active_days_last_30: unique days with at least 1 note in last 30 days
    - heatmap: [{date, count}] for last 30 days
    """
    try:
        uid = current_user.id

        # All-time notes for streak calculation
        all_notes = (
            db.query(models.Note)
            .filter(models.Note.user_id == uid)
            .order_by(models.Note.created_at.asc())
            .all() 
            #
            #COMMENT :- DB entries should have timestamp field of their own, 
            #use sort method directly using that as part of the DB query instead of doing it in code
            #
        )
        total_notes = len(all_notes)

        if not all_notes:
            return {
                "current_streak": 0,
                "longest_streak": 0,
                "total_notes": 0,
                "active_days_last_30": 0,
                "heatmap": _empty_heatmap(),
            }

        # Convert note created_at (UTC in DB) to IST date
        ist_tz = timezone(timedelta(hours=5, minutes=30))
        date_counts: dict[date, int] = Counter(
            n.created_at.astimezone(ist_tz).date() for n in all_notes
        )
        all_dates_sorted = sorted(date_counts.keys())

        # Longest streak (ever)
        longest = 1
        current_run = 1
        for i in range(1, len(all_dates_sorted)):
            if (all_dates_sorted[i] - all_dates_sorted[i - 1]).days == 1:
                current_run += 1
                longest = max(longest, current_run)
            else:
                current_run = 1

        # Current streak (walking back from today)
        today = _now_ist().date()
        current_streak = 0

        # Start checking from today
        check = today

        # If no note today, but there's a note yesterday, the streak is still alive
        if check not in date_counts and (check - timedelta(days=1)) in date_counts:
            check -= timedelta(days=1)

        while check in date_counts:
            current_streak += 1
            check -= timedelta(days=1)

        # 30-day heatmap
        heatmap = []
        for i in range(29, -1, -1):
            d = today - timedelta(days=i)
            # Ensure the structure matches the interface requirement (isoformat dates)
            heatmap.append({"date": d.isoformat(), "count": date_counts.get(d, 0)})

        active_days_last_30 = sum(1 for h in heatmap if h["count"] > 0)

        return {
            "current_streak": current_streak,
            "longest_streak": longest,
            "total_notes": total_notes,
            "active_days_last_30": active_days_last_30,
            "heatmap": heatmap,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Error in /analytics/consistency")
        raise HTTPException(
            status_code=500, detail="Failed to compute consistency data."
        )


def _empty_heatmap():
    today = _now_ist().date()
    return [
        {"date": (today - timedelta(days=i)).isoformat(), "count": 0}
        for i in range(29, -1, -1)
    ]


# ─────────────────────────────────────────────────────────────────────────────
# 2. THEME DISTRIBUTION
# ─────────────────────────────────────────────────────────────────────────────

# Keyword taxonomy — uses word-token matching (consistent with pipeline)
THEMES = {
    "work": {
        "work",
        "job",
        "career",
        "startup",
        "business",
        "product",
        "feature",
        "ship",
        "launch",
        "build",
        "customer",
        "client",
        "meeting",
    },
    "money": {
        "money",
        "finance",
        "funding",
        "salary",
        "revenue",
        "invest",
        "budget",
        "raise",
        "equity",
        "profit",
        "debt",
    },
    "relationships": {
        "friend",
        "family",
        "dating",
        "relationship",
        "partner",
        "love",
        "breakup",
        "marriage",
        "lonely",
        "social",
    },
    "health": {
        "gym",
        "fitness",
        "health",
        "workout",
        "sleep",
        "diet",
        "exercise",
        "run",
        "tired",
        "energy",
        "mental",
    },
    "learning": {
        "learn",
        "read",
        "course",
        "study",
        "book",
        "skill",
        "tutorial",
        "research",
        "understand",
    },
    "anxiety": {
        "worried",
        "stress",
        "anxious",
        "fear",
        "nervous",
        "scared",
        "overwhelmed",
        "pressure",
        "panic",
    },
    "creativity": {
        "idea",
        "create",
        "design",
        "art",
        "music",
        "write",
        "creative",
        "inspiration",
        "imagine",
    },
    "goals": {
        "goal",
        "plan",
        "target",
        "milestone",
        "deadline",
        "achieve",
        "progress",
        "focus",
        "vision",
    },
}

THEME_DISPLAY = {
    "work": "Work & Career",
    "money": "Money & Finance",
    "relationships": "Relationships",
    "health": "Health",
    "learning": "Learning",
    "anxiety": "Stress & Anxiety",
    "creativity": "Creativity",
    "goals": "Goals",
}


@router.get("/themes")
@limiter.limit("30/minute")
def get_themes(
    request: Request,
    days: int = 30,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db),
):
    """
    Keyword-based theme frequency over the last N days.
    Uses word-token matching (not substring) for accuracy.
    A note can match multiple themes.
    pct = (notes matching theme) / (total notes analyzed) * 100
    """
    try:
        days = min(days, 90)  # cap at 90
        uid = current_user.id
        notes = _notes_last_n_days(uid, db, days)

        if not notes:
            return {"window_days": days, "total_notes_analyzed": 0, "themes": []}

        total = len(notes)
        theme_hits: dict[str, list[str]] = {k: [] for k in THEMES}

        for note in notes:
            tokens = _tokenize(note.content)
            for theme, keywords in THEMES.items():
                if tokens & keywords:  # set intersection — whole-word matching
                    theme_hits[theme].append(note.content[:80])

        result = []
        for theme, matches in theme_hits.items():
            if matches:
                result.append(
                    {
                        "key": theme,
                        "name": THEME_DISPLAY[theme],
                        "count": len(matches),
                        "pct": round(len(matches) / total * 100, 1),
                        "sample": matches[-1],
                    }
                )

        result.sort(key=lambda x: x["count"], reverse=True)

        return {
            "window_days": days,
            "total_notes_analyzed": total,
            "themes": result,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Error in /analytics/themes")
        raise HTTPException(status_code=500, detail="Failed to compute theme data.")


# ─────────────────────────────────────────────────────────────────────────────
# 3. RECURRING LOOPS
# ─────────────────────────────────────────────────────────────────────────────

LOOP_L2_THRESHOLD = float(os.getenv("LOOP_L2_THRESHOLD", "0.65"))  # Empirical L2 distance for sentence transformers
MAX_NOTES_TO_SCAN = 100  # cap to avoid O(n²) — most users have far fewer
MIN_NOTE_LENGTH = 10  # Ignore short notes (e.g. "Buy milk") to avoid garbage clusters
LOOP_PATH_TEMPLATES = {
    "high": "You've revisited this {n} times without resolving it. Set a deadline — even flipping a coin beats endless circling.",
    "medium": "This keeps coming back. Give it 10 focused minutes today instead of another open loop.",
    "low": "A pattern is forming. Worth a dedicated session to resolve this.",
}


@router.get("/loops")
@limiter.limit("10/minute")
def get_loops(
    request: Request,
    days: int = 30,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db),
):

    try:
        days = min(days, 90)
        uid = current_user.id

        from app.models.models import DetectedLoop

        # Default fast path check
        if not current_user.needs_loop_recalc:
            # Issue 3 fix: push sort to Postgres using CASE WHEN — no Python sort needed
            _severity_order = case(
                (DetectedLoop.severity == "high", 0),
                (DetectedLoop.severity == "medium", 1),
                (DetectedLoop.severity == "low", 2),
                else_=9,
            )
            cached_loops = (
                db.query(DetectedLoop)
                .filter(DetectedLoop.user_id == uid)
                .order_by(_severity_order, DetectedLoop.occurrences.desc())
                .all()
            )
            if cached_loops:
                results = [
                    {
                        "theme_guess": loop.theme_guess,
                        "occurrences": loop.occurrences,
                        "severity": loop.severity,
                        "first_seen": loop.first_seen,
                        "last_seen": loop.last_seen,
                        "notes": loop.notes_json,
                        "path_forward": loop.path_forward,
                    }
                    for loop in cached_loops
                ]
                return {"loops": results, "notes_scanned": -1}

        notes = _notes_last_n_days(uid, db, days)

        if len(notes) < 3:
            return {"loops": [], "notes_scanned": len(notes)}

        # Limit scan to the most recent MAX_NOTES_TO_SCAN
        scan_notes = notes[-MAX_NOTES_TO_SCAN:]

        # (Removed ChromaDB collection init)        # 1. Filter out garbage notes
        valid_notes = []
        for note in scan_notes:
            content = note.content.strip() if note.content else ""
            if len(content) >= MIN_NOTE_LENGTH:
                valid_notes.append(note)

        if not valid_notes:
            return {"loops": [], "notes_scanned": len(scan_notes)}

        # Build adjacency: note_id → set of similar note_ids
        adjacency: dict[int, set[int]] = {n.id: set() for n in valid_notes}
        note_by_id = {n.id: n for n in valid_notes}

        # 2. Batched Query using pgvector
        try:
            from app.models.models import BrainEmbedding
            from sqlalchemy.sql import func

            corpus_size = db.query(func.count(BrainEmbedding.id))\
                .filter(BrainEmbedding.user_id == uid).scalar() or 0
            neighbor_limit = max(5, corpus_size // 100)

            emb_model = rag_engine.get_emb_fn()
            query_embeddings = emb_model.encode(
                [n.content for n in valid_notes]
            ).tolist()

            results = {"ids": [], "distances": [], "metadatas": []}
            for q_emb in query_embeddings:
                db_results = (
                    db.query(
                        BrainEmbedding.id,
                        BrainEmbedding.embedding.l2_distance(q_emb).label("distance"),
                        BrainEmbedding.metadata_,
                    )
                    .filter(BrainEmbedding.user_id == uid)
                    .order_by("distance")
                    .limit(neighbor_limit)
                    .all()
                )

                results["ids"].append([r.id for r in db_results])
                results["distances"].append([r.distance for r in db_results])
                results["metadatas"].append([r.metadata_ for r in db_results])

            if results and "ids" in results and results["ids"]:
                # results["ids"] is a list of lists, one per query
                for query_idx, query_note in enumerate(valid_notes):
                    try:
                        neighbor_ids = results["ids"][query_idx]
                        distances = results["distances"][query_idx]
                        metadatas = (
                            results["metadatas"][query_idx]
                            if "metadatas" in results and results["metadatas"]
                            else []
                        )

                        for i, doc_id in enumerate(neighbor_ids):
                            dist = distances[i]
                            if dist < LOOP_L2_THRESHOLD:
                                meta = (
                                    metadatas[i]
                                    if metadatas and i < len(metadatas)
                                    else {}
                                )
                                source = meta.get("source", "")
                                neighbor_note_id = None
                                if source.startswith("note_"):
                                    try:
                                        neighbor_note_id = int(
                                            source.replace("note_", "")
                                        )
                                    except ValueError:
                                        pass

                                if (
                                    neighbor_note_id
                                    and neighbor_note_id != query_note.id
                                ):
                                    if neighbor_note_id in adjacency:
                                        adjacency[query_note.id].add(neighbor_note_id)
                                        adjacency[neighbor_note_id].add(query_note.id)
                    except (IndexError, TypeError):
                        continue
        except Exception as e:
            logger.error("Batch query to ChromaDB failed: %s", e)
            return {"loops": [], "notes_scanned": len(scan_notes)}

        # Union-Find to cluster connected notes into loops
        clusters = _union_find_clusters(adjacency)

        # Filter: only surface clusters with ≥ 3 notes (real loops, not coincidences)
        loops = []
        for cluster_ids in clusters:
            if len(cluster_ids) < 3:
                continue

            cluster_notes = sorted(
                [note_by_id[nid] for nid in cluster_ids if nid in note_by_id],
                key=lambda n: n.created_at,
            )
            n = len(cluster_notes)

            if n >= 6:
                severity = "high"
            elif n >= 4:
                severity = "medium"
            else:
                severity = "low"

            path = LOOP_PATH_TEMPLATES[severity].format(n=n)

            # 3. Offline Keyword Extraction for Theme Guess
            # Combine all text in the cluster
            full_cluster_text = " ".join(
                [n.content for n in cluster_notes if n.content]
            )

            theme_guess = ""
            if full_cluster_text.strip():
                try:
                    # YAKE configuration
                    kw_extractor = yake.KeywordExtractor(
                        lan="en", n=2, dedupLim=0.9, top=1, features=None
                    )
                    keywords = kw_extractor.extract_keywords(full_cluster_text)
                    if keywords:
                        # Grab the highest-ranked phrase
                        top_phrase = keywords[0][0]
                        theme_guess = f"Pattern: {top_phrase.title()}"
                except Exception as e:
                    logger.debug(f"YAKE extraction failed for loop: {e}")

            # Fallback to centroid logic if YAKE fails or returns empty
            if not theme_guess:
                cluster_set = set(cluster_ids)
                best_note_id = None
                max_connections = -1

                for nid in cluster_ids:
                    if nid not in adjacency:
                        continue
                    # Count internal edges
                    internal_connections = len(adjacency[nid].intersection(cluster_set))
                    if internal_connections > max_connections:
                        max_connections = internal_connections
                        best_note_id = nid

                centroid_note = note_by_id.get(best_note_id, cluster_notes[0])
                theme_guess = centroid_note.content[:60].strip()
                if len(centroid_note.content) > 60:
                    theme_guess += "..."

            loops.append(
                {
                    "theme_guess": theme_guess,
                    "occurrences": n,
                    "severity": severity,
                    "first_seen": cluster_notes[0].created_at.date().isoformat(),
                    "last_seen": cluster_notes[-1].created_at.date().isoformat(),
                    "notes": [
                        {
                            "date": note.created_at.strftime("%b %d"),
                            "preview": note.content[:80].replace("\n", " ")
                            + ("…" if len(note.content) > 80 else ""),
                        }
                        for note in cluster_notes
                    ],
                    "path_forward": path,
                }
            )

        # Sort: high severity first, then by occurrences
        severity_order = {"high": 0, "medium": 1, "low": 2}
        loops.sort(
            key=lambda x: (severity_order.get(x["severity"], 9), -x["occurrences"])
        )

        try:
            # Clear old cache
            db.query(DetectedLoop).filter(DetectedLoop.user_id == uid).delete()

            # Insert new loops
            for loop in loops:
                db.add(DetectedLoop(
                    user_id=uid,
                    theme_guess=loop["theme_guess"],
                    severity=loop["severity"],
                    occurrences=loop["occurrences"],
                    first_seen=loop["first_seen"],
                    last_seen=loop["last_seen"],
                    notes_json=loop["notes"],
                    path_forward=loop["path_forward"]
                ))

            # Mark cache as fresh
            current_user.needs_loop_recalc = False
            db.commit()
        except Exception as e:
            logger.error(f"Failed to cache loops for user {uid}: {e}")
            db.rollback()

        return {"loops": loops, "notes_scanned": len(scan_notes)}

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Error in /analytics/loops")
        raise HTTPException(status_code=500, detail="Failed to compute loop data.")


def _union_find_clusters(adjacency: dict) -> list[set]:
    """Simple union-find to group connected note IDs into clusters."""
    parent = {nid: nid for nid in adjacency}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb

    for nid, neighbors in adjacency.items():
        for neighbor in neighbors:
            union(nid, neighbor)

    # Group by root
    groups: dict = {}
    for nid in adjacency:
        root = find(nid)
        groups.setdefault(root, set()).add(nid)

    return list(groups.values())


# ─────────────────────────────────────────────────────────────────────────────
# 4. THOUGHT PIPELINE
# ─────────────────────────────────────────────────────────────────────────────

MAX_PIPELINE_NODES = 50  # cap to keep the graph readable

# ── 3 fixed pipeline lanes ────────────────────────────────────────────────────
# Keywords are matched against whole WORDS only (word-token matching) to avoid
# false positives like "work" inside "network" or "workout".
PIPELINE_LANES = [
    {
        "key": "work",
        "label": "Work",
        "color": "#2979FF",
        "keywords": {
            "work",
            "job",
            "career",
            "meeting",
            "project",
            "deadline",
            "client",
            "office",
            "startup",
            "business",
            "product",
            "launch",
            "salary",
            "interview",
            "resume",
            "code",
            "coding",
            "programming",
            "develop",
            "development",
            "feature",
            "bug",
            "deploy",
            "manager",
            "team",
            "colleague",
            "intern",
            "promotion",
            "revenue",
            "invoice",
        },
    },
    {
        "key": "health",
        "label": "Health",
        "color": "#81B622",
        "keywords": {
            "gym",
            "workout",
            "exercise",
            "sleep",
            "diet",
            "health",
            "fitness",
            "run",
            "running",
            "tired",
            "energy",
            "sick",
            "doctor",
            "mental",
            "anxiety",
            "stress",
            "depression",
            "meditation",
            "yoga",
            "water",
            "eating",
            "food",
            "pain",
            "medicine",
            "therapy",
            "hospital",
            "healthy",
            "wellbeing",
            "rest",
            "recovery",
            "breathing",
        },
    },
    {
        "key": "personal",
        "label": "🌱 Personal",
        "color": "#BB86FC",
        "keywords": {
            "friend",
            "friends",
            "family",
            "love",
            "relationship",
            "date",
            "dating",
            "social",
            "feel",
            "feeling",
            "feelings",
            "happy",
            "happiness",
            "sad",
            "lonely",
            "travel",
            "weekend",
            "fun",
            "movie",
            "music",
            "book",
            "books",
            "reading",
            "learn",
            "learning",
            "life",
            "goal",
            "goals",
            "dream",
            "dreams",
            "creativity",
            "creative",
            "idea",
            "ideas",
            "art",
            "thought",
            "thinking",
            "personal",
            "birthday",
            "party",
            "vacation",
            "holiday",
            "gratitude",
        },
    },
]


def _classify_note(content: str) -> str:
    """
    Return the lane key that best matches the note content.
    Uses whole-word token matching to avoid substring false positives.
    Falls back to 'personal' if no lane scores any hits.
    """
    tokens = _tokenize(content)
    best_key = "personal"
    best_score = 0
    for lane in PIPELINE_LANES:
        score = len(tokens & lane["keywords"])
        if score > best_score:
            best_score = score
            best_key = lane["key"]
    return best_key


@router.get("/pipeline")
@limiter.limit("30/minute")
def get_pipeline(
    request: Request,
    days: int = 30,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db),
):
    """
    Returns a thought pipeline graph across 3 fixed lanes: Work, Health, Personal.

    Uses whole-word token matching (not substring) to classify notes accurately.
    Builds a linear parent chain per lane for bezier connections on the frontend.

    Response:
      generated_at: ISO timestamp
      lanes: [{key, label, color}]
      nodes: [{id, content, topic, lane, thought_type, timestamp, parent_ids}]
    """
    try:
        days = min(days, 90)
        uid = current_user.id
        notes = _notes_last_n_days(uid, db, days)

        lane_meta = [
            {"key": l["key"], "label": l["label"], "color": l["color"]}
            for l in PIPELINE_LANES
        ]

        if not notes:
            return {
                "generated_at": _now_ist().isoformat(),
                "lanes": lane_meta,
                "nodes": [],
            }

        lane_by_key = {l["key"]: i for i, l in enumerate(PIPELINE_LANES)}

        # ── Build nodes capped at MAX_PIPELINE_NODES (most recent) ───────────
        # Issue 6 fix: fetch only MAX_PIPELINE_NODES newest notes at the DB level
        # instead of fetching ALL notes for the window and slicing in Python.
        ist_tz = timezone(timedelta(hours=5, minutes=30))
        cutoff = _now_ist() - timedelta(days=days)
        recent_notes = (
            db.query(models.Note)
            .filter(
                models.Note.user_id == uid,
                models.Note.created_at >= cutoff,
            )
            .order_by(models.Note.created_at.desc())
            .limit(MAX_PIPELINE_NODES)
            .all()
        )[::-1]  # flip to chronological for the parent-chain logic (≤50 rows, trivial)
        last_in_lane: dict[int, str] = {}
        pipeline_nodes = []

        for note in recent_notes:
            topic = _classify_note(note.content)
            lane = lane_by_key.get(topic, 2)  # default to Personal (2)

            parent_ids: list[str] = []
            if lane in last_in_lane:
                parent_ids = [last_in_lane[lane]]
            last_in_lane[lane] = str(note.id)

            # Derive thought_type from simple whole-word heuristics
            tokens = _tokenize(note.content)
            c = note.content.strip()
            if c.endswith("?"):
                thought_type = "question"
            elif tokens & {"need", "should", "plan", "going", "will", "must", "want"}:
                thought_type = "action"
            elif tokens & {
                "worried",
                "stress",
                "anxious",
                "fear",
                "nervous",
                "scared",
                "overwhelmed",
            }:
                thought_type = "anxiety"
            elif tokens & {
                "realised",
                "realized",
                "insight",
                "learned",
                "understand",
                "discovered",
            }:
                thought_type = "insight"
            else:
                thought_type = "thought"

            pipeline_nodes.append(
                {
                    "id": str(note.id),
                    "content": note.content[:120]
                    + ("…" if len(note.content) > 120 else ""),
                    "topic": topic,
                    "lane": lane,
                    "thought_type": thought_type,
                    "timestamp": note.created_at.isoformat(),
                    "parent_ids": parent_ids,
                }
            )

        return {
            "generated_at": _now_ist().isoformat(),
            "lanes": lane_meta,
            "nodes": pipeline_nodes,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Error in /analytics/pipeline")
        raise HTTPException(status_code=500, detail="Failed to compute pipeline data.")
