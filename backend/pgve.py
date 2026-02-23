import os
import chromadb
import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv

# Load env variables
load_dotenv()

# Setup paths (since pgve.py is in backend folder)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "brain_storage")
COLLECTION_NAME = "my_second_brain_v2" # BAAI/bge-base-en-v1.5 embeddings

# 1. Connect to ChromaDB
print(f"Connecting to ChromaDB at {DB_PATH}...")
client = chromadb.PersistentClient(path=DB_PATH)
collection = client.get_collection(COLLECTION_NAME)

print(f"Fetching data from collection: {COLLECTION_NAME}...")
results = collection.get(include=["embeddings", "documents", "metadatas"])

if not results or not results["ids"]:
    print("No data found in ChromaDB.")
    exit()

# 2. Connect to Postgres
print("Connecting to PostgreSQL...")
db_url = os.getenv("DATABASE_URL", "postgresql://postgres:password123@127.0.0.1/postgres")
# psycopg2 expects postgresql:// instead of postgresql+psycopg://
if db_url.startswith("postgresql+psycopg://"):
    db_url = db_url.replace("postgresql+psycopg://", "postgresql://")

conn = psycopg.connect(db_url)
cur = conn.cursor()

# 3. Setup pgvector extension and table
print("Setting up pgvector extension and table...")
cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")
# BGE-base uses 768 dimensions
cur.execute("""
    CREATE TABLE IF NOT EXISTS brain_embeddings (
        id VARCHAR PRIMARY KEY,
        document TEXT,
        embedding vector(768),
        metadata JSONB
    );
""")
conn.commit()

import json

# 4. Insert data into pgvector table
print(f"Migrating {len(results['ids'])} records into PostgreSQL...")

# Helper to format embedding as a Postgres vector string "[1.0, 2.0,...]"
def format_vector(emb):
    if hasattr(emb, "tolist"):
        emb = emb.tolist()
    return "[" + ",".join(str(x) for x in emb) + "]"

rows = [
    (id_, doc, format_vector(emb), json.dumps(meta or {}))
    for id_, doc, emb, meta in zip(
        results["ids"],
        results["documents"],
        results["embeddings"],
        results["metadatas"]
    )
]

cur.executemany("""
    INSERT INTO brain_embeddings (id, document, embedding, metadata)
    VALUES (%s, %s, %s::vector, %s::jsonb)
    ON CONFLICT (id) DO UPDATE SET 
        document = EXCLUDED.document,
        embedding = EXCLUDED.embedding,
        metadata = EXCLUDED.metadata;
""", rows)

conn.commit()
cur.close()
conn.close()
print("Migration completed successfully!")