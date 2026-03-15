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
        Fetch the primary tones of the last N music tracks.
        """
        history = (
            db.query(models.MusicHistory)
            .filter(models.MusicHistory.user_id == user_id)
            .order_by(models.MusicHistory.played_at.desc())
            .limit(limit)
            .all()
        )

        tones = []
        for song in history:
            # Match against MusicVibeCache
            cache_key = f"{song.title.lower()}|{song.artist.lower()}"
            vibe = db.query(models.MusicVibeCache).filter(models.MusicVibeCache.cache_key == cache_key).first()
            if vibe:
                tones.append(vibe.primary_tone)
        
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
