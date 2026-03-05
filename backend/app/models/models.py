from sqlalchemy import Column, Integer, String, DateTime, Boolean, ForeignKey, JSON
from sqlalchemy.sql import func
from app.core.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    full_name = Column(String, nullable=True)
    profile_pic = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class StoredFile(Base):
    __tablename__ = "stored_files"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True)  # Linked to User.id
    filename = Column(String, index=True)
    file_type = Column(String)
    file_size = Column(Integer)
    content_text = Column(String, nullable=True)  # For .md, .txt
    file_path = Column(String, nullable=True)  # For .pdf
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Note(Base):
    __tablename__ = "notes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True)  # Linked to User.id
    content = Column(String, nullable=False)
    is_favorite = Column(Boolean, default=False)
    sentiment = Column(String, nullable=True)  # "Positive", "Negative", "Neutral"
    categories = Column(JSON, nullable=True)  # Array of strings
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True)  # Linked to User.id
    content = Column(String, nullable=False)
    sender = Column(String, nullable=False)  # 'user' or 'ai'
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
    # Optional: store which notes were cited
    context_sources = Column(String, nullable=True)


class UserDirective(Base):
    __tablename__ = "user_directives"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=False)
    directive_content = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class MusicVibeCache(Base):
    __tablename__ = "music_vibe_cache"

    id = Column(Integer, primary_key=True, index=True)
    cache_key = Column(String, unique=True, index=True, nullable=False)
    primary_tone = Column(String, nullable=False)
    short_description = Column(String, nullable=False)
    valence = Column(
        JSON, nullable=True
    )  # Using JSON for easy float migrations or keeping as float
    arousal = Column(JSON, nullable=True)
    dominance = Column(JSON, nullable=True)
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


from pgvector.sqlalchemy import Vector
from sqlalchemy.dialects.postgresql import JSONB


class BrainEmbedding(Base):
    __tablename__ = "brain_embeddings"

    id = Column(String, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    document = Column(String, nullable=False)
    embedding = Column(Vector(768), nullable=False)
    metadata_ = Column("metadata", JSONB, nullable=False)
