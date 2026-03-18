import os
import logging
from dotenv import load_dotenv
from sqlalchemy import create_engine, event
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
#test
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

SQL_DB_URL = os.getenv("DATABASE_URL")
if not SQL_DB_URL:
    raise ValueError(
        "DATABASE_URL environment variable is not set. Check your .env file."
    )

# --- H-1 FIX: Connection pool configured for beta load ---
# pool_size=10      → resident connections kept warm (safe for a single server)
# max_overflow=20   → burst connections allowed on top of pool_size (max 30 total)
# pool_timeout=30   → raise error after 30 s if no connection available (fail fast)
# pool_pre_ping     → validates connection health before handing to a request
#                     (auto-heals after Docker restarts / Postgres idle timeouts)
# pool_recycle=1800 → recycles connections every 30 min before Postgres closes them
engine = create_engine(
    SQL_DB_URL,
    pool_size=10,
    max_overflow=20,
    pool_timeout=30,
    pool_pre_ping=True,
    pool_recycle=1800,
)


# --- H-2 FIX: Optimized for pgvector HNSW search quality ---
@event.listens_for(engine, "connect")
def set_hnsw_ef_search(dbapi_conn, connection_record):
    """Sets the ef_search parameter for the current session to balance search recall and speed."""
    cursor = dbapi_conn.cursor()
    cursor.execute("SET hnsw.ef_search = 40")
    cursor.close()


logger.info(
    "SQLAlchemy engine configured: pool_size=10, max_overflow=20, "
    "pool_timeout=30s, pool_pre_ping=True, pool_recycle=1800s"
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


# Dependency — FastAPI injects this into route handlers via Depends(get_db).
# The `finally` block ALWAYS runs, closing the session even on exceptions.
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
