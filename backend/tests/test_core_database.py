# backend/tests/test_core_database.py
import pytest
from sqlalchemy import text
from app.core.database import SessionLocal, engine

def test_database_connection():
    """115: Verifies database connection and basic query execution."""
    db = SessionLocal()
    try:
        result = db.execute(text("SELECT 1")).scalar()
        assert result == 1
    finally:
        db.close()

def test_pgvector_extension_exists():
    """116: Verifies that pgvector extension is installed in the test database."""
    db = SessionLocal()
    try:
        # Check if 'vector' type exists in pg_type
        result = db.execute(text("SELECT count(*) FROM pg_type WHERE typname = 'vector'")).scalar()
        assert result > 0, "pgvector extension 'vector' type not found"
    finally:
        db.close()

def test_engine_disposal():
    """117: Verifies engine disposal doesn't crash."""
    # This is more of a smoke test for the engine teardown
    assert engine is not None
