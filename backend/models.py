from sqlalchemy import Column, Integer, String, DateTime, Boolean
from sqlalchemy.sql import func
from .database import Base

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
    user_id = Column(Integer, index=True) # Linked to User.id
    filename = Column(String, index=True)
    file_type = Column(String)
    file_size = Column(Integer)
    content_text = Column(String, nullable=True) # For .md, .txt
    file_path = Column(String, nullable=True) # For .pdf
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class Note(Base):
    __tablename__ = "notes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True) # Linked to User.id
    content = Column(String, nullable=False)
    is_favorite = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
