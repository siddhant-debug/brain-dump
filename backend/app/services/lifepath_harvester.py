import hashlib
from datetime import datetime, timedelta
from typing import List, Optional
from sqlalchemy.orm import Session
from app.models import models

class LifepathHarvester:
    """
    Pure data retrieval service for the Life Path engine.
    Aggregates health, music, and note context for a given user.
    """

    @staticmethod
    def harvest_health_context(user_id: int, db: Session, days: int = 7) -> dict:
        """Fetch health snapshots for the last N days and summarize."""
        cutoff = datetime.utcnow() - timedelta(days=days)
        snapshots = (
            db.query(models.HealthSnapshot)
            .filter(
                models.HealthSnapshot.user_id == user_id,
                models.HealthSnapshot.fetched_at >= cutoff
            )
            .order_by(models.HealthSnapshot.fetched_at.desc())
            .all()
        )

        if not snapshots:
            return {}

        # Basic summary logic
        latest = snapshots[0]
        return {
            "latest_readiness": latest.readiness,
            "avg_steps": sum(s.steps_today or 0 for s in snapshots) / len(snapshots),
            "recent_hrv": [s.hrv.get("current") for s in snapshots if s.hrv and s.hrv.get("current")][:5],
            "snapshot_count": len(snapshots)
        }

    @staticmethod
    def harvest_music_context(user_id: int, db: Session, limit: int = 10) -> List[str]:
        """
        Fetch the primary tones of the last N music tracks using a batch query.
        """
        history = (
            db.query(models.MusicHistory)
            .filter(models.MusicHistory.user_id == user_id)
            .order_by(models.MusicHistory.played_at.desc())
            .limit(limit)
            .all()
        )

        if not history:
            return []

        # 1. Accumulate cache keys
        cache_keys = []
        key_to_track = {}
        for song in history:
            raw_string = f"Single:{song.title}{song.artist}"
            ck = hashlib.md5(raw_string.encode("utf-8")).hexdigest()
            cache_keys.append(ck)
            key_to_track[ck] = song

        # 2. Batch query MusicVibeCache
        vibes = (
            db.query(models.MusicVibeCache)
            .filter(models.MusicVibeCache.cache_key.in_(cache_keys))
            .all()
        )

        # 3. Maintain order of original history
        vibe_map = {v.cache_key: v.primary_tone for v in vibes}
        tones = []
        for ck in cache_keys:
            if ck in vibe_map:
                tones.append(vibe_map[ck])
        
        return tones

    @staticmethod
    def harvest_notes_context(user_id: int, db: Session, hours: int = 24) -> List[models.Note]:
        """Fetch all notes created in the last N hours."""
        cutoff = datetime.utcnow() - timedelta(hours=hours)
        return (
            db.query(models.Note)
            .filter(
                models.Note.user_id == user_id,
                models.Note.created_at >= cutoff
            )
            .all()
        )

    @staticmethod
    def harvest_files_context(user_id: int, db: Session, hours: int = 24) -> List[str]:
        """Fetch content from files indexed in the last N hours using DB-level filtering."""
        cutoff = datetime.utcnow() - timedelta(hours=hours)
        cutoff_iso = cutoff.isoformat()

        # Query BrainEmbedding with JSONB operation for timestamp filtering
        # source_type must be "file"
        embeddings = (
            db.query(models.BrainEmbedding)
            .filter(
                models.BrainEmbedding.user_id == user_id,
                models.BrainEmbedding.source_type == "file",
                models.BrainEmbedding.metadata_["timestamp"].astext >= cutoff_iso
            )
            .all()
        )
        
        return [emb.document for emb in embeddings]
