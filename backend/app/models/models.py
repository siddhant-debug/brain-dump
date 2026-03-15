from sqlalchemy import (
    Column,
    Integer,
    String,
    DateTime,
    Boolean,
    ForeignKey,
    JSON,
    Float,
)
from sqlalchemy.sql import func
from app.core.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    full_name = Column(String, nullable=True)
    profile_pic = Column(String, nullable=True)
    weight_kg = Column(Float, nullable=True)
    height_cm = Column(Float, nullable=True)
    needs_loop_recalc = Column(Boolean, default=True, server_default="true")
    life_path_baseline = Column(JSON, nullable=True)  # {current: str, archive: List[str]}
    macro_goal = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    @property
    def has_completed_life_path(self) -> bool:
        return self.life_path_baseline is not None and self.macro_goal is not None


class HealthSnapshot(Base):
    __tablename__ = "health_snapshots"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    readiness = Column(String, nullable=True)  # HIGH, MODERATE, LOW, SYNCING
    heart_rate = Column(JSON, nullable=True)  # {current, avg_24h, resting}
    hrv = Column(JSON, nullable=True)  # {current, avg_7d}
    sleep = Column(JSON, nullable=True)  # {total_hours, deep_hours, rem_hours, awake_hours}
    steps_today = Column(Integer, nullable=True)
    active_energy_kcal = Column(Float, nullable=True)
    last_workout = Column(JSON, nullable=True)  # {type, duration_minutes, calories}
    fetched_at = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class StoredFile(Base):
    __tablename__ = "stored_files"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    filename = Column(String, index=True)
    file_type = Column(String)
    file_size = Column(Integer)
    content_text = Column(String, nullable=True)  # For .md, .txt
    file_path = Column(String, nullable=True)  # For .pdf
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Note(Base):
    __tablename__ = "notes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    content = Column(String, nullable=False)
    title = Column(String, nullable=True)
    location_name = Column(String, nullable=True)
    music_track = Column(String, nullable=True)
    focus_mode = Column(String, nullable=True)
    health_readiness = Column(String, nullable=True)
    is_favorite = Column(Boolean, default=False)
    sentiment = Column(String, nullable=True)  # "Positive", "Negative", "Neutral"
    categories = Column(JSON, nullable=True)  # Array of strings
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    content = Column(String, nullable=False)
    sender = Column(String, nullable=False)  # 'user' or 'ai'
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
    # Optional: store which notes were cited
    context_sources = Column(String, nullable=True)


class UserDirective(Base):
    __tablename__ = "user_directives"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    directive_content = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class MusicVibeCache(Base):
    __tablename__ = "music_vibe_cache"

    id = Column(Integer, primary_key=True, index=True)
    cache_key = Column(String, unique=True, index=True, nullable=False)
    primary_tone = Column(String, nullable=False)
    short_description = Column(String, nullable=False)
    valence = Column(Float, nullable=True)
    arousal = Column(Float, nullable=True)
    dominance = Column(Float, nullable=True)
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class MusicHistory(Base):
    __tablename__ = "music_history"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    title = Column(String, nullable=False)
    artist = Column(String, nullable=False)
    played_at = Column(DateTime(timezone=True), server_default=func.now())


from sqlalchemy.dialects.postgresql import ARRAY

class DetectedLoop(Base):
    __tablename__ = "detected_loops"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"),
                     index=True, nullable=False)
    theme_guess = Column(String, nullable=False)
    severity = Column(String)           # "high" | "low"
    occurrences = Column(Integer)
    path_forward = Column(String)
    first_seen = Column(String)
    last_seen = Column(String)
    notes_json = Column(JSON, nullable=False) # Store the serialized notes for easy return
    computed_at = Column(DateTime(timezone=True), server_default=func.now())





from pgvector.sqlalchemy import Vector
from sqlalchemy.dialects.postgresql import JSONB


class BrainEmbedding(Base):
    __tablename__ = "brain_embeddings"

    id = Column(String, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    document = Column(String, nullable=False)
    embedding = Column(Vector(768), nullable=False)
    source_type = Column(String, nullable=False, server_default="note", index=True)
    metadata_ = Column("metadata", JSONB, nullable=False)


class LifePathNode(Base):
    __tablename__ = "lifepath_nodes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    computed_at = Column(DateTime(timezone=True), server_default=func.now())
    trajectory = Column(JSONB, nullable=False)  # {progress: [], blockers: [], loops: [], goals: []}
    context_snapshot = Column(JSONB, nullable=False)  # {health: {}, music: {}, note_ids: []}
    embedding_id = Column(String, ForeignKey("brain_embeddings.id"), nullable=True)
